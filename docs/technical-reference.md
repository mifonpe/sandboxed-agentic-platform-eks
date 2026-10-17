# Technical Reference

Detail that used to live in the [README](../README.md): architecture, authorization, model access,
Coder templates, compute and Kata specifics, and what was removed from the upstream sample.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Amazon EKS  (eu-west-1)            │
│  ┌──────────────┐  ┌──────────────────────────────┐ │
│  │  Core Nodes   │  │  Kata Nodes (EKS MNG)        │ │
│  │  (m5.xlarge)  │  │  (m8i, nested KVM enabled)   │ │
│  │               │  │  ┌────────────────────────┐  │ │
│  │  agentgateway │  │  │  Kata VM (CLH/QEMU)    │  │ │
│  │  (ClusterIP   │  │  │  ┌──────────────────┐  │  │ │
│  │   :80)  ▲     │  │  │  │ opencode         │  │  │ │
│  │         └─────┼──┼──┼──┤ Bearer <jwt>     │  │  │ │
│  │  MCP server   │  │  │  └──────────────────┘  │  │ │
│  └──────────────┘  │  └────────────────────────┘  │ │
│                    └──────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
         │  SigV4 (gateway's Pod Identity role)
         ▼  Amazon Bedrock (eu geo inference profile)
```

Adapted from the upstream sample to eu-west-1, EKS 1.36, opencode, with components trimmed.
Deliberately absent: EFS, Prometheus/Grafana, LiteLLM, Hermes, Karpenter — see [Removed](#removed-for-the-workshop).

## Switching personas

Both `deploy-coder-mcp` and `refresh-token` mint a token for `PERSONA` into Secret
`mcp-token-<CODER_USER>`. The variables are independent: `CODER_USER` picks *which Secret*,
`PERSONA` picks *what rights*. `refresh-token` is the switch — re-mints and restarts in one step;
then open a **fresh terminal** and run `claude` (the header is read once at start-up). Same pod,
only the JWT changed.

> Tokens expire after **60 minutes**, killing tools *and* model mid-session. For a longer
> workshop raise `access_token_validity` in [cognito.tf](../terraform/cognito.tf).

> **403 naming `coder-workspace-bedrock`** = Claude Code bypassed the gateway and signed SigV4
> itself. Either the Secret is missing (wrong `CODER_USER` — it must be the GitHub username Coder
> logged you in with) or `~/.claude/settings.json` sets
> `CLAUDE_CODE_USE_BEDROCK` — settings outrank env vars and `/home/coder` is a persistent PVC,
> so it survives restarts and re-mints. Check `echo "${ANTHROPIC_AUTH_TOKEN:0:12}"` (empty →
> stale shell or no Secret) and `cat ~/.claude/settings.json`.

## Make variables

| Variable | Default | |
|---|---|---|
| `REGION` | `eu-west-1` | |
| `CLUSTER_NAME` | `agents-kata-eks` | |
| `AWS_PROFILE` | `playground` | empty uses ambient credentials |
| `KATA_MODE` | `nested-kvm` | or `bare-metal` |
| `KATA_INSTANCE_TYPES` | *(terraform default)* | comma-separated, e.g. `c8i.4xlarge,c8i.8xlarge` |
| `MCP_IMAGE_TAG` | `v0.1.0` | |
| `PERSONA` | `developer` | `analyst`, `finance` |
| `CODER_USER` | *(unset)* | the **Coder** username — your GitHub username in this demo (names the Secret), not the persona |

## Authorization

One Cognito token governs both planes, at one enforcement point.

| Persona | Tools | Model |
|---|---|---|
| `developer` | `run_once`, `run_python`, `create_sandbox`, `destroy_sandbox` | allowed |
| `analyst` | `upload_file`, `download_file`, `list_files`, `create_sandbox`, `destroy_sandbox` | allowed |
| `finance` | none — authenticates, sees an empty tool list | **403 before any AWS call** |

Unauthorized tools are **hidden** from `tools/list`, not merely refused, so a model never sees a
tool it cannot call. `run_once` creates, runs and destroys within the call; the session-scoped
tools keep a sandbox alive across calls, scoped so one caller cannot address another's microVM.
Vended sandboxes are air-gapped (`egress: []`) — no internet, no node metadata endpoint, no
Bedrock IAM of their own.

```
workspace ──Bearer <cognito jwt>──► agentgateway ──SigV4 (gateway's role)──► Bedrock
                                         │ cognito:groups
```

Why route the model through the gateway: Pod Identity binds to a *ServiceAccount*, and every
workspace shares one (`coder-workspace`). Calling Bedrock directly gives every persona identical
model rights and makes no invocation attributable to a user — `finance` would be denied every
tool yet still invoke Claude at full rate. The gateway replaces that shared IAM identity with the
per-user JWT, so the workspace needs **no AWS credentials at all**.

Set by the workspace template:

```bash
ANTHROPIC_BASE_URL=http://agentgateway.agentgateway-system.svc.cluster.local/bedrock
ANTHROPIC_AUTH_TOKEN=<cognito token, from the per-user Secret>
ANTHROPIC_MODEL=eu.anthropic.claude-sonnet-4-5-20250929-v1:0
```

> `CLAUDE_CODE_USE_BEDROCK` is deliberately **unset**: in Bedrock mode the SDK signs SigV4 itself
> and reaches AWS directly, bypassing the gateway and every policy on it.

> `routes: {"/v1/messages": Messages}` in [model-authz.yaml](../manifests/policies/model-authz.yaml)
> is **required** — the default (`Completions`) answers in OpenAI shape, which Claude Code cannot
> parse. It belongs on an `AgentgatewayPolicy`; `spec.ai.routes` on an `AgentgatewayBackend` is
> silently ignored.

Two gates apply independently: passing the CEL check is necessary but not sufficient, since the
gateway's IAM role must also permit the model. A model outside it returns a Bedrock 403 even for
an allowed persona.

### Test it

```bash
kubectl port-forward -n agentgateway-system svc/agentgateway 8080:80 &
export COGNITO_TOKEN=$(make -s token PERSONA=developer)

# tools
claude mcp add --transport http sandbox http://localhost:8080/mcp \
  --header "Authorization: Bearer $COGNITO_TOKEN"

# model — whole path: JWT validation, persona check, SigV4 with the gateway's role
curl -s -X POST http://localhost:8080/bedrock/v1/messages \
  -H "Authorization: Bearer $COGNITO_TOKEN" -H "Content-Type: application/json" \
  -d '{"model": "eu.anthropic.claude-sonnet-4-5-20250929-v1:0",
       "messages": [{"role": "user", "content": "Hi"}], "max_tokens": 20}'
```

Repeat with `PERSONA=finance` for the deny path. `make gateway-ui` exposes a **CEL playground**
that evaluates expressions against sample input — the way to confirm a `cognito:groups`
expression matches, rather than inferring it from a 403. Port-forward only (nothing exposes
:15000), and read-only: config arrives over xDS, so it shows what the proxy loaded, not your YAML.

## Model Access

One path to Bedrock: the gateway's Pod Identity role, authorized per-persona by the JWT. The
workspace holds **no AWS credentials** — `aws sts get-caller-identity` inside it fails, which is
the point.

A second, direct path exists behind `enable_coder_bedrock` (**default false**). It is off because
it is the credential Claude Code falls back to whenever something makes it sign SigV4 itself — a
`CLAUDE_CODE_USE_BEDROCK` in `~/.claude/settings.json` is enough. With the role absent that
bypass fails loudly instead of silently working and quietly skipping every per-persona policy.
Turn it on only to demo the direct path deliberately.

| Variable | Default |
|---|---|
| `gateway_bedrock_model_id` | `eu.anthropic.claude-sonnet-4-5-20250929-v1:0` |
| `bedrock_model_id` | `eu.anthropic.claude-opus-5` (EU geo profile, data stays in EU) |
| `bedrock_region` | `eu-west-1` |

`bedrock_model_id` only scopes the optional direct path; keeping it separate lets the gateway
move without touching it. Use `global.anthropic.claude-opus-5` if EU residency is not required.

Both roles ([coder-bedrock.tf](../terraform/coder-bedrock.tf) — only when enabled —
and [agentgateway-bedrock.tf](../terraform/agentgateway-bedrock.tf)) allow `InvokeModel`,
`InvokeModelWithResponseStream`, `Converse`, `ConverseStream` on the inference-profile ARN **and**
the foundation-model ARN in every Region of its geo (a geo profile routes across them, so `eu-*`
must be allowed, not just `eu-west-1`), plus `List*`/`Get*` for discovery. Change the model
variable and the policy follows.

> IAM is necessary but not sufficient — model access must also be granted in the Bedrock console,
> or invocation fails with `AccessDeniedException`.

> `eu.anthropic.claude-opus-5` is **not invocable in this account**: the profile reports `ACTIVE`,
> but every role fails with `required AWS Marketplace actions ...`. Granting `aws-marketplace:*`
> does not help — the subscription is missing account-wide. Enable it under Bedrock → Model access.

## Coder Workspaces

Coder is installed by `make deploy-coder`, not Terraform: it is an application, and a failed Helm
operation inside Terraform state can wedge an apply.

`make deploy-coder-mcp` creates, in the `coder` namespace: ServiceAccount `coder-workspace` (what
the Bedrock Pod Identity association binds to), ConfigMap `claude-mcp-config` (`.mcp.json`, holding
only a `${COGNITO_TOKEN}` placeholder), and Secret `mcp-token-<user>` (the real token, one per user).

The template must reference them — a complete one is in
[manifests/coder/template/main.tf](../manifests/coder/template/main.tf):

```bash
coder templates push kubernetes-kata -d manifests/coder/template   # CLI: no zip needed
make template-zip                                                  # web UI: regenerates coder-template.zip
```

> `coder-template.zip` is a committed second copy of `main.tf` for the web UI — rerun
> `make template-zip` after editing the template or you upload a stale one. A zip rooted at
> `template/`, or carrying macOS `__MACOSX/._main.tf` forks, hangs the upload rather than
> erroring — hence the `-X` and zipping the file, not the directory.

Uploading creates a new *version*; an existing workspace stays on the one it was built from. Mark
the new version active and create a new workspace to pick up changes.

What the template does:

- **Kata microVM** — `runtime_class_name = "kata-clh"` plus the `workload-type: kata` selector and
  `kata=true:NoSchedule` toleration. Both required: selector alone leaves the pod unschedulable,
  toleration alone lands it on a core node with no Kata runtime.
- **Installs Claude Code at startup** from `https://claude.ai/install.sh` — the stock
  `codercom/example-base:ubuntu` image has no node/npm. Installs land in `$HOME` (the home PVC).
- **PATH in `~/.profile`**, not `~/.bashrc`: Coder's terminal opens a *login* shell.
  (`/etc/profile.d` is out — `allow_privilege_escalation = false` sets `no_new_privs`, so no sudo.)
- **Persistent home** on `ebs-sc`. `WaitForFirstConsumer` pins the workspace to whichever AZ the
  volume lands in, so Kata nodes must exist in that AZ on restart.

## Compute

Spot everywhere by default; each pool independent, each accepts `spot` or `on-demand`.

| Variable | Applies to |
|---|---|
| `core_capacity_type` | Core group — agentgateway, MCP, Coder + its Postgres |
| `kata_capacity_type` | Kata group — the agent sandboxes |

Spot costs you two things: a core-node interruption takes Coder's Postgres with it, and a
Kata-node interruption terminates the microVMs on that node, killing the sessions inside. Fine for
a workshop. Listing several `kata_instance_types` lowers the odds.

### Kata node modes

| Mode | Instances | KVM via |
|---|---|---|
| `nested-kvm` (default) | m8i, c8i, r8i | `cpu_options.nested_virtualization` |
| `bare-metal` | *.metal | native `/dev/kvm` |

```bash
make apply KATA_MODE=bare-metal
```

Both use the node group module's own launch template — AWS provider 6.x added native
`cpu_options`, so nested virt no longer needs a CLI-precreated template.

### Hypervisor

Default **CLH**, best balance of performance and compatibility. `runtimeClassName: kata-clh` or
`kata-qemu`.

| | QEMU | CLH | Firecracker |
|---|---|---|---|
| virtio-fs / hotplug | Yes | Yes | No |
| Boot | ~500ms | ~200ms | ~125ms |
| Memory/VM | ~30-130MB | ~10-20MB | ~5MB |

See [isolation-backends-analysis.md](isolation-backends-analysis.md) for Firecracker and gVisor.

### Kata networking limits

ClusterIP and NodePort are unreachable from Kata VMs (kube-proxy iptables don't apply to VM tap
traffic); pod-to-pod by Pod IP works only within the same security group. Applied here: VPC DNS
(`dnsPolicy: None` + VPC CIDR base+2) instead of CoreDNS ClusterIP, and an SG rule letting Kata
nodes reach core nodes. Vended sandboxes are air-gapped so none of this applies to them; a service
a Kata pod must reach needs an internal NLB (cross-zone), addressed by DNS hostname.

## Deploy a Sandbox

Agent pods go in `agents` with `runtimeClassName: kata-clh`. No sandbox manifests ship yet — the
upstream ones were Hermes/OpenClaw/RayClaw specific and were removed.

## Removed for the workshop

- **LiteLLM** (`litellm.tf`) — proxy, Postgres, internal NLB, scoped Bedrock IAM. Model access now
  goes through agentgateway, authorized per-persona from the JWT; LiteLLM's per-tenant keys and
  budgets were unused on that path.
- **Hermes runtime** (`hermes-*.tf`) and its multi-tenant key provisioning — namespace is now `agents`
- **Prometheus + Grafana** (`monitoring.tf`)
- **EFS + EFS CSI driver** — EBS `gp3` only
- **Upstream sandbox manifests** (`examples/`), the RayClaw ECR build script, Hermes guides
- **Karpenter** (`karpenter.tf`) — it could never provision the nodes that matter here: Kata needs
  `CpuOptions.NestedVirtualization`, which only the EC2 API sets, so Kata nodes come from a managed
  node group regardless. That left it scaling general workloads the fixed core group already
  handles. It was opt-in and off, so nothing in the workshop ever ran it. Removing it also drops
  the `karpenter.sh/discovery` subnet and security-group tags.

## Layout

```
Makefile                 # every deployment step; `make install` chains them in order
terraform/
  eks.tf                 # cluster, core node group, addons
  kata-nodegroup.tf      # Kata MNG (nested-kvm / bare-metal)
  kata-deploy.tf         # Kata Containers Helm release
  agentsandbox.tf        # agent-sandbox controller, router, template, warm pool
  agentgateway.tf        # Gateway API + agentgateway CRDs, controller, Gateway
  agentgateway-bedrock.tf  # Bedrock IAM + Pod Identity for the gateway
  coder-bedrock.tf       # Bedrock IAM + Pod Identity for workspaces
  cognito.tf             # user pool, client, personas, groups
  mcp.tf                 # ECR repository for the MCP server image
mcp/                     # MCP server (FastMCP); built by `make build-mcp`
  server.py              # tool definitions
  sandbox.py             # SandboxClaim lifecycle, router calls
manifests/
  kata-python/           # SandboxTemplate + WarmPool (air-gapped)
  mcp/                   # MCP Deployment, Service, RBAC, gateway backend
  policies/              # agentgateway authn + per-persona tool AND model authz
  coder/template/        # Coder workspace template (Kata + gateway wiring)
scripts/
  cleanup.sh             # ordered teardown (`make destroy`)
```
