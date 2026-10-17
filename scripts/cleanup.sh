#!/bin/bash

set -e

REGION="eu-west-1"
CLUSTER_NAME="agents-kata-eks"
# Inherit AWS_PROFILE from the environment (the Makefile exports it); --profile
# overrides. Empty means ambient credentials.
AWS_PROFILE="${AWS_PROFILE:-}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --region)
      REGION="$2"
      shift 2
      ;;
    --cluster-name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --profile)
      AWS_PROFILE="$2"
      shift 2
      ;;
    -y|--yes)
      AUTO_APPROVE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--region REGION] [--cluster-name CLUSTER_NAME] [--profile PROFILE] [-y|--yes]"
      exit 1
      ;;
  esac
done

echo "============================================"
echo "  Agentic Dev Platform on EKS - Cleanup"
echo "============================================"
echo "Region:       $REGION"
echo "Cluster Name: $CLUSTER_NAME"
echo "AWS Profile:  ${AWS_PROFILE:-<ambient credentials>}"
echo "============================================"

if [[ "$AUTO_APPROVE" != "true" ]]; then
  read -p "This will DESTROY all resources. Continue? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

# Step 0: Delete everything that makes an AWS load balancer, and WAIT for it.
#
# This has to happen before terraform destroy, and the ordering is not cosmetic:
# the ALB behind Coder's Ingress is owned by the aws-load-balancer-controller,
# NOT by terraform. Terraform destroys the controller (a Helm release) and never
# knows the ALB exists. Delete the controller first and the Ingress is orphaned
# with nothing left to reconcile it, so the ALB survives — holding ENIs in the
# subnets, which blocks subnet and internet-gateway deletion, which hangs the VPC
# teardown and strands the node groups and ASGs behind it.
#
# Deleting the Ingress while the controller is still running makes the controller
# delete the ALB properly. Hence: apps first, terraform second.
echo ""
echo ">>> Step 0: Removing load-balancer-backed workloads (Coder, MCP)..."

# Coder: the ingress is what owns the ALB. Uninstall the chart, which removes it.
helm uninstall coder -n coder 2>/dev/null && echo "  Coder uninstalled." || echo "  Coder not installed."
helm uninstall coder-postgresql -n coder 2>/dev/null && echo "  Coder postgres uninstalled." || true
# Belt and braces: an ingress left by a failed uninstall still orphans the ALB.
kubectl delete ingress --all -n coder --ignore-not-found=true 2>/dev/null || true
# Workspace pods are created by Coder itself, not by the chart, so they outlive it
# and keep PVCs (and therefore EBS volumes) attached.
kubectl delete deploy -n coder -l com.coder.resource=true --ignore-not-found=true 2>/dev/null || true
kubectl delete pvc --all -n coder --ignore-not-found=true 2>/dev/null || true

# MCP server: no load balancer of its own, but it holds the gateway backend.
kubectl delete -n mcp deploy/mcp-sandbox svc/mcp-sandbox sa/mcp-sandbox --ignore-not-found=true 2>/dev/null || true
kubectl delete -n agent-sandbox role/mcp-sandbox-claims rolebinding/mcp-sandbox-claims --ignore-not-found=true 2>/dev/null || true

# Any OTHER Service of type LoadBalancer, whatever created it — e.g. a stray one
# left over from testing.
kubectl delete svc -A --field-selector spec.type=LoadBalancer --ignore-not-found=true 2>/dev/null || true

# WAIT for the controller to actually delete them. Without this the script races
# ahead to terraform destroy, kills the controller mid-reconcile, and the ALB is
# orphaned anyway — the exact failure this step exists to prevent.
echo "  Waiting for load balancers to be removed (up to 5 min)..."
for i in $(seq 1 30); do
  remaining=$(kubectl get ingress,svc -A -o json 2>/dev/null \
    | python3 -c "
import json,sys
d=json.load(sys.stdin)
n=sum(1 for i in d.get('items',[])
      if i['kind']=='Ingress' or i.get('spec',{}).get('type')=='LoadBalancer')
print(n)
" 2>/dev/null || echo 0)
  [[ "$remaining" == "0" ]] && { echo "  All load-balancer resources gone."; break; }
  [[ $i -eq 30 ]] && echo "  WARNING: $remaining still present after 5 min — check for a stranded ALB before rerunning."
  sleep 10
done

# Step 1: Delete manually deployed workloads (not managed by Terraform)
echo ""
echo ">>> Step 1: Deleting manually deployed workloads..."
kubectl delete pods -n agents -l app=agent-sandbox --ignore-not-found=true 2>/dev/null || true
kubectl delete svc -n agents -l app=agent-sandbox --ignore-not-found=true 2>/dev/null || true
kubectl delete configmap -n agents -l tenant --ignore-not-found=true 2>/dev/null || true
kubectl delete secret -n agents -l tenant --ignore-not-found=true 2>/dev/null || true
kubectl delete pvc -n agents --all --ignore-not-found=true 2>/dev/null || true
echo "  Workloads deleted."

# Step 2: Wait for pods to terminate
echo ""
echo ">>> Step 2: Waiting for pods to terminate..."
kubectl wait --for=delete pods -n agents -l app=agent-sandbox --timeout=60s 2>/dev/null || true

# Exported so the AWS CLI calls below and terraform's provider both see it.
[[ -n "$AWS_PROFILE" ]] && export AWS_PROFILE
# Must match the value used at apply time: destroy-time provisioners read the
# profile from self.triggers, and a mismatch makes them run without credentials.
TF_PROFILE_VAR=()
[[ -n "$AWS_PROFILE" ]] && TF_PROFILE_VAR=(-var="aws_profile=$AWS_PROFILE")

AWS_PROFILE_FLAG=()
[[ -n "$AWS_PROFILE" ]] && AWS_PROFILE_FLAG=(--profile "$AWS_PROFILE")

# Step 3: Delete the EKS managed node groups, and WAIT.
#
# Same class of problem as step 0, different resource. Nodes run in PUBLIC
# subnets with map_public_ip_on_launch=true (vpc.tf), so every instance holds an
# ENI with a public IP, and AWS refuses to detach an internet gateway while one
# exists.
#
# Terraform does not order this correctly on its own: the node groups live in
# module.eks / module.eks_kata_node_group, the IGW in module.vpc, and nothing
# expresses the dependency between them. Observed on a real teardown — Terraform
# went straight for module.vpc.aws_internet_gateway.this[0] while BOTH node
# groups were still ACTIVE (not even DELETING), then sat on the IGW until it
# timed out. Deleting the node groups first and waiting removes the ENIs before
# anything asks for the IGW.
#
# Delete the NODE GROUP, not the instances: terminating instances leaves the ASG
# to replace them, and the replacements hold public IPs again.
#
# Names are generated with a random suffix, so they are discovered here rather
# than hardcoded. Terraform reconciles the already-deleted groups as gone.
echo ""
echo ">>> Step 3: Deleting EKS managed node groups..."
NODEGROUPS=$(aws eks list-nodegroups --region "$REGION" "${AWS_PROFILE_FLAG[@]}" \
  --cluster-name "$CLUSTER_NAME" --query 'nodegroups[]' --output text 2>/dev/null) || NODEGROUPS=""

if [[ -z "$NODEGROUPS" || "$NODEGROUPS" == "None" ]]; then
  echo "  No node groups found (cluster already gone, or none exist)."
else
  for ng in $NODEGROUPS; do
    echo "  Deleting node group: $ng"
    aws eks delete-nodegroup --region "$REGION" "${AWS_PROFILE_FLAG[@]}" \
      --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" >/dev/null 2>&1 || true
  done

  # Wait for the instances to actually go. The IGW is only unblocked once the
  # ENIs are released, which happens on termination, not on the delete call.
  #
  # 20 min: a node group with a blocked pod eviction can take a while to drain,
  # and timing out here only means falling through to a destroy that may hang —
  # so warn loudly rather than failing the script.
  for ng in $NODEGROUPS; do
    echo "  Waiting for $ng to finish deleting (up to 20 min)..."
    aws eks wait nodegroup-deleted --region "$REGION" "${AWS_PROFILE_FLAG[@]}" \
      --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" 2>/dev/null \
      && echo "    $ng deleted." \
      || echo "    WARNING: $ng did not report deleted — the IGW teardown may hang."
  done
  echo "  Node groups deleted."
fi

# Step 4: Terraform destroy (with retries for dependency ordering)
echo ""
echo ">>> Step 4: Destroying Terraform-managed infrastructure..."
echo "  This takes ~10-15 minutes."

cd "$(dirname "${BASH_SOURCE[0]}")/../terraform"

# Nodes run in PUBLIC subnets with map_public_ip_on_launch=true (vpc.tf), so every
# instance holds an ENI with a public IP. AWS refuses to detach/delete an internet
# gateway while any such ENI exists, so a leftover instance — one orphaned by a
# failed destroy pass — hangs the VPC teardown on "Network vpc-xxx has some
# mapped public address(es)" until it times out.
#
# Terraform destroys both managed node groups in the right order on its own; this
# sweep only catches what Terraform does not know about.
sweep_vpc_instances() {
  local vpc_id
  vpc_id=$(aws ec2 describe-vpcs --region "$REGION" \
    --filters "Name=tag:Name,Values=$CLUSTER_NAME" \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null) || return 0
  [[ -z "$vpc_id" || "$vpc_id" == "None" ]] && return 0

  local ids
  ids=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc_id" \
              "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null)
  [[ -z "$ids" || "$ids" == "None" ]] && { echo "  No stray instances in $vpc_id."; return 0; }

  echo "  Terminating stray instances in $vpc_id: $ids"
  aws ec2 terminate-instances --region "$REGION" --instance-ids $ids >/dev/null 2>&1 || true
  aws ec2 wait instance-terminated --region "$REGION" --instance-ids $ids 2>/dev/null || true
  echo "  Stray instances terminated."
}

# Backstop for a load balancer that outlived its controller anyway — step 0 should
# prevent this, but a controller killed mid-reconcile still orphans one, and an
# orphaned LB holds ENIs that block subnet and IGW deletion.
#
# Scoped to the cluster VPC so it can never touch a load balancer belonging to
# something else in the account.
sweep_vpc_load_balancers() {
  local vpc_id
  vpc_id=$(aws ec2 describe-vpcs --region "$REGION" \
    --filters "Name=tag:Name,Values=$CLUSTER_NAME" \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null) || return 0
  [[ -z "$vpc_id" || "$vpc_id" == "None" ]] && return 0

  # ALBs and NLBs.
  local arns
  arns=$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[?VpcId=='$vpc_id'].LoadBalancerArn" --output text 2>/dev/null)
  if [[ -n "$arns" && "$arns" != "None" ]]; then
    for arn in $arns; do
      echo "  Deleting orphaned load balancer: $arn"
      aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn" >/dev/null 2>&1 || true
    done
  fi

  # Classic ELBs — a Service of type LoadBalancer with no annotations gets one
  # from the in-tree cloud provider, and those are invisible to elbv2.
  local names
  names=$(aws elb describe-load-balancers --region "$REGION" \
    --query "LoadBalancerDescriptions[?VPCId=='$vpc_id'].LoadBalancerName" --output text 2>/dev/null)
  if [[ -n "$names" && "$names" != "None" ]]; then
    for n in $names; do
      echo "  Deleting orphaned classic ELB: $n"
      aws elb delete-load-balancer --region "$REGION" --load-balancer-name "$n" >/dev/null 2>&1 || true
    done
  fi

  # Deletion is async and the ENIs linger a little after the API returns.
  if [[ -n "$arns$names" && "$arns$names" != "NoneNone" ]]; then
    echo "  Waiting 45s for load balancer ENIs to detach..."
    sleep 45
  fi
}

# First pass: destroy Helm releases and K8s resources
terraform destroy \
  -var="region=$REGION" \
  -var="name=$CLUSTER_NAME" \
  "${TF_PROFILE_VAR[@]}" \
  -auto-approve 2>&1 || {
    echo ""
    echo ">>> First destroy pass had errors. Cleaning up orphaned state..."

    # Remove K8s resources from state if cluster is already gone
    for res in $(terraform state list 2>/dev/null | grep -E 'kubernetes_|helm_release|kubectl_manifest'); do
      echo "  Removing from state: $res"
      terraform state rm "$res" 2>/dev/null || true
    done

    echo ""
    echo ">>> Sweeping orphaned load balancers (their ENIs block subnet deletion)..."
    sweep_vpc_load_balancers

    echo ""
    echo ">>> Sweeping stray EC2 instances (public IPs block IGW deletion)..."
    sweep_vpc_instances

    echo ""
    echo ">>> Retrying destroy..."
    terraform destroy \
      -var="region=$REGION" \
      -var="name=$CLUSTER_NAME" \
      "${TF_PROFILE_VAR[@]}" \
      -auto-approve
  }

# Step 4b: ECR repo. terraform destroy handles this via force_delete=true on the
# repository (images and all). This is only a backstop for the case where the
# repo was orphaned by a state removal in the retry path above — an ECR repo left
# behind blocks the next apply on a name clash.
echo ""
echo ">>> Step 4b: Verifying ECR repository is gone..."
ECR_REPO="${CLUSTER_NAME}-mcp-sandbox"
if aws ecr describe-repositories --region "$REGION" --repository-names "$ECR_REPO" >/dev/null 2>&1; then
  echo "  Repository '$ECR_REPO' still exists; deleting (--force removes images too)."
  aws ecr delete-repository --region "$REGION" --repository-name "$ECR_REPO" --force >/dev/null 2>&1 \
    && echo "  Deleted." || echo "  Delete failed — remove it manually."
else
  echo "  Repository '$ECR_REPO' already gone."
fi

# Step 5: Delete the nested-kvm launch template (created outside Terraform)
echo ""
echo ">>> Step 5: Deleting nested-kvm launch template..."
LT_NAME="${CLUSTER_NAME}-kata-nested-kvm"
aws ec2 delete-launch-template --region "$REGION" \
  --launch-template-name "$LT_NAME" 2>/dev/null \
  && echo "  Launch template '$LT_NAME' deleted." \
  || echo "  Launch template '$LT_NAME' not found or already deleted."

# Step 5b: Verify nothing survived.
#
# A destroy that leaves a VPC behind looks successful but is not: the next apply
# collides on names, and the leftovers keep billing. Report rather than assume.
echo ""
echo ">>> Step 5b: Verifying teardown..."
LEFTOVER=0
VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Name,Values=$CLUSTER_NAME" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
  echo "  WARNING: VPC $VPC_ID still exists."
  LEFTOVER=1

  LB_LEFT=$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "length(LoadBalancers[?VpcId=='$VPC_ID'])" --output text 2>/dev/null)
  [[ "$LB_LEFT" != "0" && -n "$LB_LEFT" ]] && echo "    - $LB_LEFT load balancer(s) still attached"

  INST_LEFT=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'length(Reservations[].Instances[])' --output text 2>/dev/null)
  [[ "$INST_LEFT" != "0" && -n "$INST_LEFT" ]] && echo "    - $INST_LEFT instance(s) still running"

  ENI_LEFT=$(aws ec2 describe-network-interfaces --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'length(NetworkInterfaces)' --output text 2>/dev/null)
  [[ "$ENI_LEFT" != "0" && -n "$ENI_LEFT" ]] && echo "    - $ENI_LEFT network interface(s) still present"

  echo "    Re-run 'make destroy' after clearing these, or delete them in the console."
else
  echo "  VPC gone."
fi

ASG_LEFT=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" \
  --query "length(AutoScalingGroups[?contains(AutoScalingGroupName, '$CLUSTER_NAME')])" --output text 2>/dev/null)
if [[ "$ASG_LEFT" != "0" && -n "$ASG_LEFT" ]]; then
  echo "  WARNING: $ASG_LEFT autoscaling group(s) matching '$CLUSTER_NAME' still exist."
  LEFTOVER=1
fi

[[ "$LEFTOVER" == "0" ]] && echo "  Clean." || echo "  Teardown INCOMPLETE — see warnings above."

# Step 6: Clean up local files
echo ""
echo ">>> Step 6: Cleaning up local files..."
rm -f tfplan
rm -f terraform.tfstate.*.backup

echo ""
echo "============================================"
echo "  Cleanup Complete!"
echo "============================================"
echo ""
echo "Remaining local files (kept intentionally):"
echo "  - terraform.tfstate      (tracks that resources are destroyed)"
echo "  - .terraform/            (provider cache, re-used on next deploy)"
echo ""
echo "To fully reset: rm -rf .terraform terraform.tfstate*"
