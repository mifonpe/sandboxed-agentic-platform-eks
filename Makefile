REGION ?= eu-west-1
CLUSTER_NAME ?= agents-kata-eks
KATA_MODE ?= nested-kvm
# Comma-separated, e.g. KATA_INSTANCE_TYPES=c8i.4xlarge,c8i.8xlarge. Empty keeps
# the terraform default, which already differs per kata_node_mode.
KATA_INSTANCE_TYPES ?=
# Exported so the AWS CLI, terraform's AWS provider and kubectl all pick it up.
# Leave it empty (AWS_PROFILE= make apply) to use ambient credentials instead.
AWS_PROFILE ?= playground
# Only export when non-empty: an exported but empty AWS_PROFILE makes the CLI
# look for a profile literally named "" and fail, instead of falling back to
# ambient credentials.
ifneq ($(AWS_PROFILE),)
export AWS_PROFILE
else
# An empty AWS_PROFILE inherited from the environment still reaches the CLI,
# which then looks for a profile literally named "" instead of falling back to
# ambient credentials. Unexport it so it is absent, not empty.
unexport AWS_PROFILE
endif

# Passed to terraform as well: local-exec provisioners shell out to the CLI and
# do not inherit the provider's profile argument.
TF_PROFILE_VAR = $(if $(AWS_PROFILE),-var="aws_profile=$(AWS_PROFILE)",)
# `export AWS_PROFILE` above only reaches recipe execution; $(shell ...) in an
# $(eval ...) runs at parse time and needs the flag passed explicitly.
AWS_PROFILE_FLAG = $(if $(AWS_PROFILE),--profile $(AWS_PROFILE),)
# `env -u AWS_PROFILE` on the shell calls below: an empty AWS_PROFILE inherited
# from the caller's environment reaches the CLI as a profile literally named "",
# which errors instead of falling back to ambient credentials. Stripping the var
# and passing --profile explicitly makes both modes work.
# Must match var.mcp_image_tag in terraform/variables.tf, or the Deployment pulls
# a tag that was never pushed.
MCP_IMAGE_TAG ?= v0.1.0

# Shared by bootstrap/plan/apply so they cannot drift apart — a bootstrap and an
# apply disagreeing on these would plan a replacement of what the other built.
#
# kata_instance_types is a terraform LIST, so a comma-separated value has to
# become ["a","b"]; only passed when set, since the default differs per
# kata_node_mode and an empty list would override both.
TF_VARS = -var="region=$(REGION)" -var="name=$(CLUSTER_NAME)" -var="kata_node_mode=$(KATA_MODE)" \
	$(if $(KATA_INSTANCE_TYPES),-var='kata_instance_types=["$(subst $(space),"$(comma)",$(subst $(comma),$(space),$(KATA_INSTANCE_TYPES)))"]',) \
	$(TF_PROFILE_VAR)

# $(subst) above needs literals for space and comma; neither can be written
# inline inside a function call.
comma := ,
empty :=
space := $(empty) $(empty)

.PHONY: help install prereqs destroy fmt validate init bootstrap plan apply kubeconfig build-mcp deploy-mcp delete-mcp deploy-authz deploy-model-authz model-url gateway-ui token deploy-coder-mcp deploy-coder delete-coder refresh-token template-zip

help:
	@echo "make install CODER_USER=<coder-user> - full environment: bootstrap -> apply -> kubeconfig -> mcp -> authz -> coder"
	@echo "                  CODER_USER is your Coder username (GitHub username here), not \$$USER; omit it and the last step is skipped"
	@echo "make prereqs    - check required CLIs are installed (aws, kubectl, terraform, helm, docker)"
	@echo "make destroy    - run cleanup.sh (destroys all resources)"
	@echo "make fmt        - terraform fmt"
	@echo "make validate   - terraform validate"
	@echo "make init       - terraform init"
	@echo "make bootstrap  - terraform apply -target=module.vpc -target=module.ebs_csi_driver_irsa -target=module.eks (VPC + cluster + EBS CSI IRSA only; run once before first plan/apply)"
	@echo "make plan       - terraform plan (assumes launch template + kubeconfig already exist)"
	@echo "make apply      - terraform apply (assumes launch template + kubeconfig already exist)"
	@echo "make kubeconfig - update local kubeconfig for the cluster"
	@echo "make build-mcp  - build and push the MCP server image to ECR (MCP_IMAGE_TAG=$(MCP_IMAGE_TAG))"
	@echo "make deploy-mcp - render manifests/mcp with envsubst and apply them"
	@echo "make delete-mcp - remove the MCP server from the cluster"
	@echo "make deploy-authz - apply the Cognito JWT authn + per-group tool authz policies"
	@echo "make token PERSONA=developer|analyst|finance - print an access token"
	@echo "make deploy-coder-mcp CODER_USER=<name> - wire Claude Code in a workspace to the MCP server"
	@echo "make gateway-ui    - port-forward the agentgateway admin UI (http://localhost:15000/ui/)"
	@echo "make deploy-coder   - install Coder (postgres + server) via helm"
	@echo "make refresh-token CODER_USER=<name> - re-mint the token and restart that user's workspace"
	@echo "make template-zip   - regenerate coder-template.zip from manifests/coder/template (web UI upload)"
	@echo ""
	@echo "Vars: REGION=$(REGION) CLUSTER_NAME=$(CLUSTER_NAME) KATA_MODE=$(KATA_MODE) KATA_INSTANCE_TYPES=$(KATA_INSTANCE_TYPES)"

# Everything Quick Start runs, in the order its dependency table requires.
#
# A plain prerequisite list would let -j reorder these; each step here needs the
# objects the previous one created (the cluster before the Helm providers, the
# ECR repo before the image, the image before the Deployment, the Cognito
# outputs before the policies). Recursive $(MAKE) in the recipe keeps the order
# serial regardless of -j.
#
# deploy-coder-mcp is last and needs CODER_USER: it names the per-user Secret,
# and a wrong one starts a workspace with no token that silently falls back to
# calling Bedrock directly. Skipped when unset rather than defaulting to $(USER),
# which is a LOCAL username and almost never the Coder one.
install: prereqs
	@echo "============================================"
	@echo "  Deploy to AWS"
	@echo "============================================"
	@echo "Region:       $(REGION)"
	@echo "Cluster:      $(CLUSTER_NAME)"
	@echo "Kata mode:    $(KATA_MODE)"
	@echo "Instances:    $(if $(KATA_INSTANCE_TYPES),$(KATA_INSTANCE_TYPES),<terraform default>)"
	@echo "Profile:      $(if $(AWS_PROFILE),$(AWS_PROFILE),<ambient credentials>)"
	@echo "Coder user:   $(if $(CODER_USER),$(CODER_USER) ($(PERSONA)),<skipped - set CODER_USER>)"
	@echo "============================================"
	@# The one gate for the whole run: both terraform passes below are
	@# -auto-approve, so this replaces their prompts rather than adding to them.
	@read -p "Proceed? This creates billable AWS resources. (y/N) " -n 1 -r REPLY; echo; \
	  [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ] || { echo "Cancelled."; exit 1; }
	$(MAKE) bootstrap AUTO_APPROVE=-auto-approve
	$(MAKE) apply AUTO_APPROVE=-auto-approve
	$(MAKE) kubeconfig
	$(MAKE) build-mcp
	$(MAKE) deploy-mcp
	$(MAKE) deploy-authz
	$(MAKE) deploy-model-authz
	$(MAKE) deploy-coder
ifneq ($(CODER_USER),)
	$(MAKE) deploy-coder-mcp CODER_USER=$(CODER_USER) PERSONA=$(PERSONA)
endif
	@echo ""
	@echo "============================================"
	@echo "  Environment ready"
	@echo "============================================"
ifeq ($(CODER_USER),)
	@echo ""
	@echo "SKIPPED: deploy-coder-mcp (no CODER_USER). Run it once you have a"
	@echo "Coder username: make deploy-coder-mcp CODER_USER=<coder-user>"
endif
	@echo ""
	@echo "Next: upload the workspace template"
	@echo "  coder templates push kubernetes-kata -d manifests/coder/template"
	@echo "Coder ALB: kubectl get ingress coder -n $(CODER_NAMESPACE)"

# Verify the CLIs the deploy needs are present, and stop with the install hint
# if any are missing.
#
# A CHECK, not an installer: `make install` is the deploy, and silently
# sudo-installing system packages is not something a deploy target should do.
# Plain sh so it works on macOS's bash 3.2 as well as Linux.
prereqs:
	@missing=""; \
	for c in aws kubectl terraform helm docker; do \
	  command -v $$c >/dev/null 2>&1 || missing="$$missing $$c"; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "ERROR: missing required tools:$$missing"; \
	  echo ""; \
	  echo "  macOS:  brew install awscli kubectl terraform helm   (Docker Desktop for docker)"; \
	  echo "  Linux:  see the vendors' install docs, or your package manager"; \
	  exit 1; \
	fi
	@echo "Prerequisites OK: aws, kubectl, terraform, helm, docker"

destroy:
	./scripts/cleanup.sh --region $(REGION) --cluster-name $(CLUSTER_NAME) $(if $(AWS_PROFILE),--profile $(AWS_PROFILE),)

fmt:
	terraform -chdir=terraform fmt -recursive

validate:
	terraform -chdir=terraform validate

init:
	terraform -chdir=terraform init

# AUTO_APPROVE is set by `make install`, which runs the whole chain unattended
# and would otherwise stop on terraform's approve prompt in the middle. Empty
# for a standalone bootstrap/apply, where reviewing the plan is the point.
AUTO_APPROVE ?=

bootstrap: init
	terraform -chdir=terraform apply -target=module.vpc -target=module.ebs_csi_driver_irsa -target=module.eks $(TF_VARS) $(AUTO_APPROVE)

plan: init
	terraform -chdir=terraform plan $(TF_VARS)

apply: init
	terraform -chdir=terraform apply $(TF_VARS) $(AUTO_APPROVE)

# --profile like every other AWS call here: without it the CLI uses ambient
# credentials, and update-kubeconfig either fails or writes a context pointing at
# whatever account those credentials belong to.
kubeconfig:
	aws eks --region $(REGION) $(AWS_PROFILE_FLAG) update-kubeconfig --name $(CLUSTER_NAME)

# Build and push the MCP server image. The ECR repo is created by terraform
# (mcp.tf), so run this after an apply — then `kubectl rollout restart` the
# deployment, or bump MCP_IMAGE_TAG and re-apply, to pick up a new build.
#
# --platform linux/amd64 is explicit because the nodes are amd64 and a plain
# build on an Apple Silicon laptop produces an arm64 image that lands in ECR and
# fails at runtime with "exec format error".
#
# buildx with --push, not build-then-push: the docker-container driver keeps the
# result in the build cache rather than the local image store, so a separate
# `docker push` fails with "image not known". --push sends it straight to ECR.
build-mcp:
	$(eval ACCOUNT_ID := $(shell env -u AWS_PROFILE aws sts get-caller-identity $(AWS_PROFILE_FLAG) --query Account --output text))
	@test -n "$(ACCOUNT_ID)" || { echo "ERROR: could not resolve AWS account id (profile '$(AWS_PROFILE)'). Check credentials."; exit 1; }
	$(eval REGISTRY := $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com)
	$(eval IMAGE := $(REGISTRY)/$(CLUSTER_NAME)-mcp-sandbox:$(MCP_IMAGE_TAG))
	aws ecr get-login-password --region $(REGION) $(AWS_PROFILE_FLAG) \
		| docker login --username AWS --password-stdin $(REGISTRY)
	docker buildx build --platform linux/amd64 -t $(IMAGE) --push mcp/
	@echo ""
	@echo "Pushed $(IMAGE)"
	@echo "Roll it out: kubectl -n mcp rollout restart deploy/mcp-sandbox"

# Values substituted into manifests/mcp/*.yaml. MCP_NAMESPACE is where the server
# runs; SANDBOX_NAMESPACE/WARMPOOL are what it creates SandboxClaims against and
# must match manifests/kata-python/sandbox-warmpool.yaml.
MCP_NAMESPACE     ?= mcp
SANDBOX_NAMESPACE ?= agent-sandbox
SANDBOX_WARMPOOL  ?= kata-python-pool

# envsubst only expands the names listed, so a literal $$(...) or $$VAR elsewhere
# in a manifest survives untouched.
MCP_VARS = '$$image $$namespace $$sandbox_namespace $$warmpool'

deploy-mcp:
	$(eval ACCOUNT_ID := $(shell env -u AWS_PROFILE aws sts get-caller-identity $(AWS_PROFILE_FLAG) --query Account --output text))
	@test -n "$(ACCOUNT_ID)" || { echo "ERROR: could not resolve AWS account id (profile '$(AWS_PROFILE)'). Check credentials."; exit 1; }
	$(eval export image := $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/$(CLUSTER_NAME)-mcp-sandbox:$(MCP_IMAGE_TAG))
	$(eval export namespace := $(MCP_NAMESPACE))
	$(eval export sandbox_namespace := $(SANDBOX_NAMESPACE))
	$(eval export warmpool := $(SANDBOX_WARMPOOL))
	kubectl create namespace $(MCP_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@for f in manifests/mcp/serviceaccount.yaml manifests/mcp/role.yaml \
	          manifests/mcp/rolebinding.yaml manifests/mcp/deployment.yaml \
	          manifests/mcp/service.yaml manifests/mcp/networkpolicy.yaml \
	          manifests/mcp/backend.yaml; do \
		echo ">>> $$f"; \
		envsubst $(MCP_VARS) < $$f | kubectl apply -f -; \
	done
	@echo ""
	@echo "Applied. Image: $(image)"
	@echo "Watch: kubectl -n $(MCP_NAMESPACE) rollout status deploy/mcp-sandbox"

delete-mcp:
	-kubectl delete -n $(MCP_NAMESPACE) deploy/mcp-sandbox svc/mcp-sandbox sa/mcp-sandbox netpol/mcp-sandbox-gateway-only --ignore-not-found
	-kubectl delete -n $(SANDBOX_NAMESPACE) role/mcp-sandbox-claims rolebinding/mcp-sandbox-claims --ignore-not-found

# Render the Cognito authz policies from terraform outputs and apply them.
# Replaces the tool-only rule from step 2 with one that also checks
# cognito:groups, and turns on JWT validation at the gateway.
deploy-authz:
	$(eval export namespace := $(MCP_NAMESPACE))
	$(eval export cognito_issuer := $(shell terraform -chdir=terraform output -raw cognito_issuer))
	$(eval export cognito_jwks_host := $(shell terraform -chdir=terraform output -raw cognito_jwks_host))
	$(eval export cognito_jwks_path := $(shell terraform -chdir=terraform output -raw cognito_jwks_path))
	$(eval export cognito_client_id := $(shell terraform -chdir=terraform output -raw cognito_client_id))
	@test -n "$(cognito_issuer)" || { echo "ERROR: cognito_issuer output is empty. Is enable_cognito=true applied?"; exit 1; }
	envsubst '$$namespace $$cognito_issuer $$cognito_jwks_host $$cognito_jwks_path $$cognito_client_id' \
		< manifests/policies/step3-cognito-authz.yaml | kubectl apply -f -
	@echo ""
	@echo "Authn is now Strict: requests without a valid token get 401."
	@echo "Get one with: make token PERSONA=developer"

# Route model traffic through agentgateway, authorized by the Cognito JWT.
#
# Independent of deploy-authz: that governs MCP TOOLS, this governs MODEL access.
# Both read the same cognito:groups claim at the same enforcement point.
#
# Needs enable_agentgateway_bedrock=true applied first (the gateway's Pod
# Identity role); without it the backend exists but every call 403s on IAM.
GATEWAY_MODEL ?= eu.anthropic.claude-sonnet-4-5-20250929-v1:0

deploy-model-authz:
	$(eval export namespace := $(MCP_NAMESPACE))
	$(eval export bedrock_region := $(REGION))
	envsubst '$$namespace $$bedrock_region' < manifests/policies/model-authz.yaml | kubectl apply -f -
	@echo ""
	@echo "Model traffic now routes through the gateway at /bedrock/v1/messages."
	@echo "developer + analyst allowed; finance denied before any AWS call."
	@echo "Point a client at it with: make model-url"

# The in-cluster base URL for Claude Code. ANTHROPIC_BASE_URL wants the prefix
# WITHOUT /v1/messages — the client appends that itself.
model-url:
	@echo "http://agentgateway.agentgateway-system.svc.cluster.local/bedrock"

# agentgateway admin UI — listeners, routes, backends and a CEL playground.
#
# Port-forward only: the UI listens on 15000 on the proxy pod and NO Service
# exposes it (15020/metrics is the only declared containerPort), so it is
# unreachable without this.
#
# Read-only under Kubernetes: config arrives over xDS from the controller, so the
# UI shows what the proxy actually loaded rather than letting you edit it. That
# is what makes it useful — it is the difference between "the policy is applied"
# and "the policy is in a YAML file".
#
# /ui/playground evaluates CEL against sample input: the way to check a
# cognito:groups expression really matches, instead of inferring it from a 403.
#
# deploy/agentgateway, not deploy/agentgateway-proxy as upstream docs say: the
# fullnameOverride in terraform/agentgateway.tf renames the CONTROLLER, leaving
# this name for the data-plane proxy.
gateway-ui:
	@echo "UI: http://localhost:15000/ui/   (ctrl-c to stop)"
	kubectl port-forward -n agentgateway-system deploy/agentgateway 15000:15000

# Print an access token for a test persona. USER_PASSWORD_AUTH is enabled on the
# client precisely so a token is obtainable without a browser.
# Prints only the access token. Used directly rather than via `$(MAKE) -s token`:
# a nested make inside $$(...) echoes the recipe text, which silently ends up in
# the Secret instead of a JWT.
define mint_token
aws cognito-idp initiate-auth --region $(REGION) $(AWS_PROFILE_FLAG) \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $$(terraform -chdir=terraform output -raw cognito_client_id) \
  --auth-parameters USERNAME=$(1),PASSWORD=$$(terraform -chdir=terraform output -json cognito_user_passwords | python3 -c "import json,sys;print(json.load(sys.stdin)['$(1)'])") \
  --query 'AuthenticationResult.AccessToken' --output text
endef

PERSONA ?= developer
token:
	$(eval CLIENT := $(shell terraform -chdir=terraform output -raw cognito_client_id))
	$(eval PW := $(shell terraform -chdir=terraform output -json cognito_user_passwords | python3 -c "import json,sys;print(json.load(sys.stdin)['$(PERSONA)'])"))
	@aws cognito-idp initiate-auth --region $(REGION) $(AWS_PROFILE_FLAG) \
		--auth-flow USER_PASSWORD_AUTH \
		--client-id $(CLIENT) \
		--auth-parameters USERNAME=$(PERSONA),PASSWORD=$(PW) \
		--query 'AuthenticationResult.AccessToken' --output text

# Wire Claude Code inside a Coder workspace to the MCP server behind the gateway.
#
# Two objects with deliberately different handling:
#   ConfigMap  .mcp.json, shared and inert — the token is NOT in it, only the
#              ${COGNITO_TOKEN} placeholder Claude Code expands from the env.
#   Secret     the actual token, one per user. Never written to git or terraform
#              state: it is a 60-minute credential that grants that user's
#              persona, so a shared or committed copy would hand their tool
#              access to anyone who can read it.
#
# Re-run this when the token expires — Claude Code reads the header once at
# startup, so the workspace's Claude session needs restarting too.
CODER_NAMESPACE ?= coder
# No default: this is the CODER username, and $(USER) is the local one. Guessing
# wrong names a Secret the workspace mounts `optional`, so it starts fine with no
# token and Claude Code silently falls back to calling Bedrock directly. Every
# target that needs it fails loudly when unset instead.
CODER_USER      ?=

deploy-coder-mcp:
	$(eval export namespace := $(CODER_NAMESPACE))
	@test -n "$(CODER_USER)" || { echo "ERROR: set CODER_USER=<coder username>"; exit 1; }
	envsubst '$$namespace' < manifests/coder/mcp-client-config.yaml | kubectl apply -f -
	@# The ServiceAccount the Bedrock Pod Identity association binds to. Must exist
	@# before a workspace starts, or the pod gets no AWS credentials.
	envsubst '$$namespace' < manifests/coder/workspace-serviceaccount.yaml | kubectl apply -f -
	@kubectl create secret generic mcp-token-$(CODER_USER) -n $(CODER_NAMESPACE) \
		--from-literal=token="$$($(call mint_token,$(PERSONA)))" \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo ""
	@echo "ConfigMap claude-mcp-config + Secret mcp-token-$(CODER_USER) ($(PERSONA)) applied in $(CODER_NAMESPACE)."
	@echo "Mount them into the workspace: .mcp.json from the ConfigMap, COGNITO_TOKEN from the Secret."

# Coder lives here rather than in terraform for the same reason the MCP server
# does: it is an application, and keeping it out of infra state means a failed
# Helm operation cannot wedge a terraform apply (a stuck chart uninstall has
# already done that once on this cluster).
#
# Order matters: the DB secret and the MCP ConfigMap/Secret must exist before the
# chart, because workspace pods reference them by name at start-up.
# Pinned to what terraform installed, so the migration is not also an upgrade.
CODER_CHART_VERSION    ?= 2.37.3
CODER_PG_CHART_VERSION ?= 18.12.4
CODER_PG_PASSWORD      ?= $(shell openssl rand -hex 16)

deploy-coder:
	$(eval export namespace := $(CODER_NAMESPACE))
	$(eval export cluster_name := $(CLUSTER_NAME))
	kubectl create namespace $(CODER_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@# Reuse the existing password when there is one: rotating it would leave the
	@# running database with credentials the connection string no longer matches.
	$(eval export pg_password := $(shell kubectl get secret coder-db-url -n $(CODER_NAMESPACE) -o jsonpath='{.data.url}' 2>/dev/null | base64 -d | sed 's|.*://coder:||; s|@.*||' || echo))
	$(eval export pg_password := $(if $(pg_password),$(pg_password),$(CODER_PG_PASSWORD)))
	@kubectl create secret generic coder-db-url -n $(CODER_NAMESPACE) \
		--from-literal=url="postgresql://coder:$(pg_password)@coder-postgresql.$(CODER_NAMESPACE).svc.cluster.local:5432/coder?sslmode=disable" \
		--dry-run=client -o yaml | kubectl apply -f -
	envsubst '$$pg_password' < manifests/coder/postgresql-values.yaml > /tmp/coder-pg-values.yaml
	helm upgrade --install coder-postgresql oci://registry-1.docker.io/bitnamicharts/postgresql \
		--version $(CODER_PG_CHART_VERSION) \
		-n $(CODER_NAMESPACE) -f /tmp/coder-pg-values.yaml --wait --timeout 10m
	envsubst '$$namespace $$cluster_name' < manifests/coder/coder-values.yaml > /tmp/coder-values.yaml
	@# --repo rather than a direct .tgz URL: the file is named coder_helm_<v>.tgz,
	@# not coder-<v>.tgz, and letting helm resolve it from the index avoids
	@# depending on that naming.
	helm upgrade --install coder coder --repo https://helm.coder.com/v2 \
		--version $(CODER_CHART_VERSION) \
		-n $(CODER_NAMESPACE) -f /tmp/coder-values.yaml --wait --timeout 10m
	@rm -f /tmp/coder-pg-values.yaml /tmp/coder-values.yaml
	@echo ""
	@echo "Coder installed. ALB: kubectl get ingress coder -n $(CODER_NAMESPACE)"

# Regenerate coder-template.zip from the template directory.
#
# The zip is only for the Coder WEB UI, which wants an archive; `coder templates
# push -d manifests/coder/template` needs no zip at all. It is a second copy of
# main.tf, so it goes stale the moment the template changes — run this after
# editing it.
#
# -X and zipping the FILE (not the directory): a zip rooted at template/, or one
# carrying macOS __MACOSX/._main.tf resource forks, makes the upload hang rather
# than error.
template-zip:
	cd manifests/coder/template && zip -X ../../../coder-template.zip main.tf
	@echo "Regenerated coder-template.zip"

delete-coder:
	-helm uninstall coder -n $(CODER_NAMESPACE)
	-helm uninstall coder-postgresql -n $(CODER_NAMESPACE)
	@echo "PVCs kept on purpose — delete them explicitly to drop the database."

# Re-mint the Cognito token and restart the WORKSPACE that consumes it.
#
# Not the Coder server: it never reads the token. Workspace pods do, and Claude
# Code reads the Authorization header once at start-up, so the pod has to restart
# for a new token to take effect.
refresh-token:
	@test -n "$(CODER_USER)" || { echo "ERROR: set CODER_USER=<coder username>"; exit 1; }
	@kubectl create secret generic mcp-token-$(CODER_USER) -n $(CODER_NAMESPACE) \
		--from-literal=token="$$($(call mint_token,$(PERSONA)))" \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "Token refreshed for $(CODER_USER) ($(PERSONA))."
	@for d in $$(kubectl get deploy -n $(CODER_NAMESPACE) -l com.coder.user.username=$(CODER_USER) -o name); do \
		echo "restarting $$d"; kubectl rollout restart -n $(CODER_NAMESPACE) $$d; \
	done
