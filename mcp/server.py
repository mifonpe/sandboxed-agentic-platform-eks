"""MCP server exposing sandboxed Python execution as a tool.

Sits behind agentgateway, which does JWT authn and per-tool authz before any
request reaches here — this process sees no token and makes no authorization
decision. It only vends a microVM, runs code, and tears it down.
"""

import logging
import os

import uvicorn
from mcp.server.fastmcp import Context, FastMCP
from mcp.server.transport_security import TransportSecuritySettings
from starlette.requests import Request
from starlette.responses import PlainTextResponse

import sandbox

logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))

# DNS-rebinding protection blocks in-cluster DNS names; this is a ClusterIP
# behind agentgateway, not a browser-facing localhost server.
mcp = FastMCP(
    "Sandboxed Python",
    transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False),
)


# Tools are deliberately fine-grained so agentgateway can authorize them
# individually — a persona that may move files need not be one that may execute
# code. Splitting them IS the authorization surface.


def _session(ctx: Context) -> str:
    """Stable id for the caller's MCP session.

    Sandboxes are scoped to this: the sandbox_id a tool receives is an opaque
    string from the caller, so without a session key any authenticated caller
    could drive another's microVM by learning its id. The transport creates one
    ServerSession per MCP session, so its object identity is the handle.
    """
    return str(id(ctx.session))


@mcp.tool()
def run_once(code: str, files: dict[str, str] | None = None) -> dict:
    """Run Python in a throwaway sandbox and return stdout, stderr, exit_code.

    The sandbox is created, used and destroyed within this one call, so nothing
    persists. Use this for self-contained work; use create_sandbox when results
    need to survive between calls.

    `files` maps filename -> content and is written before the code runs — pass
    input data here rather than embedding it in `code`.
    """
    return sandbox.run_once(code, files)


@mcp.tool()
def create_sandbox(ctx: Context) -> dict:
    """Start a new sandboxed environment and return its id.

    The sandbox is an air-gapped microVM with no network access. It persists
    until destroy_sandbox, so files written to it survive between calls. Always
    destroy it when finished.
    """
    return {"sandbox_id": sandbox.create_sandbox(_session(ctx))}


@mcp.tool()
def destroy_sandbox(sandbox_id: str, ctx: Context) -> dict:
    """Destroy a sandbox and everything in it. Idempotent."""
    return sandbox.destroy_sandbox(_session(ctx), sandbox_id)


@mcp.tool()
def run_python(sandbox_id: str, code: str, ctx: Context) -> dict:
    """Execute Python inside an existing sandbox; returns stdout, stderr, exit_code.

    No network access, so no pip installs and no outbound calls. Read inputs from
    files already uploaded to the working directory.
    """
    return sandbox.run_python(_session(ctx), sandbox_id, code)


@mcp.tool()
def upload_file(sandbox_id: str, name: str, content: str, ctx: Context) -> dict:
    """Write a file into the sandbox's working directory."""
    return sandbox.upload_file(_session(ctx), sandbox_id, name, content)


@mcp.tool()
def download_file(sandbox_id: str, path: str, ctx: Context) -> dict:
    """Read a file back out of the sandbox.

    Returns {"content", "encoding"} — utf-8 when the file is text, base64 when it
    is not.
    """
    return sandbox.download_file(_session(ctx), sandbox_id, path)


@mcp.tool()
def list_files(sandbox_id: str, ctx: Context, path: str = ".") -> dict:
    """List a directory inside the sandbox."""
    return sandbox.list_files(_session(ctx), sandbox_id, path)


# The MCP endpoint itself is not probeable: streamable HTTP requires
# `Accept: text/event-stream`, so a kubelet GET gets 406 Not Acceptable and the
# pod never goes Ready — and each probe opens and tears down a session. This
# plain route answers the probe without touching the MCP transport.
@mcp.custom_route("/healthz", methods=["GET"])
async def healthz(_: Request) -> PlainTextResponse:
    return PlainTextResponse("ok")


if __name__ == "__main__":
    uvicorn.run(mcp.streamable_http_app(), host="0.0.0.0", port=8080)
