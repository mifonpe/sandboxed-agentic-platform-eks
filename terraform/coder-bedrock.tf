################################################################################
# Bedrock access for Coder workspaces.
#
# Lets Claude Code running inside a workspace invoke Claude on Bedrock without
# any long-lived credential in the workspace: EKS Pod Identity hands the pod
# temporary STS credentials, scoped to this role, via the SDK's standard
# provider chain.
#
# The association targets a DEDICATED ServiceAccount, not "default" — binding it
# to default would give Bedrock to every pod in the coder namespace, including
# the Coder server and its database.
################################################################################

locals {
  # "eu.anthropic.claude-opus-5" -> geo "eu", foundation model "anthropic.claude-opus-5".
  # An in-region id ("anthropic.claude-opus-5") has no geo prefix and no profile.
  bedrock_geo              = split(".", var.bedrock_model_id)[0]
  bedrock_foundation_model = replace(var.bedrock_model_id, "/^(us|eu|au|global)\\./", "")

  # A geo profile routes to the foundation model in any Region of its geo, so the
  # model ARN must be allowed in all of them — not just var.bedrock_region.
  # Also consumed by agentgateway-bedrock.tf.
  bedrock_model_region_glob = contains(["us", "eu", "au"], local.bedrock_geo) ? "${local.bedrock_geo}-*" : "*"
}

resource "aws_iam_policy" "coder_workspace_bedrock" {
  count = var.enable_coder_bedrock ? 1 : 0

  name        = "${local.name}-coder-workspace-bedrock"
  description = "Allow Coder workspaces to invoke ${var.bedrock_model_id} on Bedrock"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeInferenceProfile"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:Converse",
          "bedrock:ConverseStream"
        ]
        # Same two-ARN shape as the agentgateway role: a geo inference profile
        # routes to the foundation model in any Region of its geo, so both the
        # profile and the region-globbed foundation model have to be allowed.
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:${var.bedrock_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_id}",
          "arn:${data.aws_partition.current.partition}:bedrock:${local.bedrock_model_region_glob}::foundation-model/${local.bedrock_foundation_model}",
        ]
      },
      {
        Sid    = "DiscoverModels"
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel",
          "bedrock:ListInferenceProfiles",
          "bedrock:GetInferenceProfile"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role" "coder_workspace_bedrock" {
  count = var.enable_coder_bedrock ? 1 : 0

  name = "${local.name}-coder-workspace-bedrock"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = local.pod_identity_principal
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "coder_workspace_bedrock" {
  count = var.enable_coder_bedrock ? 1 : 0

  role       = aws_iam_role.coder_workspace_bedrock[0].name
  policy_arn = aws_iam_policy.coder_workspace_bedrock[0].arn
}

# The namespace and ServiceAccount are created by `make deploy-coder` (Coder
# itself lives in Helm, not terraform), so this association references them by
# name rather than by resource.
resource "aws_eks_pod_identity_association" "coder_workspace_bedrock" {
  count = var.enable_coder_bedrock ? 1 : 0

  cluster_name    = module.eks.cluster_name
  namespace       = var.coder_namespace
  service_account = var.coder_workspace_service_account
  role_arn        = aws_iam_role.coder_workspace_bedrock[0].arn
}

output "coder_workspace_bedrock_role_arn" {
  description = "Role Coder workspaces assume for Bedrock access."
  value       = var.enable_coder_bedrock ? aws_iam_role.coder_workspace_bedrock[0].arn : ""
}
