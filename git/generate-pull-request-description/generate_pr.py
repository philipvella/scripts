import sys
import os
from openai import OpenAI, APIStatusError, AuthenticationError, BadRequestError, RateLimitError

# The shell script passes the key as the first argument and ticket as the second
api_key = sys.argv[1]
ticket = sys.argv[2] if len(sys.argv) > 2 else "XXX-0000"
client = OpenAI(api_key=api_key)

# Max diff size in characters before truncation (to avoid rate limits)
MAX_DIFF_SIZE = 15000

def _error_code_from_exception(exc):
    """Try to extract provider error code from OpenAI SDK exceptions."""
    body = getattr(exc, "body", None)
    if isinstance(body, dict):
        error = body.get("error")
        if isinstance(error, dict):
            return error.get("code")
    return None


def generate_description(diff_text):
    # Warn if diff is truncated
    original_size = len(diff_text)
    if original_size > MAX_DIFF_SIZE:
        truncated_diff = diff_text[:MAX_DIFF_SIZE]
        print(f"⚠️  Diff truncated from {original_size} to {MAX_DIFF_SIZE} characters to avoid rate limits", file=sys.stderr)
        diff_text = truncated_diff + "\n... (diff truncated)"

    # Precise instructions to match the style you liked
    prompt = (
            "Summarize the following git diff into a concise list. "
            f"First output should be a relative title starting with 'chore({ticket}): DYNAMIC SUMMARY'. "
            "Then the rest of the output should be, bullet points like this '- [x] '. "
            "As concise as possible without repetition. Do not include any information that is not directly related to the code changes. "
            "Focus mostly on the product deliverables so that it is as concise as possible for the reviewer to understand the impact of the changes. "
            "Do not use bold titles or headers. "
            "Focus on product terms and technical changes:\n\n" + diff_text
    )

    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}]
        )
        print(response.choices[0].message.content)
    except RateLimitError as e:
        # 429 can be transient rate limiting or hard quota exhaustion.
        code = _error_code_from_exception(e)
        if code == "insufficient_quota":
            print("❌ OpenAI quota exceeded (insufficient_quota).", file=sys.stderr)
            print("Check billing/credits for the API key, then retry.", file=sys.stderr)
        else:
            print("❌ Rate limited by OpenAI. Retry shortly or reduce diff size.", file=sys.stderr)
        sys.exit(1)
    except AuthenticationError:
        print("❌ OpenAI authentication failed. Verify OPENAI_API_KEY is set and valid.", file=sys.stderr)
        sys.exit(1)
    except BadRequestError as e:
        code = _error_code_from_exception(e)
        if code == "model_not_found":
            print(f"❌ Model '{model}' was not found or not accessible for this API key.", file=sys.stderr)
            print("Try --model gpt-4o-mini (or another enabled model).", file=sys.stderr)
        else:
            print(f"❌ Invalid request to OpenAI API: {e}", file=sys.stderr)
        sys.exit(1)
    except APIStatusError as e:
        print(f"❌ OpenAI API error (status {e.status_code}).", file=sys.stderr)
        print(f"URL: {e.request.url}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    # Read the diff from the pipe
    diff = sys.stdin.read()
    if diff:
        generate_description(diff)