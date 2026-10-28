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
        error = body.get("error", body)
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
            f"The first line must be a PR title starting with 'chore({ticket}): ' "
            "followed by a concise, specific summary you generate from the actual diff. "
            "Write the summary itself, not a placeholder or the words 'dynamic summary'. "
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
    except APIStatusError as e:
        code = _error_code_from_exception(e)
        if code == "model_not_found":
            print(f"❌ Model '{model}' was not found or not accessible for this API key/project.", file=sys.stderr)
            print("Retry with --model <enabled-model> (for example, --model gpt-4o-mini).", file=sys.stderr)
            print("If that also fails, check model access for the API key's project.", file=sys.stderr)
        elif isinstance(e, RateLimitError) and code == "insufficient_quota":
            print("❌ OpenAI quota exceeded (insufficient_quota).", file=sys.stderr)
            print("Check billing/credits for the API key, then retry.", file=sys.stderr)
        elif isinstance(e, RateLimitError):
            print("❌ Rate limited by OpenAI. Retry shortly or reduce diff size.", file=sys.stderr)
        elif isinstance(e, AuthenticationError):
            print("❌ OpenAI authentication failed. Verify OPENAI_API_KEY is set and valid.", file=sys.stderr)
        elif isinstance(e, BadRequestError):
            print("❌ Invalid request to OpenAI API. Check the provider message below.", file=sys.stderr)
        else:
            print(f"❌ OpenAI API error (status {e.status_code}).", file=sys.stderr)
            if e.status_code == 404:
                print("Check the provider message for model access issues and verify OPENAI_BASE_URL if set.", file=sys.stderr)

        print(f"Status: {e.status_code}", file=sys.stderr)
        print(f"URL: {e.request.url}", file=sys.stderr)
        print(f"Model: {model}", file=sys.stderr)
        if code:
            print(f"Error code: {code}", file=sys.stderr)
        print(f"Provider message: {e.message}", file=sys.stderr)
        if e.request_id:
            print(f"Request ID: {e.request_id}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    # Read the diff from the pipe
    diff = sys.stdin.read()
    if diff:
        generate_description(diff)