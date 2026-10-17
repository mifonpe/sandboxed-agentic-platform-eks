################################################################################
# agent-sandbox — vends single-use Kata microVM sandboxes on demand
#
# Installed via kubectl apply against the pinned GitHub release asset, matching
# upstream's own documented install method (no Helm chart is published — the
# in-tree helm/ dir has no repo/OCI host, see project docs). Sits ON TOP of the
# existing Kata runtime (kata-deploy.tf) and Kata node group
# (kata-nodegroup.tf) — every vended sandbox runs on runtimeClassName
# "kata-${var.kata_hypervisor}", which is already installed and already targets
# the tainted "kata" node group.
#
# Static warm pool: this is a demo, so a fixed-size WarmPool backed by the
# existing fixed-size Kata node group is the deliberate ceiling on concurrent
# sandboxes (see var.kata_node_max_size). Elastic vending would need a node
# autoscaler that can set nested virtualization — out of scope here.
################################################################################

locals {
  agent_sandbox_version    = "v1.0.4"
  agent_sandbox_runtime    = "kata-${var.kata_hypervisor}"
  agent_sandbox_router_url = "https://raw.githubusercontent.com/kubernetes-sigs/agent-sandbox/refs/tags/${local.agent_sandbox_version}/clients/python/agentic-sandbox-client/sandbox-router/sandbox_router.yaml"
}

# Controller + CRDs (Sandbox, SandboxTemplate, SandboxWarmPool, SandboxClaim),
# controller RBAC and Deployment, in namespace agent-sandbox-system.
resource "null_resource" "agent_sandbox_controller" {
  triggers = {
    cluster_name = module.eks.cluster_name
    region       = local.region
    version      = local.agent_sandbox_version
    # Destroy-time provisioners cannot reference locals or vars — only self.triggers.
    aws_profile = local.aws_profile
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      AWS_PROFILE = local.aws_profile
    }
    command = <<-EOT
      set -euo pipefail
      export KUBECONFIG="$(mktemp)"
      trap 'rm -f "$KUBECONFIG"' EXIT
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} --kubeconfig "$KUBECONFIG"

      kubectl apply --server-side -f "https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${self.triggers.version}/sandbox-with-extensions.yaml"

      kubectl wait --for=condition=Established --timeout=120s \
        crd/sandboxes.agents.x-k8s.io \
        crd/sandboxtemplates.extensions.agents.x-k8s.io \
        crd/sandboxwarmpools.extensions.agents.x-k8s.io \
        crd/sandboxclaims.extensions.agents.x-k8s.io

      kubectl wait --for=condition=Available --timeout=180s \
        -n agent-sandbox-system deploy/agent-sandbox-controller
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    environment = {
      # try(): resources created before aws_profile was added to triggers have it
      # absent from their stored state, and a destroy provisioner reads the OLD
      # triggers -- a bare reference fails with "Missing map element" and blocks
      # the replace. Empty string means the CLI falls back to ambient credentials.
      AWS_PROFILE = try(self.triggers.aws_profile, "")
    }
    command = <<-EOT
      export KUBECONFIG="$(mktemp)"
      trap 'rm -f "$KUBECONFIG"' EXIT
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} --kubeconfig "$KUBECONFIG" || exit 0
      kubectl delete -f "https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${self.triggers.version}/sandbox-with-extensions.yaml" --ignore-not-found --timeout=120s || true
    EOT
  }

  depends_on = [module.eks]
}

# sandbox-router — the only thing allowed to reach into sandbox pods; proxies
# file/exec calls from a broker to whichever Sandbox a SandboxClaim resolves to.
resource "null_resource" "agent_sandbox_router" {
  triggers = {
    cluster_name = module.eks.cluster_name
    region       = local.region
    version      = local.agent_sandbox_version
    router_url   = local.agent_sandbox_router_url
    # Destroy-time provisioners cannot reference locals or vars — only self.triggers.
    aws_profile = local.aws_profile
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      AWS_PROFILE = local.aws_profile
    }
    command = <<-EOT
      set -euo pipefail
      export KUBECONFIG="$(mktemp)"
      trap 'rm -f "$KUBECONFIG"' EXIT
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} --kubeconfig "$KUBECONFIG"

      # Upstream ships ALLOW_UNAUTHENTICATED_ROUTER=false with ROUTER_AUTH_TOKEN
      # commented out, so the router crash-loops until one of the two is set. The
      # router is internal-only (ClusterIP, no external exposure), so unauthenticated
      # is an acceptable default for this demo deployment.
      curl -sSL "${self.triggers.router_url}" \
        | sed 's|$${ROUTER_IMAGE}|us-central1-docker.pkg.dev/k8s-staging-images/agent-sandbox/sandbox-router:latest-main|g' \
        | sed 's|value: "false"|value: "true"|' \
        | kubectl -n agent-sandbox-system apply -f -

      kubectl wait --for=condition=Available --timeout=180s \
        -n agent-sandbox-system deploy/sandbox-router-deployment
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    environment = {
      # try(): resources created before aws_profile was added to triggers have it
      # absent from their stored state, and a destroy provisioner reads the OLD
      # triggers -- a bare reference fails with "Missing map element" and blocks
      # the replace. Empty string means the CLI falls back to ambient credentials.
      AWS_PROFILE = try(self.triggers.aws_profile, "")
    }
    command = <<-EOT
      export KUBECONFIG="$(mktemp)"
      trap 'rm -f "$KUBECONFIG"' EXIT
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} --kubeconfig "$KUBECONFIG" || exit 0
      kubectl delete deploy sandbox-router-deployment -n agent-sandbox-system --ignore-not-found --timeout=60s || true
      kubectl delete svc sandbox-router-svc -n agent-sandbox-system --ignore-not-found --timeout=60s || true
    EOT
  }

  depends_on = [null_resource.agent_sandbox_controller]
}

# Namespace for the SandboxTemplate/WarmPool/Claims.
resource "kubernetes_namespace_v1" "agent_sandbox" {
  metadata {
    name = "agent-sandbox"
    labels = {
      name = "agent-sandbox"
    }
  }

  depends_on = [null_resource.agent_sandbox_controller]
}

# SandboxTemplate + WarmPool live as plain YAML under manifests/kata-python/ so they
# can be read, diffed and `kubectl apply`d without going through Terraform. templatefile
# fills the two values Terraform owns: the runtime class (follows var.kata_node_mode)
# and the warm pool size.
resource "kubectl_manifest" "agent_sandbox_template" {
  yaml_body = templatefile("${path.module}/../manifests/kata-python/sandbox-template.yaml", {
    runtime_class = local.agent_sandbox_runtime
  })

  depends_on = [
    kubernetes_namespace_v1.agent_sandbox,
    null_resource.agent_sandbox_router,
    helm_release.kata_deploy,
  ]
}

resource "kubectl_manifest" "agent_sandbox_warmpool" {
  yaml_body = templatefile("${path.module}/../manifests/kata-python/sandbox-warmpool.yaml", {
    warmpool_replicas = var.agent_sandbox_warmpool_replicas
  })

  depends_on = [kubectl_manifest.agent_sandbox_template]
}
