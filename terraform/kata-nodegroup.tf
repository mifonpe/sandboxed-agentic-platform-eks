# Kata node group supports two modes:
# - "nested-kvm": c8i/m8i/r8i instances with NestedVirtualization=enabled (default)
# - "bare-metal": *.metal instances with native KVM (no nested virt needed)
#
# Both modes use the submodule's own built-in launch template (create_launch_template
# default) — module v21 / AWS provider 6.x added native cpu_options.nested_virtualization
# support, so nested-kvm no longer needs a CLI-precreated launch template.

# This rule allows Kata nodes (which sit on the cluster primary SG, same as every EKS
# managed node) to reach core nodes (e.g. the agentgateway data plane).
resource "aws_security_group_rule" "kata_to_node_all_traffic" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.cluster_primary_security_group_id
  description              = "Allow Kata nodes (cluster primary SG) to access core nodes"
}

locals {
  kata_use_nested_kvm = var.kata_node_mode == "nested-kvm"
}

# EKS Managed Node Group for Kata workloads
module "eks_kata_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 21.0"

  name               = "kata-${var.kata_node_mode}"
  cluster_name       = module.eks.cluster_name
  kubernetes_version = var.eks_cluster_version

  cluster_service_cidr = module.eks.cluster_service_cidr

  subnet_ids = module.vpc.public_subnets

  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

  min_size     = var.kata_node_min_size
  max_size     = var.kata_node_max_size
  desired_size = var.kata_node_desired_size

  instance_types = var.kata_instance_types
  ami_type       = "AL2023_x86_64_STANDARD"

  # Spot by default. An interruption terminates the Kata VMs on that node, killing the agent
  # sandboxes running inside them — list several instance types to reduce the odds.
  capacity_type = local.mng_capacity_type[var.kata_capacity_type]

  # nested-kvm needs NestedVirtualization enabled to expose /dev/kvm to the guest;
  # bare-metal instances already have native /dev/kvm, so cpu_options is left unset.
  cpu_options = local.kata_use_nested_kvm ? {
    nested_virtualization = "enabled"
  } : null

  block_device_mappings = {
    xvda = {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = 100
        volume_type           = "gp3"
        encrypted             = true
        delete_on_termination = true
      }
    }
  }

  # See eks.tf core_node_group: default hop_limit=1 blocks pod-network IMDS calls.
  # Keep this at 2 — the VPC CNI reads IMDS from the pod network. Sandbox IMDS access
  # is blocked by the air-gap NetworkPolicy instead (egress: [] covers 169.254.0.0/16),
  # see manifests/kata-python/sandbox-template.yaml.
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  labels = {
    "workload-type"                  = "kata"
    "katacontainers.io/kata-runtime" = "true"
  }

  taints = {
    kata = {
      key    = "kata"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }

  iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}
