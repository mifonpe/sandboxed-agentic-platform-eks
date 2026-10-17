# Coder workspace template — Claude Code on Kata, wired to the MCP sandbox server.
#
# Upload with the Coder CLI from this directory:
#   coder templates push kubernetes-kata -d .
#
# Uses the stock codercom/example-base:ubuntu image and installs Claude Code at
# startup — nothing is built or pushed for this workshop. See the startup_script
# on coder_agent.main.
#
# What this template assumes already exists in the cluster. All of it is created
# by the make targets, NOT by this template:
#   ServiceAccount coder-workspace    make deploy-coder-mcp  (Bedrock Pod Identity binds to it)
#   ConfigMap      claude-mcp-config  make deploy-coder-mcp  (.mcp.json, token is a placeholder)
#   Secret         mcp-token-<user>   make deploy-coder-mcp CODER_USER=<user>
#   RuntimeClass   kata-clh           terraform (kata-deploy.tf)
#   StorageClass   ebs-sc             terraform (ebs-csi-driver.tf), cluster default
#
# The workspace pod itself runs INSIDE a Kata microVM (runtime_class_name below),
# so the agent's own session is kernel-isolated from the node, independently of
# the separately-vended per-call sandboxes it reaches through MCP.

terraform {
  required_providers {
    coder      = { source = "coder/coder" }
    kubernetes = { source = "hashicorp/kubernetes" }
  }
}

provider "kubernetes" {
  # Empty config_path: the Coder provisioner runs in-cluster and uses its own
  # ServiceAccount. Set this only when running the provisioner outside the cluster.
  config_path = null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

################################################################################
# Parameters
################################################################################

variable "namespace" {
  type        = string
  description = "Namespace holding the workspace objects. Must match CODER_NAMESPACE in the Makefile, or the ConfigMap and Secret are not found."
  default     = "coder"
}

# Public Coder base image — nothing is built or pushed for this workshop.
# Claude Code and the AWS CLI are installed by the startup script below, so the
# image stays stock and there is no ECR repo or build step to keep in sync.
#
# The tradeoff is that a workspace start depends on npm being reachable. Bake an
# image instead if that dependency ever becomes a problem on the day.
variable "workspace_image" {
  type        = string
  description = "Workspace container image."
  default     = "codercom/example-base:ubuntu"
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU"
  description  = "Cores. Kata boots a VM per pod, so this is VM-sized, not cgroup-sized."
  default      = "2"
  type         = "number"
  mutable      = true
  order        = 1
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GiB)"
  default      = "4"
  type         = "number"
  mutable      = true
  order        = 2
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size (GiB)"
  description  = "Persistent /home/coder. Survives stop/start; deleted with the workspace."
  default      = "20"
  type         = "number"
  # Immutable: a PVC cannot shrink, and growing it needs a resize the template
  # does not perform. Changing it would force a replace and silently drop data.
  mutable = false
  order   = 3
}

################################################################################
# Agent
################################################################################

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"

  # Model traffic goes through agentgateway, NOT direct to Bedrock.
  #
  # CLAUDE_CODE_USE_BEDROCK is deliberately unset: in Bedrock mode the SDK signs
  # SigV4 itself and talks to AWS directly, which bypasses the gateway and with
  # it every per-persona policy. Pointing ANTHROPIC_BASE_URL at the gateway makes
  # the SAME Cognito token that authorizes MCP tools also authorize the model —
  # one identity, one enforcement point, for both planes.
  #
  # The gateway holds the only Bedrock IAM on this path and signs with its own
  # Pod Identity role, so no AWS credential is needed in the workspace at all.
  # ANTHROPIC_AUTH_TOKEN is NOT set here: coder_agent.env values are rendered at
  # provision time, so a $${COGNITO_TOKEN} reference would be a literal string,
  # not the running pod's env var. It is set as a container env below, sourced
  # from the per-user Secret.
  env = {
    ANTHROPIC_BASE_URL = "http://agentgateway.agentgateway-system.svc.cluster.local/bedrock"
    # Must be a model the gateway's IAM role permits — a model outside it returns
    # a Bedrock 403 even for an allowed persona. See var.gateway_bedrock_model_id
    # in terraform/variables.tf.
    ANTHROPIC_MODEL = "eu.anthropic.claude-sonnet-4-5-20250929-v1:0"
  }

  # The image is stock, so Claude Code and the AWS CLI are installed here.
  #
  # non-blocking: a failed install must not mark the agent unhealthy and make the
  # workspace unreachable — a shell the attendee can debug in is worth more than
  # a workspace that refuses to start. The script reports what is missing instead.
  #
  # Installs land under $HOME (~/.local), which is the home PVC, so they persist
  # across restarts and the download only happens on a fresh workspace.
  startup_script_behavior = "non-blocking"
  startup_script          = <<-EOT
    set -u

    export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

    # Official installer, NOT `npm install -g`: codercom/example-base:ubuntu ships
    # no node and no npm, so the npm route fails instantly. This installer bundles
    # its own runtime and only needs curl, which the image does have.
    if ! command -v claude >/dev/null 2>&1; then
      echo "installing claude code..."
      curl -fsSL https://claude.ai/install.sh | bash \
        || echo "WARNING: claude code install failed — check egress to claude.ai"
    fi

    # AWS CLI is here to PROVE the workspace has no AWS identity: with
    # enable_coder_bedrock = false there is no Pod Identity association, so
    # `aws sts get-caller-identity` fails — which is the point. Model access goes
    # through agentgateway, which signs to Bedrock with its own role. Never
    # required by Claude Code, so a failed install is only a warning.
    if ! command -v aws >/dev/null 2>&1; then
      echo "installing aws cli..."
      curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscli.zip \
        && unzip -q /tmp/awscli.zip -d /tmp \
        && /tmp/aws/install --install-dir "$HOME/.aws-cli" --bin-dir "$HOME/.local/bin" \
        && rm -rf /tmp/aws /tmp/awscli.zip \
        || echo "WARNING: aws cli install failed"
    fi

    # code-server backs the coder_app on :13337. The installer puts it under
    # ~/.local, so it persists in the home PVC like the others.
    if ! command -v code-server >/dev/null 2>&1; then
      echo "installing code-server..."
      curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix="$HOME/.local" \
        || echo "WARNING: code-server install failed — the web IDE will be unavailable"
    fi
    if command -v code-server >/dev/null 2>&1; then
      code-server --auth none --port 13337 >"$HOME/.code-server.log" 2>&1 &
    fi

    # Persist PATH in ~/.profile.
    #
    # ~/.profile, not ~/.bashrc: Coder's terminal opens a LOGIN shell, which reads
    # ~/.profile but never ~/.bashrc (Ubuntu's .bashrc also returns early when
    # non-interactive). A line appended to .bashrc works under `bash -i` and fails
    # in the real terminal, which looks exactly like a failed install.
    #
    # NOT /etc/profile.d either: allow_privilege_escalation = false on the
    # container sets no_new_privs, so sudo cannot run at all. ~/.profile is
    # user-owned, needs no root, and lives on the home PVC so it persists.
    grep -q '.local/bin' "$HOME/.profile" 2>/dev/null \
      || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"

    # .bashrc too, so non-login interactive shells (code-server's terminal) agree
    # with the login shell rather than silently differing.
    grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null \
      || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

    echo "--- workspace wiring ---"
    echo "claude:        $(command -v claude || echo 'NOT FOUND')"
    echo "mcp config:    $([ -f "$HOME/.mcp.json" ] && echo present || echo "MISSING - run 'make deploy-coder-mcp CODER_USER=${data.coder_workspace_owner.me.name}'")"
    echo "cognito token: $([ -n "$${COGNITO_TOKEN:-}" ] && echo 'present (60m TTL)' || echo "MISSING - run 'make deploy-coder-mcp CODER_USER=${data.coder_workspace_owner.me.name}'")"
    echo "kata:          $(ls /dev/kvm >/dev/null 2>&1 && echo 'nested kvm visible' || echo 'microVM (no nested kvm, expected)')"
    # CLAUDE_CODE_USE_BEDROCK makes Claude Code sign SigV4 itself and skip the
    # gateway, taking every per-persona policy with it. settings.json outranks
    # env vars and lives on the home PVC, so it survives restarts and token
    # re-mints — surface it here rather than discovering it through a 403.
    echo "model path:    $(grep -q CLAUDE_CODE_USE_BEDROCK "$HOME/.claude/settings.json" 2>/dev/null && echo 'DIRECT TO BEDROCK - gateway BYPASSED, remove CLAUDE_CODE_USE_BEDROCK from ~/.claude/settings.json' || echo 'via agentgateway (correct)')"
  EOT

  metadata {
    display_name = "CPU"
    key          = "cpu"
    script       = "top -bn1 | awk '/Cpu/ {printf \"%.0f%%\", 100 - $8}'"
    interval     = 10
    timeout      = 5
  }

  metadata {
    display_name = "Memory"
    key          = "mem"
    script       = "free -h | awk '/Mem:/ {print $3 \"/\" $2}'"
    interval     = 10
    timeout      = 5
  }

  metadata {
    display_name = "Home disk"
    key          = "disk"
    script       = "df -h /home/coder | awk 'NR==2 {print $3 \"/\" $2}'"
    interval     = 60
    timeout      = 5
  }
}

################################################################################
# Persistent home
#
# WaitForFirstConsumer on ebs-sc means the volume is provisioned in whichever AZ
# the pod lands in — and from then on the workspace is pinned to that AZ, since
# an EBS volume cannot cross one. Kata nodes must therefore exist in that AZ for
# the workspace to restart. kata_node_desired_size >= 2 across subnets covers this.
################################################################################

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
  }

  wait_until_bound = false

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "ebs-sc"
    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
  }
}

################################################################################
# Workspace pod — Deployment, not bare Pod, so `kubectl rollout restart` works.
# `make refresh-token` relies on that to pick up a re-minted Cognito token.
################################################################################

resource "kubernetes_deployment" "main" {
  # Only exists while the workspace is started. Coder stops a workspace by
  # scaling this to zero via count, leaving the PVC intact.
  count = data.coder_workspace.me.start_count

  # Without this, the Deployment is created while the PVC is still Pending and
  # the pod sits unschedulable instead of waiting.
  depends_on = [kubernetes_persistent_volume_claim.home]

  wait_for_rollout = false

  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      # `make refresh-token` selects on this label to restart the right workspace.
      "com.coder.user.username" = data.coder_workspace_owner.me.name
    }
  }

  spec {
    replicas = 1
    # Recreate, not RollingUpdate: the home PVC is ReadWriteOnce, so a second pod
    # could never attach it and a rolling update would deadlock.
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "coder-workspace"
          "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
          "com.coder.user.username"    = data.coder_workspace_owner.me.name
        }
      }

      spec {
        ########################################################################
        # Kata isolation.
        #
        # runtime_class_name boots this pod in its own microVM with its own
        # kernel. The node group is tainted kata=true:NoSchedule and labelled
        # workload-type=kata (terraform/kata-nodegroup.tf), so BOTH the
        # toleration and the node_selector are required: the selector alone
        # leaves the pod unschedulable on the taint, and the toleration alone
        # lets it land on a core node that has no Kata runtime, where the pod
        # fails with "RuntimeClass kata-clh not found".
        ########################################################################
        runtime_class_name = "kata-clh"

        node_selector = {
          "workload-type" = "kata"
        }

        toleration {
          key      = "kata"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }

        # Dedicated SA, not "default". It carries no Bedrock IAM by default
        # (var.enable_coder_bedrock is false — model access goes through
        # agentgateway), but it stays named so an association can be attached
        # deliberately rather than landing on every pod in the namespace.
        service_account_name = "coder-workspace"

        # The workspace runs attendee-controlled code with a shell, so it gets no
        # Kubernetes credential. coder-workspace has no RoleBindings today, which
        # makes the mounted token harmless NOW — but binding a Role to it later
        # for convenience would silently turn every workspace into a cluster
        # client. Same reason the sandbox template sets this.
        automount_service_account_token = false

        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        container {
          name              = "dev"
          image             = var.workspace_image
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-c", coder_agent.main.init_script]

          security_context {
            run_as_user                = 1000
            allow_privilege_escalation = false
          }

          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }

          # The per-user Cognito token. Claude Code expands ${COGNITO_TOKEN} out
          # of .mcp.json from this env var, which is what lets the ConfigMap be
          # shared while the credential stays per-user.
          #
          # optional = true so a workspace still starts before any token has been
          # minted — the startup script reports it as missing instead.
          env {
            name = "COGNITO_TOKEN"
            value_from {
              secret_key_ref {
                name     = "mcp-token-${data.coder_workspace_owner.me.name}"
                key      = "token"
                optional = true
              }
            }
          }

          # The model credential IS the Cognito token — same Secret, same claim
          # the MCP tool policy reads. The gateway validates it, authorizes the
          # persona, then signs to Bedrock with its own role.
          env {
            name = "ANTHROPIC_AUTH_TOKEN"
            value_from {
              secret_key_ref {
                name     = "mcp-token-${data.coder_workspace_owner.me.name}"
                key      = "token"
                optional = true
              }
            }
          }

          env {
            name  = "ANTHROPIC_BASE_URL"
            value = "http://agentgateway.agentgateway-system.svc.cluster.local/bedrock"
          }

          env {
            name  = "ANTHROPIC_MODEL"
            value = "eu.anthropic.claude-sonnet-4-5-20250929-v1:0"
          }

          resources {
            requests = {
              "cpu"    = "${data.coder_parameter.cpu.value * 250}m"
              "memory" = "${data.coder_parameter.memory.value * 512}Mi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }

          volume_mount {
            name       = "home"
            mount_path = "/home/coder"
            read_only  = false
          }

          # sub_path is REQUIRED. /home/coder is the PVC above; mounting a volume
          # at the directory would shadow the entire home. sub_path projects the
          # single file into it instead.
          volume_mount {
            name       = "mcp-config"
            mount_path = "/home/coder/.mcp.json"
            sub_path   = ".mcp.json"
            read_only  = true
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
            read_only  = false
          }
        }

        volume {
          name = "mcp-config"
          config_map {
            name = "claude-mcp-config"
            # optional so a missing ConfigMap does not wedge the pod in
            # ContainerCreating; the startup script reports it instead.
            optional = true
          }
        }
      }
    }
  }
}

################################################################################
# UI
################################################################################

resource "coder_app" "code-server" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "coder_metadata" "workspace" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_deployment.main[0].id

  item {
    key   = "isolation"
    value = "Kata microVM (kata-clh)"
  }
  item {
    key   = "model"
    value = "claude-sonnet-4-5 via agentgateway (Cognito JWT)"
  }
  item {
    key   = "mcp"
    value = "sandbox @ agentgateway.agentgateway-system.svc.cluster.local"
  }
  item {
    key   = "token"
    value = "mcp-token-${data.coder_workspace_owner.me.name} (60m TTL)"
  }
}
