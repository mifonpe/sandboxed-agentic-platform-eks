################################################################################
# agentgateway — AI-native proxy for MCP tool servers and agent-to-agent traffic.
#
# The point of this file is the enforcement POINT, not the proxy: agentgateway is
# where JWT authn and per-tool authz land (AgentgatewayPolicy with
# traffic.jwtAuthentication + backend.mcp.authorization), so a specific identity
# can be allowed exactly one tool on one MCP server.
#
# What is here: Gateway API CRDs + agentgateway CRDs + the controller + a base
# Gateway. What is NOT here: any AgentgatewayBackend or policy — those target MCP
# servers that do not exist yet. Add them when there is a tool server to front.
#
# Gated behind var.enable_agentgateway (default true); set it false to skip the
# whole stack.
################################################################################

locals {
  gateway_api_version  = "v1.5.1"
  agentgateway_version = "v1.3.1"

  # Experimental channel, not standard: policy-adjacent types (BackendTLSPolicy
  # v1alpha3 among them) only ship there, and the authz work will want them.
  gateway_api_crd_url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${local.gateway_api_version}/experimental-install.yaml"

  agentgateway_crd_base = "https://raw.githubusercontent.com/agentgateway/agentgateway/${local.agentgateway_version}/controller/install/helm/agentgateway-crds/templates"
  agentgateway_crd_files = [
    "agentgateway.dev_agentgatewaybackends.yaml",
    "agentgateway.dev_agentgatewayparameters.yaml",
    "agentgateway.dev_agentgatewaypolicies.yaml",
  ]
}

# CRDs go in via `kubectl apply --server-side`, NOT Helm: the CRD charts bundle
# multi-megabyte schemas and Helm stores a whole release in a Secret capped at
# 1 MiB, which gateway-api blows outright ("Secret is invalid: data: Too long").
# Server-side apply writes them directly with no release Secret and no size cap.
#
# --validate=false because client-side validation first downloads the API
# server's aggregated OpenAPI doc, and each batch of server-side-applied CRDs
# makes the API server rebuild that doc — the fetch can fail mid-rebuild and
# kubectl then falls back to localhost:8080 and dies. Validating a CRD is
# pointless anyway; it is a self-contained schema document.
resource "null_resource" "gateway_crds" {
  count = var.enable_agentgateway ? 1 : 0

  triggers = {
    cluster_name         = module.eks.cluster_name
    region               = var.region
    gateway_api_version  = local.gateway_api_version
    agentgateway_version = local.agentgateway_version
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    # The AWS provider's `profile` does not reach provisioners — they shell out to
    # the CLI, which reads AWS_PROFILE from the environment.
    environment = {
      AWS_PROFILE = local.aws_profile
    }

    command = <<-EOT
      set -euo pipefail
      export KUBECONFIG="$(mktemp)"
      trap 'rm -f "$KUBECONFIG"' EXIT
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} --kubeconfig "$KUBECONFIG"

      kubectl apply --server-side --validate=false -f "${local.gateway_api_crd_url}"
      for f in ${join(" ", local.agentgateway_crd_files)}; do
        kubectl apply --server-side --validate=false -f "${local.agentgateway_crd_base}/$f"
      done

      # Block until Established so the Helm release and any CR apply do not race
      # CRD registration.
      kubectl wait --for=condition=Established --timeout=120s \
        crd/gateways.gateway.networking.k8s.io \
        crd/agentgatewaybackends.agentgateway.dev \
        crd/agentgatewaypolicies.agentgateway.dev
    EOT
  }

  depends_on = [module.eks]
}

resource "helm_release" "agentgateway" {
  count = var.enable_agentgateway ? 1 : 0

  name             = "agentgateway"
  repository       = "oci://cr.agentgateway.dev/charts"
  chart            = "agentgateway"
  version          = local.agentgateway_version
  namespace        = "agentgateway-system"
  create_namespace = true
  wait             = false
  timeout          = 600

  # Rename the CONTROLLER to "agentgateway-controller". By default the chart names
  # the controller Deployment/Service "agentgateway" — the same name the controller
  # then wants for the DATA-PLANE PROXY Deployment it creates for the Gateway named
  # "agentgateway" below. They collide: the controller tries to overwrite its own
  # Deployment, fails on an immutable spec.selector, and loops forever, so the proxy
  # never comes up and nothing routes. This frees the name for the proxy.
  set = [{
    name  = "fullnameOverride"
    value = "agentgateway-controller"
  }]

  depends_on = [null_resource.gateway_crds]
}

# AgentgatewayParameters forces the data-plane Service to ClusterIP. Without it
# agentgateway provisions it as type LoadBalancer with no annotations, and EKS's
# in-tree cloud provider answers that with a public Classic ELB — an unintended
# public endpoint in front of your MCP tools.
resource "kubectl_manifest" "agentgateway_parameters" {
  count = var.enable_agentgateway ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "agentgateway.dev/v1alpha1"
    kind       = "AgentgatewayParameters"
    metadata = {
      name      = "cluster-internal"
      namespace = "agentgateway-system"
    }
    spec = {
      service = {
        spec = {
          type = "ClusterIP"
        }
      }
    }
  })

  depends_on = [helm_release.agentgateway]
}

# Base Gateway — the data plane. Routes and backends are added later, when there
# is an MCP server to front.
resource "kubectl_manifest" "agentgateway_gateway" {
  count = var.enable_agentgateway ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "agentgateway"
      namespace = "agentgateway-system"
    }
    spec = {
      gatewayClassName = "agentgateway"
      infrastructure = {
        parametersRef = {
          group = "agentgateway.dev"
          kind  = "AgentgatewayParameters"
          name  = "cluster-internal"
        }
      }
      listeners = [{
        name     = "http"
        protocol = "HTTP"
        port     = 80
        allowedRoutes = {
          namespaces = { from = "All" }
        }
      }]
    }
  })

  depends_on = [kubectl_manifest.agentgateway_parameters]
}
