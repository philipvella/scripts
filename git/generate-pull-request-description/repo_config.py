import argparse
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import termios
import tty


def prompt(label, default=""):
    while True:
        print(label, end="", file=sys.stderr, flush=True)
        value = sys.stdin.readline()
        if not value:
            raise ValueError(
                "Input ended. Supply --repo, --base and --branch for unattended use."
            )
        value = value.strip()
        if value or default:
            return value or default
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


def prompt_branch(repo):
    result = subprocess.run(
        ["git", "-C", repo, "symbolic-ref", "--quiet", "--short", "HEAD"],
        text=True, capture_output=True,
    )
    if result.returncode not in (0, 1):
        raise subprocess.CalledProcessError(
            result.returncode, result.args, stderr=result.stderr
        )
    current = result.stdout.strip()
    if not current:
        print("Repository has a detached HEAD; enter a branch explicitly.", file=sys.stderr)
        return prompt("Branch to describe: ")

    return prompt(
        f"Branch to describe [{current}] (Enter to use current): ", default=current
    )


def choose_repo(repos):
    entries = list(repos)
    labels = [f"{path} (base: {repos[path]})" for path in entries]
    labels.append("Add a new repository")
    numbers = [str(index) for index in range(1, len(entries) + 1)] + ["0"]
    print("Saved repositories:", file=sys.stderr)
    for number, label in zip(numbers, labels):
        print(f"  {number}) {label}", file=sys.stderr)

    if not sys.stdin.isatty() or not sys.stderr.isatty() or os.environ.get("TERM") == "dumb":
        while True:
            choice = prompt("Choose a repository: ")
            if choice in numbers:
                index = numbers.index(choice)
                return entries[index] if index < len(entries) else ""
            print("Choose a listed repository number or 0.", file=sys.stderr)

    descriptor = sys.stdin.fileno()
    original = termios.tcgetattr(descriptor)
    selected = 0
    digits = ""
    try:
        tty.setcbreak(descriptor)
        while True:
            display = digits or f"{numbers[selected]}) {labels[selected]}"
            print(
                f"\r\033[KChoose a repository (Up/Down, Enter, or number): {display}",
                end="", file=sys.stderr, flush=True,
            )
            key = os.read(descriptor, 1)
            if key in (b"", b"\x04"):
                raise ValueError("Input ended. Supply --repo for unattended use.")
            if key in (b"\r", b"\n"):
                if digits:
                    if digits not in numbers:
                        print("\nChoose a listed repository number or 0.", file=sys.stderr)
                        digits = ""
                        continue
                    selected = numbers.index(digits)
                return entries[selected] if selected < len(entries) else ""
            if key == b"\x1b":
                sequence = b""
                for _ in range(2):
                    if not select.select([descriptor], [], [], 0.1)[0]:
                        break
                    sequence += os.read(descriptor, 1)
                if sequence in (b"[A", b"OA", b"[B", b"OB"):
                    selected = (selected + (-1 if sequence[-1:] == b"A" else 1)) % len(labels)
                    digits = ""
            elif b"0" <= key <= b"9":
                digits += key.decode("ascii")
            elif key in (b"\x7f", b"\x08"):
                digits = digits[:-1]
    finally:
        termios.tcsetattr(descriptor, termios.TCSADRAIN, original)
        print(file=sys.stderr)


def resolve_settings(repo, base, branch, config_path):
    repos = load_repos(config_path)
    if not repo:
        if repos:
            repo = choose_repo(repos)
        if not repo:
            repo = prompt("Repository path: ")

    repo = str(Path(repo).expanduser().resolve())
    repo = git(repo, "rev-parse", "--show-toplevel")
    base = base or repos.get(repo) or prompt("Base branch (e.g. origin/main): ")
    branch = branch or prompt_branch(repo)
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
