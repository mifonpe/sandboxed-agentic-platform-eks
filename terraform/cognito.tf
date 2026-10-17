################################################################################
# Cognito user pool — the identity behind per-tool MCP authorization.
#
# Group membership surfaces automatically as the `cognito:groups` claim in the
# access token; agentgateway's authorization policy reads that claim. No custom
# attributes and no pre-token-generation Lambda are needed.
#
# Two personas exist so the policy has something to discriminate BETWEEN: a rule
# that allows everyone proves nothing.
################################################################################

locals {
  # Three personas with genuinely different rights, so the policy has something
  # to discriminate BETWEEN — a rule that allows everyone proves nothing.
  #   developer: execute code (and manage the sandbox it runs in)
  #   analyst:   move files in and out, but never execute
  #   finance:   authenticates successfully and may call nothing
  cognito_personas = {
    "developer" = "Execute code in a sandbox"
    "analyst"   = "Upload and download sandbox files, no execution"
    "finance"   = "No tool access (proves the deny path)"
  }
}

resource "aws_cognito_user_pool" "agents" {
  count = var.enable_cognito ? 1 : 0

  name = "${local.name}-agents"

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_uppercase = true
    require_symbols   = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "admin_only"
      priority = 1
    }
  }

  tags = local.tags
}

# App client WITHOUT a secret, and with USER_PASSWORD_AUTH enabled.
#
# The workshop's client is built for a browser OAuth flow against a Chainlit UI.
# There is no UI here, and a token has to be obtainable from inside the cluster
# for testing, so this client supports a direct username/password exchange
# (initiate-auth) instead. Swap to the authorization-code flow once a real
# front end exists — USER_PASSWORD_AUTH sends the password to the API and should
# not outlive the testing phase.
resource "aws_cognito_user_pool_client" "agents" {
  count = var.enable_cognito ? 1 : 0

  name         = "${local.name}-mcp-client"
  user_pool_id = aws_cognito_user_pool.agents[0].id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # Access tokens are what agentgateway validates; keep them short-lived.
  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_group" "persona" {
  for_each = var.enable_cognito ? local.cognito_personas : {}

  name         = each.key
  user_pool_id = aws_cognito_user_pool.agents[0].id
  description  = each.value
}

resource "random_password" "persona" {
  for_each = var.enable_cognito ? local.cognito_personas : {}

  length  = 16
  special = false
  # Satisfy the pool policy (upper + lower + number).
  min_lower   = 2
  min_upper   = 2
  min_numeric = 2
}

# Test users with permanent passwords. message_action = SUPPRESS so Cognito does
# not try to email a welcome message to a nonexistent address.
resource "aws_cognito_user" "persona" {
  for_each = var.enable_cognito ? local.cognito_personas : {}

  user_pool_id   = aws_cognito_user_pool.agents[0].id
  username       = each.key
  password       = random_password.persona[each.key].result
  message_action = "SUPPRESS"

  attributes = {
    email          = "${each.key}@example.invalid"
    email_verified = "true"
  }
}

resource "aws_cognito_user_in_group" "persona" {
  for_each = var.enable_cognito ? local.cognito_personas : {}

  user_pool_id = aws_cognito_user_pool.agents[0].id
  group_name   = aws_cognito_user_group.persona[each.key].name
  username     = aws_cognito_user.persona[each.key].username
}

################################################################################
# Outputs consumed when rendering manifests/policies/step3-cognito-authz.yaml.
################################################################################

output "cognito_issuer" {
  description = "JWT issuer (iss claim) that agentgateway validates against."
  value       = var.enable_cognito ? "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.agents[0].id}" : ""
}

output "cognito_jwks_host" {
  description = "Host serving the JWKS; agentgateway reaches it via a static AgentgatewayBackend, not a bare URL."
  value       = var.enable_cognito ? "cognito-idp.${var.region}.amazonaws.com" : ""
}

output "cognito_jwks_path" {
  description = "JWKS path on that host."
  value       = var.enable_cognito ? "/${aws_cognito_user_pool.agents[0].id}/.well-known/jwks.json" : ""
}

output "cognito_client_id" {
  description = "App client id; becomes the `audiences` entry in the JWT policy."
  value       = var.enable_cognito ? aws_cognito_user_pool_client.agents[0].id : ""
}

output "cognito_user_passwords" {
  description = "Generated passwords for the test personas."
  value       = var.enable_cognito ? { for k, v in random_password.persona : k => v.result } : {}
  sensitive   = true
}
