# Coding Agents in Kata micro VMs on Amazon EKS

Workshop platform: coding agents in Kata Containers micro VMs on EKS. Each agent pod boots its
own kernel, so agent-executed code never shares one with the node or another tenant. Model and
tool access both go through agentgateway, authorized by the same Cognito JWT.

Based on [aws-samples/sample-aws-eks-kata-for-agents](https://github.com/aws-samples/sample-aws-eks-kata-for-agents)
(MIT-0, [LICENSE](LICENSE)).

Architecture, authorization, model access, Coder templates, Kata/compute detail and what was
trimmed from upstream: [docs/technical-reference.md](docs/technical-reference.md).

| Component | Purpose |
|---|---|
| **EKS 1.36** | Control plane |
| **EKS Managed Node Group** | Kata nodes, nested KVM (c8i/m8i/r8i) or bare metal |
| **Kata Containers** | VM isolation per sandbox pod (QEMU + CLH) |
| **agent-sandbox** | Controller + router vending microVMs on demand (warm pool off by default) |
| **MCP server** | Sandboxed Python execution as MCP tools |
| **agentgateway** | Validates Cognito JWTs, authorizes tool **and** model calls |
| **Cognito** | User pool, three personas, `cognito:groups` claim |
| **Coder** | Workspaces (Helm, not Terraform); run in Kata microVMs |
| **EBS CSI / ALB controller** | `ebs-sc` gp3 default StorageClass; ALB for Coder |


## Prerequisites

AWS CLI (Bedrock model access granted in `eu-west-1`), kubectl, Terraform >= 1.3.2, Helm v3, and
Docker (`build-mcp` builds the image). `make prereqs` checks all five are present and names what
is missing; `make install` runs that check first. Install them with your package manager —
`brew install awscli kubectl terraform helm` on macOS.

## Quick Start

```bash
make install CODER_USER=<coder-user>
```

One confirmation prompt, then the whole environment (~25-30 min). Then upload the template —
see [Coder Workspaces](docs/technical-reference.md#coder-workspaces).

`CODER_USER` is the **Coder** username, not `$USER`. For this demo Coder logs in with GitHub, so
it must match your **GitHub username** — that is what Coder stores as the username, what it
stamps on workspaces as the `com.coder.user.username` label, and therefore what
`make refresh-token` matches on when it restarts your workspace.

It names the Secret the workspace mounts `optional`, so a wrong one starts fine with no token and
Claude Code falls back to calling Bedrock directly. Omit it and `install` does everything else,
then tells you to run `make deploy-coder-mcp` once you know the username. There is no default
precisely because a wrong guess fails silently while an absent one fails loudly.

> Confirm it rather than assuming: `coder whoami`, or the username shown in the Coder UI. A
> GitHub *display name* is not the username, and the two often differ.

### What it runs

Order matters: each step depends on objects the previous one creates, so `install` chains them
serially rather than letting `-j` reorder them. Run any of them on their own to repeat a step.

| # | Target | Creates | Depends on |
|---|---|---|---|
| 1 | `prereqs` | checks aws, kubectl, terraform, helm, docker are installed | — |
| 2 | `bootstrap` | VPC + EKS cluster + EBS CSI IAM | — |
| 3 | `apply` | everything else in Terraform | the cluster existing (Helm/kubectl providers need an API endpoint) |
| 4 | `kubeconfig` | points kubectl at the new cluster | the cluster |
| 5 | `build-mcp` | builds + pushes the MCP image to ECR | the ECR repo, created by `apply` |
| 6 | `deploy-mcp` | MCP server, Service, RBAC, gateway backend + route | the image existing in ECR |
| 7 | `deploy-authz` | Cognito JWT authn + per-persona tool authorization | the MCP backend (policies attach to it) and Cognito outputs |
| 8 | `deploy-model-authz` | routes model traffic through the gateway, authorized by JWT | the gateway's Bedrock IAM role, created by `apply` |
| 9 | `deploy-coder` | Coder (postgres + server) | the EBS StorageClass and the ALB controller |
| 10 | `deploy-coder-mcp` | workspace SA, `.mcp.json`, per-user token | Cognito, for the token it mints |

Both terraform passes run `-auto-approve` under `install` — the single prompt up front replaces
them. Run `make plan` first, or `make bootstrap && make apply` individually, to review each plan.

`bootstrap` is a separate pass because `-target` skips resources Terraform would otherwise create
against an API server that does not exist yet. It must include `module.ebs_csi_driver_irsa`:
without it `-target` leaves the policy unattached and the CSI controller loops on
`UnauthorizedOperation: ec2:DescribeAvailabilityZones`.

### Day-to-day

```bash
make token PERSONA=developer                      # print a token (developer|analyst|finance)
make deploy-coder-mcp CODER_USER=<u> PERSONA=<p>  # SA + ConfigMap + Secret, no restart
make refresh-token    CODER_USER=<u> PERSONA=<p>  # re-mint Secret AND restart the workspace
make gateway-ui                                   # admin UI → localhost:15000/ui/
make model-url                                    # gateway base URL for ANTHROPIC_BASE_URL
make plan / destroy / delete-mcp / delete-coder
```

## Coder template

`make install` deploys Coder but does not upload the workspace template — do it once, by either route.

**CLI** (no zip):

```bash
coder login https://<coder-url>
coder templates push kubernetes-kata -d manifests/coder/template
```

**Web UI** — Templates → New template → Upload:

```bash
make template-zip   # zips manifests/coder/template/main.tf into coder-template.zip
```

`coder-template.zip` is committed, so regenerate it after editing
[main.tf](manifests/coder/template/main.tf) or you upload a stale copy.

Each upload creates a new *version*. Mark it active, then create a new workspace — existing
workspaces stay on the version they were built from. Details:
[technical-reference](docs/technical-reference.md#coder-workspaces).

## Cleanup

```bash
make destroy          # or: make delete-coder / make delete-mcp for one component
```

`scripts/cleanup.sh` removes Helm/kubectl-managed apps *before* Terraform, which is the part that
must happen in that order:

> Coder's Ingress creates an ALB owned by the **aws-load-balancer-controller**, not Terraform.
> Destroying the controller first orphans the ALB, whose ENIs block subnet and internet-gateway
> deletion, which hangs the VPC teardown and strands the node groups behind it.

So the script: (0) uninstalls Coder and the MCP server, deletes every `type: LoadBalancer`
Service, and **waits** for the controller to tear the load balancers down; (1) destroys the
Terraform stack, retrying once after clearing orphaned K8s state; (2) sweeps orphaned
ALBs/NLBs/ELBs then EC2 instances, scoped to the cluster VPC (nodes sit in public subnets, so a
leftover instance holds a public-IP ENI and AWS refuses to detach the IGW); (3) deletes the MCP
ECR repo and the nested-kvm launch template; (4) **verifies**, reporting any surviving VPC, load
balancer, instance, ENI or ASG rather than exiting clean on a half-finished teardown.
