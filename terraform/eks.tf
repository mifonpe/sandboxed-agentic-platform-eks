module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = var.eks_cluster_version

  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  access_entries = var.access_entries

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  kms_key_administrators = distinct(concat([
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"],
    var.kms_key_admin_roles,
    [data.aws_iam_session_context.current.issuer_arn]
  ))

  security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }

    # The ephemeral-ports rule above only covers 1025-65535, so a pod listening on
    # a privileged port is unreachable from pods on OTHER nodes while working fine
    # from its own -- which looks exactly like a broken application. The
    # agentgateway data plane serves its HTTP listener on :80 and hit this.
    #
    # self = true, not source_node_security_group: this block lands on the NODE
    # security group, and the module only maps source_cluster_security_group there
    # (see modules/eks/node_groups.tf). self is the node-to-node form.
    #
    # Description charset is restricted by AWS to
    # ^[0-9A-Za-z_ .:/()#,@\[\]+=&;{}!$*-]*$ -- no em-dashes.
    ingress_nodes_http = {
      description = "Node to node HTTP (:80), below the 1025 floor of the ephemeral ports rule"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      self        = true
    }
  }

  # eks_managed_node_group_defaults was removed in module v21 — defaults are now
  # inlined directly on the one node group we have (core_node_group below).
  eks_managed_node_groups = {
    core_node_group = {
      name        = "core-node-group"
      description = "Core node group for system workloads"

      subnet_ids = module.vpc.public_subnets

      min_size     = 1
      max_size     = 3
      desired_size = 2

      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.xlarge"]

      # Spot by default. Coder's Postgres lives here — an interruption loses any
      # workspace/template state not on a PVC, so use on-demand if that matters.
      capacity_type = local.mng_capacity_type[var.core_capacity_type]

      labels = {
        WorkerType    = local.mng_capacity_type[var.core_capacity_type]
        NodeGroupType = "core"
      }

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      ebs_optimized = true
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 100
            volume_type = "gp3"
          }
        }
      }

      # AWS's launch template default is hop_limit=1, which blocks pod-network
      # traffic from reaching IMDS (adds a hop over the host) — the LB controller
      # needs IMDS to discover the VPC ID and fails to start without this.
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }
    }
  }

  node_security_group_tags = local.tags

  addons = {
    # Nodes can't reach Ready without a CNI, and managed node groups wait for Ready
    # before reporting ACTIVE — before_compute installs these ahead of the node
    # groups instead of the module's default "after node groups" ordering.
    vpc-cni = {
      most_recent    = true
      before_compute = true

      # Enable the built-in NetworkPolicy agent so NetworkPolicy objects are actually
      # enforced. Without this the node agent runs --enable-network-policy=false and
      # every policy in the cluster is decorative — including the agent-sandbox
      # air-gap (see manifests/kata-python/sandbox-template.yaml).
      # Default-allow until a policy selects a pod, so unselected workloads are
      # unaffected.
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
      })
    }
    kube-proxy = {
      most_recent    = true
      before_compute = true
    }
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.arn
    }
  }

  tags = local.tags
}
