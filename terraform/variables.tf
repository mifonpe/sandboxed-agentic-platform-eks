variable "name" {
  description = "Name for the VPC and EKS cluster"
  type        = string
  default     = "agents-kata-eks"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "kata_hypervisor" {
  description = "Kata Containers hypervisor to use: qemu, clh, or fc"
  type        = string
  default     = "clh"

  validation {
    condition     = contains(["qemu", "clh", "fc"], var.kata_hypervisor)
    error_message = "kata_hypervisor must be one of: qemu, clh, or fc"
  }
}

variable "kata_node_mode" {
  description = "Kata node provisioning mode: nested-kvm (8i instances with NestedVirtualization) or bare-metal (.metal instances with native KVM)"
  type        = string
  default     = "nested-kvm"

  validation {
    condition     = contains(["nested-kvm", "bare-metal"], var.kata_node_mode)
    error_message = "kata_node_mode must be one of: nested-kvm, bare-metal"
  }
}

variable "kata_instance_types" {
  description = "Instance types for Kata nodes. For nested-kvm: c8i/m8i/r8i families. For bare-metal: *.metal instances."
  type        = list(string)
  default     = ["m8i.2xlarge", "m8i.4xlarge"]
}

variable "kata_node_min_size" {
  description = "Minimum number of Kata nodes"
  type        = number
  default     = 1
}

variable "kata_node_max_size" {
  description = "Maximum number of Kata nodes"
  type        = number
  default     = 6
}

variable "kata_node_desired_size" {
  description = "Desired number of Kata nodes"
  type        = number
  default     = 2
}

variable "core_capacity_type" {
  description = "Purchase option for the core node group (controllers, MCP server, Coder): spot or on-demand"
  type        = string
  default     = "spot"

  validation {
    condition     = contains(["spot", "on-demand"], var.core_capacity_type)
    error_message = "core_capacity_type must be one of: spot, on-demand"
  }
}

variable "kata_capacity_type" {
  description = "Purchase option for the Kata node group: spot or on-demand. Spot interruption kills running agent sandboxes."
  type        = string
  default     = "on-demand"

  validation {
    condition     = contains(["spot", "on-demand"], var.kata_capacity_type)
    error_message = "kata_capacity_type must be one of: spot, on-demand"
  }
}

variable "is_china_region" {
  description = "Whether the deployment targets AWS China region"
  type        = bool
  default     = null
}

variable "access_entries" {
  description = "Map of access entries for the EKS cluster"
  type        = any
  default     = {}
}

variable "kms_key_admin_roles" {
  description = "List of IAM role ARNs that should be KMS key administrators"
  type        = list(string)
  default     = []
}

# 0 by default: each replica is a microVM sitting idle on a Kata node, a standing
# cost whether or not anyone claims a sandbox.
#
# An empty pool does NOT block claims. Measured on a live cluster at replicas 0:
# the claim resolves and the cold Kata boot reaches Ready in 3.9s, against a
# READY_TIMEOUT of 180s (mcp/sandbox.py). Raise this to trade the idle capacity
# back for that latency.
#
# The apparent reason is that warmPoolRef names a template rather than requiring
# available stock — but that is inferred from the behaviour, not confirmed
# against the agent-sandbox controller source, which is applied from a release
# URL and not vendored here. The 3.9s measurement is the part to rely on.
variable "agent_sandbox_warmpool_replicas" {
  description = "Pre-booted Kata microVMs held by the SandboxWarmPool. 0 means claims cold-boot. Bounded by the fixed Kata node group."
  type        = number
  default     = 0
}

variable "aws_profile" {
  description = "AWS CLI profile used by local-exec provisioners (they do not inherit the provider's profile argument). Empty uses the ambient credentials."
  type        = string
  default     = ""
}

variable "enable_mcp_sandbox" {
  description = "Create the ECR repository for the MCP server image. The server itself is deployed with `make deploy-mcp`."
  type        = bool
  default     = true
}

# OFF by default: the workspace template routes model traffic through
# agentgateway, so this role is unused — and leaving it attached is an active
# hazard. It is the credential Claude Code falls back to whenever something makes
# it sign SigV4 itself (CLAUDE_CODE_USE_BEDROCK in ~/.claude/settings.json, which
# outranks env vars and persists on the home PVC). That bypasses the gateway and
# every per-persona policy on it.
#
# With no role the bypass fails loudly with "no credentials" instead of silently
# succeeding. The only reason it failed loudly BEFORE was that this role happened
# to be scoped to a different model than the gateway path — had both allowed the
# same model, the bypass would have worked and the authorization demo would have
# proven nothing.
#
# Set true only to demonstrate the direct-to-Bedrock path deliberately.
variable "enable_coder_bedrock" {
  description = "Create the IAM role letting Coder workspaces invoke Bedrock DIRECTLY, bypassing agentgateway. Off: model access goes through the gateway, authorized per-persona by the Cognito JWT."
  type        = bool
  default     = false
}

# Nothing routes through the gateway until manifests/policies/model-authz.yaml
# is applied
# (`make deploy-model-authz`).
variable "enable_agentgateway_bedrock" {
  description = "Create the IAM role letting the agentgateway data plane invoke Bedrock, so model access can be authorized from the Cognito JWT."
  type        = bool
  default     = true
}

# The model served THROUGH THE GATEWAY. Deliberately separate from
# var.bedrock_model_id (which the workspace role uses), so the gateway path can
# be pointed at a model the account can actually invoke without disturbing it.
#
# NOT claude-opus-5: that profile is ACTIVE in this account but invoking it fails
# with "required AWS Marketplace actions ... to enable access to this model" for
# every role tried, including the Coder workspace role. Verified 2026-10-05.
variable "gateway_bedrock_model_id" {
  description = "Bedrock inference profile served through agentgateway."
  type        = string
  default     = "eu.anthropic.claude-sonnet-4-5-20250929-v1:0"
}

variable "gateway_bedrock_foundation_model" {
  description = "Foundation model backing gateway_bedrock_model_id; used for the region-globbed ARN a geo profile needs."
  type        = string
  default     = "anthropic.claude-sonnet-4-5-20250929-v1:0"
}

variable "coder_namespace" {
  description = "Namespace Coder runs in. Coder is installed by `make deploy-coder`, so terraform refers to it by name."
  type        = string
  default     = "coder"
}

variable "coder_workspace_service_account" {
  description = "ServiceAccount workspace pods run as. Deliberately NOT \"default\": that would grant Bedrock to every pod in the namespace."
  type        = string
  default     = "coder-workspace"
}

variable "enable_cognito" {
  description = "Create the Cognito user pool, client, groups and test users backing per-tool MCP authorization."
  type        = bool
  default     = true
}

variable "enable_agentgateway" {
  description = "Install Gateway API CRDs + agentgateway (MCP/A2A proxy). Enforcement point for per-tool JWT authz."
  type        = bool
  default     = true
}

variable "bedrock_model_id" {
  description = "Bedrock model/inference-profile ID the Coder workspace role is scoped to. EU geo profile keeps data in EU regions."
  type        = string
  default     = "eu.anthropic.claude-opus-5"
}

variable "bedrock_region" {
  description = "Region the Coder workspace role calls Bedrock in. Must match the geo of bedrock_model_id."
  type        = string
  default     = "eu-west-1"
}
