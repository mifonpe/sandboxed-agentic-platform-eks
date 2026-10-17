"""Vend a Kata microVM per call, run code in it, delete it.

One SandboxClaim per run_python call: no state survives between calls, and one
caller's code can never observe another's. The claim is created from a YAML
template (manifests/sandboxclaim.yaml) applied through the K8s API, and deleted
in a finally block. shutdownPolicy: Delete + a TTL is the backstop for when this
process dies mid-run.

This module holds the SandboxClaim RBAC. The microVM itself is air-gapped
(egress: [] on the SandboxTemplate) and holds no credentials.
"""

import base64
import logging
import os
import string
import time
import uuid
from pathlib import Path

import httpx
from kubernetes import client, config

log = logging.getLogger(__name__)

NAMESPACE = os.environ.get("SANDBOX_NAMESPACE", "agent-sandbox")
WARMPOOL = os.environ.get("SANDBOX_WARMPOOL", "kata-python-pool")
ROUTER_URL = os.environ.get(
    "SANDBOX_ROUTER_URL",
    "http://sandbox-router-svc.agent-sandbox-system.svc.cluster.local:8080",
)
RUN_TIMEOUT = int(os.environ.get("SANDBOX_RUN_TIMEOUT", "120"))
READY_TIMEOUT = int(os.environ.get("SANDBOX_READY_TIMEOUT", "180"))
# TTL outlives RUN_TIMEOUT so a slow-but-live run is never reaped mid-flight.
TTL_SECONDS = int(os.environ.get("SANDBOX_TTL", "300"))

MAX_OUTPUT_BYTES = 64 * 1024

_GROUP, _VERSION, _PLURAL = "extensions.agents.x-k8s.io", "v1beta1", "sandboxclaims"
_TEMPLATE = Path(__file__).parent / "manifests" / "sandboxclaim.yaml"


# (session, sandbox id) -> claim name.
#
# Keyed by SESSION, not just sandbox id: the id is an opaque string a caller
# passes back to us, so a flat map would let any authenticated caller drive
# someone else's microVM by learning its name — the analyst reading the
# developer's files. Scoping to the session makes an id from another session
# simply not exist.
#
# In-memory on purpose: a restart forgets everything and the claims' TTL reaps
# the orphans.
# ponytail: single-replica assumption; needs shared state or sticky routing if
# this is ever scaled out.
_CLAIMS: dict[tuple[str, str], str] = {}


def _api():
    _load_kube()
    return client.CustomObjectsApi()


def _delete_claim(api, claim_name: str) -> None:
    try:
        api.delete_namespaced_custom_object(
            _GROUP, _VERSION, NAMESPACE, _PLURAL, claim_name
        )
    except Exception:  # TTL backstop will GC it
        log.exception("claim %s delete failed", claim_name)


def _load_kube():
    """In-cluster config normally; kubeconfig when running this locally."""
    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()


def _cap(text: str | None) -> str:
    """Bound output so a runaway print cannot flood the agent's context."""
    if not text:
        return ""
    data = text.encode("utf-8")
    if len(data) <= MAX_OUTPUT_BYTES:
        return text
    return data[:MAX_OUTPUT_BYTES].decode("utf-8", errors="ignore") + "...[truncated]"


def _render_claim(claim_name: str) -> dict:
    import yaml

    body = string.Template(_TEMPLATE.read_text()).substitute(
        claim_name=claim_name,
        namespace=NAMESPACE,
        warmpool=WARMPOOL,
        ttl_seconds=TTL_SECONDS,
    )
    return yaml.safe_load(body)


def _wait_ready(api, claim_name: str) -> str:
    """Block until the claim resolves to a sandbox; return the sandbox name."""
    deadline = time.monotonic() + READY_TIMEOUT
    while time.monotonic() < deadline:
        claim = api.get_namespaced_custom_object(
            _GROUP, _VERSION, NAMESPACE, _PLURAL, claim_name
        )
        status = claim.get("status", {})
        name = status.get("sandbox", {}).get("name")
        ready = any(
            c.get("type") == "Ready" and c.get("status") == "True"
            for c in status.get("conditions", [])
        )
        if ready and name:
            return name
        time.sleep(1)
    raise TimeoutError(f"claim {claim_name} not ready after {READY_TIMEOUT}s")


# The router is a catch-all passthrough on /{full_path}: it picks the target
# sandbox from HEADERS, not from the URL, then proxies to
# <x-sandbox-id>.<x-sandbox-namespace>.svc.<cluster-domain>:<x-sandbox-port>.
# So the path we send is the RUNTIME's own path (/execute, /upload, ...) with no
# router prefix. Verified against the deployed router's /openapi.json and
# clients/python/.../sandbox_router.py.
SANDBOX_PORT = os.environ.get("SANDBOX_PORT", "8888")


def _headers(sandbox: str) -> dict:
    return {
        "X-Sandbox-Id": sandbox,
        "X-Sandbox-Namespace": NAMESPACE,
        "X-Sandbox-Port": SANDBOX_PORT,
    }


def _execute(sandbox: str, command: str) -> dict:
    """POST /execute -> {stdout, stderr, exit_code}."""
    resp = httpx.post(
        f"{ROUTER_URL}/execute",
        json={"command": command},
        headers=_headers(sandbox),
        timeout=RUN_TIMEOUT,
    )
    resp.raise_for_status()
    result = resp.json()
    return {
        "stdout": _cap(result.get("stdout")),
        "stderr": _cap(result.get("stderr")),
        "exit_code": result.get("exit_code", 0),
    }


def _upload(sandbox: str, name: str, content: str | bytes) -> None:
    """POST /upload (multipart). Used to inject code and data as files, so
    neither has to survive shell quoting and data never passes through the LLM."""
    data = content.encode() if isinstance(content, str) else content
    resp = httpx.post(
        f"{ROUTER_URL}/upload",
        files={"file": (name, data)},
        headers=_headers(sandbox),
        timeout=60,
    )
    resp.raise_for_status()


def _download(sandbox: str, path: str) -> bytes:
    """GET /download/{path} -> raw bytes."""
    resp = httpx.get(
        f"{ROUTER_URL}/download/{path}", headers=_headers(sandbox), timeout=60
    )
    resp.raise_for_status()
    return resp.content


def create_sandbox(session: str) -> str:
    """Create a SandboxClaim, wait for it to resolve, return the sandbox id.

    The caller owns the lifetime from here: the sandbox lives until
    destroy_sandbox, or until the claim's TTL reaps it. That TTL is the only
    thing standing between an abandoned session and a microVM idling forever, so
    it is deliberately short relative to how long a session is expected to last.
    """
    api = _api()
    claim_name = f"s-{uuid.uuid4().hex[:12]}"
    api.create_namespaced_custom_object(
        _GROUP, _VERSION, NAMESPACE, _PLURAL, _render_claim(claim_name)
    )
    try:
        sandbox = _wait_ready(api, claim_name)
    except Exception:
        # Never leak a claim whose sandbox never became ready.
        _delete_claim(api, claim_name)
        raise
    _CLAIMS[(session, sandbox)] = claim_name
    return sandbox


def destroy_sandbox(session: str, sandbox: str) -> dict:
    """Delete the claim backing `sandbox`. Idempotent, and scoped to the session."""
    claim_name = _CLAIMS.pop((session, sandbox), None)
    if claim_name is None:
        # Unknown id, or already destroyed — not an error worth failing a tool call
        # over, and the TTL covers anything this process has forgotten.
        return {"destroyed": False, "reason": "unknown or already destroyed"}
    _delete_claim(_api(), claim_name)
    return {"destroyed": True}


def _require(session: str, sandbox: str) -> str:
    """Reject any sandbox this SESSION did not create.

    The sandbox argument is an arbitrary string from the caller, interpolated
    into a request the router will happily proxy. Checking session ownership is
    what stops one caller addressing another's microVM.
    """
    if (session, sandbox) not in _CLAIMS:
        raise ValueError(f"unknown sandbox: {sandbox}")
    return sandbox


def cleanup_session(session: str) -> int:
    """Destroy every sandbox belonging to a session. Returns how many."""
    owned = [(s, sb) for (s, sb) in _CLAIMS if s == session]
    for key in owned:
        _delete_claim(_api(), _CLAIMS.pop(key))
    return len(owned)


def run_python(session: str, sandbox: str, code: str) -> dict:
    """Run `code` in an existing sandbox. The sandbox survives the call."""
    _upload(_require(session, sandbox), "main.py", code)
    return _execute(sandbox, "python3 main.py")


def upload_file(session: str, sandbox: str, name: str, content: str) -> dict:
    """Write a file into the sandbox's working directory."""
    _upload(_require(session, sandbox), name, content)
    return {"uploaded": name}


def download_file(session: str, sandbox: str, path: str) -> dict:
    """Read a file back out. Returns text, or base64 when it is not UTF-8."""
    raw = _download(_require(session, sandbox), path)
    try:
        return {"path": path, "content": raw.decode("utf-8"), "encoding": "utf-8"}
    except UnicodeDecodeError:
        return {
            "path": path,
            "content": base64.b64encode(raw).decode("ascii"),
            "encoding": "base64",
        }


def list_files(session: str, sandbox: str, path: str = ".") -> dict:
    """List a directory inside the sandbox."""
    resp = httpx.get(
        f"{ROUTER_URL}/list/{path}", headers=_headers(_require(session, sandbox)), timeout=30
    )
    resp.raise_for_status()
    return resp.json()


def run_once(code: str, files: dict[str, str] | None = None) -> dict:
    """Run code in a throwaway sandbox: create, run, destroy.

    The session-scoped tools exist for work that spans calls; this is for the
    common case where nothing needs to survive. Nothing is registered in _CLAIMS
    — the sandbox is unreachable by id and gone before the call returns, so
    there is no session to scope it to.
    """
    api = _api()
    claim_name = f"o-{uuid.uuid4().hex[:12]}"
    api.create_namespaced_custom_object(
        _GROUP, _VERSION, NAMESPACE, _PLURAL, _render_claim(claim_name)
    )
    try:
        sandbox = _wait_ready(api, claim_name)
        for name, content in (files or {}).items():
            _upload(sandbox, name, content)
        _upload(sandbox, "main.py", code)
        return _execute(sandbox, "python3 main.py")
    finally:
        _delete_claim(api, claim_name)
