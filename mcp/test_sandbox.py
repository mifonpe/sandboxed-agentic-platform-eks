"""Self-check for the bits that can silently break: template rendering and the
output cap. Run: python3 test_sandbox.py"""

import os

os.environ.setdefault("SANDBOX_NAMESPACE", "agent-sandbox")
import sandbox


def test_render_claim():
    claim = sandbox._render_claim("run-abc123")
    assert claim["metadata"]["name"] == "run-abc123"
    assert claim["metadata"]["namespace"] == sandbox.NAMESPACE
    assert claim["spec"]["warmPoolRef"]["name"] == sandbox.WARMPOOL
    # Delete + TTL is what stops a dead broker leaking microVMs.
    assert claim["spec"]["lifecycle"]["shutdownPolicy"] == "Delete"
    assert isinstance(claim["spec"]["lifecycle"]["ttlSecondsAfterFinished"], int)
    # No unsubstituted placeholders left anywhere.
    assert "${" not in str(claim)


def test_ttl_outlives_run_timeout():
    # Otherwise the controller reaps a sandbox that is still legitimately running.
    assert sandbox.TTL_SECONDS > sandbox.RUN_TIMEOUT


def test_require_rejects_unknown_id():
    try:
        sandbox._require("sess-a", "s-not-mine")
    except ValueError:
        pass
    else:
        raise AssertionError("_require accepted an unknown sandbox id")


def test_require_rejects_other_sessions_sandbox():
    # The whole point of session scoping: knowing an id must not be enough.
    sandbox._CLAIMS[("sess-a", "s-owned")] = "claim-1"
    try:
        assert sandbox._require("sess-a", "s-owned") == "s-owned"
        try:
            sandbox._require("sess-b", "s-owned")
        except ValueError:
            pass
        else:
            raise AssertionError("session B reached session A's sandbox")
    finally:
        sandbox._CLAIMS.pop(("sess-a", "s-owned"), None)


def test_destroy_unknown_is_not_an_error():
    r = sandbox.destroy_sandbox("sess-a", "s-never-existed")
    assert r["destroyed"] is False


def test_cap_output():
    assert sandbox._cap(None) == ""
    assert sandbox._cap("hi") == "hi"
    big = sandbox._cap("x" * (sandbox.MAX_OUTPUT_BYTES + 5000))
    assert big.endswith("...[truncated]")
    assert len(big.encode()) <= sandbox.MAX_OUTPUT_BYTES + len("...[truncated]")


if __name__ == "__main__":
    test_render_claim()
    test_ttl_outlives_run_timeout()
    test_require_rejects_unknown_id()
    test_require_rejects_other_sessions_sandbox()
    test_destroy_unknown_is_not_an_error()
    test_cap_output()
    print("all checks passed")
