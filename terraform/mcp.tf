################################################################################
# ECR repository for the MCP server image.
#
# Only the registry lives in Terraform — the MCP server's Kubernetes objects are
# plain manifests under manifests/mcp/, applied with `make deploy-mcp`. Keeping
# them out of Terraform means redeploying the server does not touch infra state.
################################################################################

resource "aws_ecr_repository" "mcp_sandbox" {
  count = var.enable_mcp_sandbox ? 1 : 0

  name                 = "${local.name}-mcp-sandbox"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # force_delete so `terraform destroy` removes the repo even when it still holds
  # images — without it destroy fails with RepositoryNotEmptyException and leaves
  # the repo behind, which then blocks the next apply on a name clash.
  force_delete = true

  tags = local.tags
}

output "mcp_ecr_repository_url" {
  description = "ECR repo for the MCP server image; consumed by `make build-mcp`."
  value       = var.enable_mcp_sandbox ? aws_ecr_repository.mcp_sandbox[0].repository_url : ""
}
