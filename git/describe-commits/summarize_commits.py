import json
import os
import sys
import time
from pathlib import Path

try:
    from openai import OpenAI
except Exception:  # pragma: no cover
    OpenAI = None


def _build_prompt(diff_text: str) -> str:
    return (
        "Summarize the following git changes for non-technical stakeholders. "
        "Write in simple product/human terms. "
        "Return 4-8 bullet points, each starting with '- '. "
        "Don't include code snippets. Avoid file paths and low-level implementation details. "
        "If changes are purely internal/refactor, say that clearly.\n\n"
        "Git diff (may be truncated):\n"
        + diff_text
    )


def _estimate_tokens(text: str) -> int:
    # Rough heuristic: ~4 characters per token for English-ish source.
    # Good enough to keep us under TPM without extra deps.
    return max(1, len(text) // 4)


def _rate_limit_wait(estimated_input_tokens: int, *, model: str) -> None:
    """Best-effort local TPM limiter.

    Tracks token usage in a small JSON file under ~/.cache so multiple invocations
    of the script back off together.

    Env vars:
      OPENAI_TPM_LIMIT: tokens per minute budget (default: 30000)
      OPENAI_TPM_RESERVE: extra buffer tokens (default: 2000)
      OPENAI_TPM_WINDOW_SECONDS: window size (default: 60)
      OPENAI_TPM_STATE_FILE: override state file path
      OPENAI_TPM_MAX_SLEEP_SECONDS: cap how long we'll wait (default: 90)
    """

    if os.getenv("UNIT_TEST_MODE") == "1":
        return

    tpm_limit = int(os.getenv("OPENAI_TPM_LIMIT", "30000"))
    reserve = int(os.getenv("OPENAI_TPM_RESERVE", "2000"))
    window = int(os.getenv("OPENAI_TPM_WINDOW_SECONDS", "60"))
    max_sleep = int(os.getenv("OPENAI_TPM_MAX_SLEEP_SECONDS", "90"))

    # Reserve some budget for model output + prompt framing.
    need = estimated_input_tokens + reserve

    state_path = os.getenv("OPENAI_TPM_STATE_FILE")
    if state_path:
        state_file = Path(state_path)
    else:
        state_file = Path.home() / ".cache" / "scripts_openai_tpm.json"

    state_file.parent.mkdir(parents=True, exist_ok=True)
    now = time.time()

    # Load state
    try:
        state = json.loads(state_file.read_text())
    except Exception:
        state = {}

    entry = state.get(model) or {"window_start": now, "tokens": 0}
    window_start = float(entry.get("window_start", now))
    tokens_used = int(entry.get("tokens", 0))

    # Reset window if elapsed
    if now - window_start >= window:
        window_start = now
        tokens_used = 0

    # If we'd exceed, sleep until window resets.
    if tokens_used + need > tpm_limit:
        sleep_for = window - (now - window_start)
        sleep_for = max(0.0, min(float(max_sleep), float(sleep_for)))
        if sleep_for > 0:
            time.sleep(sleep_for)
        # New window after sleeping
        window_start = time.time()
        tokens_used = 0

    # Record usage for this request
    tokens_used += need
    state[model] = {"window_start": window_start, "tokens": tokens_used}
    try:
        state_file.write_text(json.dumps(state))
    except Exception:
        # If we can't persist state, we still proceed (best-effort).
        pass


def _is_request_too_large_error(err: Exception) -> bool:
    msg = str(err).lower()
    # Covers common OpenAI SDK messages:
    # - "Request too large"
    # - token-per-minute exceeded with details
    return (
        "request too large" in msg
        or ("tokens per min" in msg and "limit" in msg and "requested" in msg)
        or "context length" in msg
        or "maximum context" in msg
    )


def _is_rate_limit_error(err: Exception) -> bool:
    msg = str(err).lower()
    # Best-effort; SDK may raise different exception types, but message will include 429.
    return "error code: 429" in msg or "rate limit" in msg or "rate_limit" in msg


def summarize(diff_text: str, api_key: str) -> str:
    # For local tests: don't hit the network.
    if os.getenv("UNIT_TEST_MODE") == "1":
        return "- Summary (stubbed): changes detected and would be summarized here."

    if OpenAI is None:
        raise RuntimeError(
            "Python package 'openai' is not available. Install it (e.g. pip install openai)."
        )

    model = os.getenv("OPENAI_MODEL", "gpt-4o")

    # Progressive truncation plan (chars). Can be overridden.
    # We start with the incoming diff_text, then fall back to these sizes.
    retry_sizes_env = os.getenv("OPENAI_RETRY_DIFF_CHAR_SIZES", "60000,30000,15000")
    retry_sizes = []
    for part in retry_sizes_env.split(","):
        part = part.strip()
        if not part:
            continue
        try:
            retry_sizes.append(int(part))
        except ValueError:
            continue

    max_output_tokens = int(os.getenv("OPENAI_MAX_OUTPUT_TOKENS", "500"))

    # Attempt 1: full input, then progressively smaller diffs.
    attempts = [diff_text]
    for size in retry_sizes:
        if len(diff_text) > size:
            attempts.append(diff_text[:size] + f"\n\n[Diff truncated to {size} characters for retry due to model limits.]")

    last_err: Exception | None = None

    for i, attempt_diff in enumerate(attempts, start=1):
        prompt = _build_prompt(attempt_diff)

        # TPM limiter applies per attempt.
        _rate_limit_wait(_estimate_tokens(prompt), model=model)

        client = OpenAI(api_key=api_key)
        try:
            response = client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=max_output_tokens,
            )
            return response.choices[0].message.content
        except Exception as e:
            last_err = e

            # If it's a size/rate issue, retry with a smaller diff (if available).
            can_retry = i < len(attempts)
            if can_retry and (_is_request_too_large_error(e) or _is_rate_limit_error(e)):
                # Small backoff to avoid hammering in burst scenarios.
                time.sleep(float(os.getenv("OPENAI_RETRY_BACKOFF_SECONDS", "1.0")))
                continue

            raise

    # Shouldn't reach here, but keep a sensible failure mode.
    raise RuntimeError(f"Failed to generate summary after retries: {last_err}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: summarize_commits.py <OPENAI_API_KEY>", file=sys.stderr)
        sys.exit(2)

    api_key = sys.argv[1]
    diff = sys.stdin.read()

    if not diff.strip():
        print("No diff provided on stdin", file=sys.stderr)
        sys.exit(1)

    try:
        print(summarize(diff, api_key))
    except Exception as e:
        print(f"Error generating summary: {e}", file=sys.stderr)
        sys.exit(1)
