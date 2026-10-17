module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.20"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    chart_version = "1.11.0"
  }

  tags = local.tags
}

# The Helm release reports "deployed" before the controller pods are Ready, but its
# mutating/validating webhooks are already registered — any Service or Ingress applied in
# that window fails with "no endpoints available for service
# aws-load-balancer-webhook-service". Block until the webhook actually answers.
#
# ponytail: shells out to kubectl because there is no Terraform data source that waits on
# pod readiness. Drop this if the chart ever gains a proper readiness gate.
resource "null_resource" "wait_for_alb_controller" {
  triggers = {
    cluster = module.eks.cluster_name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    # The AWS provider's `profile` argument does not reach provisioners — they shell
    # out to the CLI, which reads AWS_PROFILE from the environment. Without this the
    # CLI has no credentials, update-kubeconfig silently writes nothing, and kubectl
    # falls back to localhost:8080. Same pattern as agentsandbox.tf.
    environment = {
      AWS_PROFILE = local.aws_profile
    }

    command = <<-EOT
      set -euo pipefail
      export KUBECONFIG="$(mktemp)"
      trap 'rm -f "$KUBECONFIG"' EXIT
      aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region} --kubeconfig "$KUBECONFIG"
      kubectl -n kube-system wait --for=condition=Available \
        deployment/aws-load-balancer-controller --timeout=10m
    EOT
  }

  depends_on = [module.eks_blueprints_addons]
}
