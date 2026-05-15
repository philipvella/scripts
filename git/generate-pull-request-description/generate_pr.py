import sys
import os
from openai import OpenAI

# The shell script passes the key as the first argument and ticket as the second
api_key = sys.argv[1]
ticket = sys.argv[2] if len(sys.argv) > 2 else "XXX-0000"
client = OpenAI(api_key=api_key)

# Max diff size in characters before truncation (to avoid rate limits)
MAX_DIFF_SIZE = 15000

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

    # Use gpt-4-turbo for better rate limit handling (40k TPM instead of 30k for gpt-4o)
    model = os.getenv("OPENAI_MODEL", "gpt-4-turbo")

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}]
        )
        print(response.choices[0].message.content)
    except Exception as e:
        if "rate_limit" in str(e).lower():
            print(f"❌ Rate limited. Try reducing diff size or upgrade your OpenAI account.", file=sys.stderr)
            print(f"Error: {str(e)}", file=sys.stderr)
            sys.exit(1)
        raise

if __name__ == "__main__":
    # Read the diff from the pipe
    diff = sys.stdin.read()
    if diff:
        generate_description(diff)