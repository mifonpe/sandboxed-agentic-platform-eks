provider "aws" {
  region = local.region

  profile = var.aws_profile != "" ? var.aws_profile : null
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  # helm provider v3: kubernetes is an attribute, not a block
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  apply_retry_count      = 30
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

locals {
  name   = var.name
  region = var.region

  # local-exec provisioners (agentsandbox.tf) don't inherit the AWS provider's
  # profile argument — they need it passed explicitly via AWS_PROFILE.
  aws_profile = var.aws_profile

  is_china_region = var.is_china_region != null ? var.is_china_region : startswith(var.region, "cn-")
  partition       = local.is_china_region ? "aws-cn" : "aws"
  dns_suffix      = local.is_china_region ? "amazonaws.com.cn" : "amazonaws.com"

  pod_identity_principal = "pods.eks.amazonaws.com"

  kata_namespace   = "kata-system"
  agents_namespace = "agents"

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Managed node groups want SPOT / ON_DEMAND; the variables take the lowercase
  # spot / on-demand, so map between them here.
  mng_capacity_type = {
    "spot"      = "SPOT"
    "on-demand" = "ON_DEMAND"
  }

  tags = {
    Blueprint  = local.name
    GithubRepo = "gitlab.aws.dev/wsuam/sample-aws-eks-kata-for-agents"
    Workload   = "agents-kata"
  }
}
