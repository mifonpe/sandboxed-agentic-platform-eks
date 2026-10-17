terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.59"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    # kubectl (not hashicorp/kubernetes) for the agent-sandbox and agentgateway CRs:
    # kubernetes_manifest needs the CRD to exist at plan time, which it does not on a
    # first apply.
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
  }
}
