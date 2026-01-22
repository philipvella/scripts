import sys
from openai import OpenAI

# The shell script passes the key as the first argument
api_key = sys.argv[1]
client = OpenAI(api_key=api_key)

def generate_description(diff_text):
    # Precise instructions to match the style you liked
    prompt = (
            "Summarize the following git diff into a concise list. "
            "First output should be a relative title starting with 'chore(XXX-0000): DYNAMIC SUMMARY'. "
            "Then the rest of the output should be, bullet points like this '- [x] '. "
            "Do not use bold titles or headers. "
            "Focus on product terms and technical changes:\n\n" + diff_text
    )

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}]
    )
    print(response.choices[0].message.content)

if __name__ == "__main__":
    # Read the diff from the pipe
    diff = sys.stdin.read()
    if diff:
        generate_description(diff)