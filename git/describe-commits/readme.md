# describe-commits

Summarize the changes between two git commits in plain English (simple product/human terms).

## Usage

```bash
./describe_commits.sh <from-commit> <to-commit> <repo-path> [pathspec]
```

Examples:

```bash
export OPENAI_API_KEY="..."
./describe_commits.sh a1b2c3d 9f8e7d6 /path/to/repo
```

Limit to a sub-path inside the repo:

```bash
export OPENAI_API_KEY="..."
./describe_commits.sh a1b2c3d 9f8e7d6 /path/to/repo src/
```

## Requirements

- `git`
- `python3`
- Python package: `openai` (same dependency used by `git/generate-pull-request-description/generate_pr.py`)

If you want to test locally without calling OpenAI:

```bash
UNIT_TEST_MODE=1 ./describe_commits.sh <from> <to> <repo> [pathspec]
```
