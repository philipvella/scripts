import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def prompt(label):
    while True:
        print(label, end="", file=sys.stderr, flush=True)
        value = sys.stdin.readline()
        if not value:
            raise ValueError(
                "Input ended. Supply --repo, --base and --branch for unattended use."
            )
        value = value.strip()
        if value:
            return value
        print("A value is required.", file=sys.stderr)


def load_repos(path):
    if not path.exists():
        return {}
    with path.open() as config:
        repos = json.load(config)
    if not isinstance(repos, dict) or any(
        not isinstance(repo, str) or not repo
        or not isinstance(base, str) or not base
        or "\n" in repo or "\r" in repo or "\n" in base or "\r" in base
        for repo, base in repos.items()
    ):
        raise ValueError(f"Invalid repository settings in {path}. Expected path/base pairs.")
    return repos


def save_repos(path, repos):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", dir=path.parent, prefix=".repos-", delete=False
        ) as config:
            temporary = Path(config.name)
            json.dump(repos, config, indent=2)
            config.write("\n")
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def git(repo, *args):
    return subprocess.run(
        ["git", "-C", repo, *args], check=True, text=True, capture_output=True
    ).stdout.strip()


def resolve_settings(repo, base, branch, config_path):
    repos = load_repos(config_path)
    if not repo:
        if repos:
            entries = list(repos)
            print("Saved repositories:", file=sys.stderr)
            for index, path in enumerate(entries, 1):
                print(f"  {index}) {path} (base: {repos[path]})", file=sys.stderr)
            print("  0) Add a new repository", file=sys.stderr)
            while True:
                choice = prompt("Choose a repository: ")
                if choice == "0":
                    break
                if choice.isascii() and choice.isdecimal() and 1 <= int(choice) <= len(entries):
                    repo = entries[int(choice) - 1]
                    break
                print("Choose a listed repository number or 0.", file=sys.stderr)
        if not repo:
            repo = prompt("Repository path: ")

    repo = str(Path(repo).expanduser().resolve())
    repo = git(repo, "rev-parse", "--show-toplevel")
    base = base or repos.get(repo) or prompt("Base branch (e.g. origin/main): ")
    branch = branch or prompt("Branch to describe: ")
    if any("\n" in value or "\r" in value for value in (repo, base, branch)):
        raise ValueError("Repository path and branch names must not contain newlines.")
    for ref in (base, branch):
        git(repo, "rev-parse", "--verify", "--end-of-options", f"{ref}^{{commit}}")

    if repos.get(repo) != base:
        repos[repo] = base
        save_repos(config_path, repos)
        print(f"Saved repository and base branch in {config_path}", file=sys.stderr)
    return repo, base, branch


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default="")
    parser.add_argument("--base", default="")
    parser.add_argument("--branch", default="")
    args = parser.parse_args()
    config_dir = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    config_path = config_dir / "generate-pull-request-description" / "repos.json"
    try:
        settings = resolve_settings(args.repo, args.base, args.branch, config_path)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        print(f"Repository settings error: {detail}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nCancelled.", file=sys.stderr)
        return 1
    print("\n".join(settings))
    return 0


if __name__ == "__main__":
    sys.exit(main())
