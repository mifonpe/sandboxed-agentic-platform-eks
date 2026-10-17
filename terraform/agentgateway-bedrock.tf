################################################################################
# Bedrock access for the agentgateway data plane.
#
# SPIKE (var.enable_agentgateway_bedrock, default false): lets agentgateway front
# Bedrock as an `ai` backend, so model access can be authorized from the SAME
# Cognito JWT that already governs MCP tool access.
#
# Today workspaces call Bedrock directly with their own Pod Identity role
# (coder-bedrock.tf), which is a SHARED role: every workspace assumes it and no
# per-user distinction is possible. Routing model traffic through the gateway
# moves the IAM here, and the per-user distinction comes from the JWT claim
# instead of from IAM.
#
# This file is purely additive. It does not remove the workspace role, and
# nothing routes through it until an `ai` backend and HTTPRoute exist.
################################################################################

resource "aws_iam_policy" "agentgateway_bedrock" {
  count = var.enable_agentgateway_bedrock ? 1 : 0

  name        = "${local.name}-agentgateway-bedrock"
  description = "Allow agentgateway to invoke ${var.bedrock_model_id} on Bedrock"

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
        # Same two-ARN shape as the Coder workspace role: a geo
        # inference profile routes to the foundation model in any Region of its
        # geo, so both the profile and the region-globbed foundation model have
        # to be allowed.
        #
        # The inference-profile ARN is region-globbed too: a geo profile can be
        # addressed from any Region in its geo, and pinning it to
        # var.bedrock_region makes streaming fail from the others.
        Resource = [
          "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/${var.gateway_bedrock_model_id}",
          "arn:${data.aws_partition.current.partition}:bedrock:${local.bedrock_model_region_glob}::foundation-model/${var.gateway_bedrock_foundation_model}",
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
      # No aws-marketplace:* statement.
      #
      # Bedrock raises "not authorized to perform the required AWS Marketplace
      # actions" for models whose Marketplace subscription the ACCOUNT lacks —
      # claude-opus-5 here. Granting the role those actions does not fix it
      # (verified: the documented ViewSubscriptions/Subscribe/Unsubscribe policy
      # still returned 403), because the subscription is missing account-wide,
      # not role-wide. The fix is enabling model access in the Bedrock console,
      # not widening this policy. var.gateway_bedrock_model_id points at a model
      # the account can already invoke.
    ]
  })

  tags = local.tags
}

resource "aws_iam_role" "agentgateway_bedrock" {
  count = var.enable_agentgateway_bedrock ? 1 : 0

  name = "${local.name}-agentgateway-bedrock"

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

resource "aws_iam_role_policy_attachment" "agentgateway_bedrock" {
  count = var.enable_agentgateway_bedrock ? 1 : 0

  role       = aws_iam_role.agentgateway_bedrock[0].name
  policy_arn = aws_iam_policy.agentgateway_bedrock[0].arn
}

# Binds to the DATA PLANE ServiceAccount ("agentgateway"), not the controller
# ("agentgateway-controller"). The controller only reconciles CRs; the data
# plane proxy is what signs and forwards Bedrock requests.
resource "aws_eks_pod_identity_association" "agentgateway_bedrock" {
  count = var.enable_agentgateway_bedrock ? 1 : 0

  cluster_name    = module.eks.cluster_name
  namespace       = "agentgateway-system"
  service_account = "agentgateway"
  role_arn        = aws_iam_role.agentgateway_bedrock[0].arn
}

output "agentgateway_bedrock_role_arn" {
  description = "Role the agentgateway data plane assumes for Bedrock access."
  value       = var.enable_agentgateway_bedrock ? aws_iam_role.agentgateway_bedrock[0].arn : ""
}
