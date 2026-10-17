module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = var.vpc_cidr

  azs            = local.azs
  public_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]

  # Nodes live in the public subnets (map_public_ip_on_launch below) and reach the
  # internet via the Internet Gateway directly — no NAT gateway, since this is a
  # demo/workshop deployment and NAT's ~$32/mo + data cost isn't worth it here.
  map_public_ip_on_launch = true
  enable_nat_gateway      = false
  enable_dns_hostnames    = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  tags = local.tags
}
