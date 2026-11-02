import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


try:
    import questionary
    from prompt_toolkit.completion import PathCompleter
    from prompt_toolkit.styles import Style
except ImportError:
    questionary = None

STYLE = Style([
    ("qmark", "fg:#5fd7ff bold"),
    ("question", "bold"),
    ("answer", "fg:#5fd75f bold"),
    ("pointer", "fg:#5fd7ff bold"),
    ("highlighted", "fg:#5fd7ff bold"),
    ("selected", "fg:#5fd75f"),
    ("instruction", "fg:#808080 italic"),
    ("text", ""),
    ("bottom-toolbar", "noreverse fg:#808080"),
]) if questionary else None


def interactive():
    return (
        questionary is not None
        and sys.stdin.isatty()
        and sys.stderr.isatty()
        and os.environ.get("TERM") != "dumb"
    )


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


def ask(question):
    try:
        answer = question.unsafe_ask()
    except EOFError:
        raise ValueError("Input ended. Supply --repo, --base and --branch for unattended use.")
    if answer is None:
        raise KeyboardInterrupt
    return answer.strip() if isinstance(answer, str) else answer


def is_commit(repo, ref):
    return subprocess.run(
        ["git", "-C", repo, "rev-parse", "--quiet", "--verify", "--end-of-options",
         f"{ref}^{{commit}}"],
        capture_output=True,
    ).returncode == 0


def ref_validator(repo):
    def validate(value):
        value = value.strip()
        if not value:
            return "A value is required."
        if not is_commit(repo, value):
            return f"'{value}' is not a branch or commit in this repository."
        return True
    return validate


def refs(repo, *patterns):
    result = subprocess.run(
        ["git", "-C", repo, "for-each-ref", "--sort=-committerdate",
         "--format=%(refname:short)", *patterns],
        text=True, capture_output=True,
    )
    return [ref for ref in result.stdout.splitlines() if ref and not ref.endswith("/HEAD")]


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


def current_branch(repo):
    result = subprocess.run(
        ["git", "-C", repo, "symbolic-ref", "--quiet", "--short", "HEAD"],
        text=True, capture_output=True,
    )
    if result.returncode not in (0, 1):
        raise subprocess.CalledProcessError(
            result.returncode, result.args, stderr=result.stderr
        )
    return result.stdout.strip()


def prompt_branch(repo):
    current = current_branch(repo)
    if interactive():
        return ask(questionary.autocomplete(
            "Branch to describe:",
            choices=refs(repo, "refs/heads"),
            default=current,
            validate=ref_validator(repo),
            complete_while_typing=False,
            bottom_toolbar=" Enter: use current branch · Tab: complete · Ctrl-C: cancel" if current
            else " Detached HEAD: type a branch · Tab: complete · Ctrl-C: cancel",
            style=STYLE,
        ))
    if not current:
        print("Repository has a detached HEAD; enter a branch explicitly.", file=sys.stderr)
        return prompt("Branch to describe: ")
    return prompt(
        f"Branch to describe [{current}] (Enter to use current): ", default=current
    )


def prompt_base(repo):
    if interactive():
        remote = refs(repo, "refs/remotes")
        local = refs(repo, "refs/heads")
        default = next(
            (ref for ref in ("origin/main", "origin/master", "main", "master")
             if ref in remote + local),
            "",
        )
        return ask(questionary.autocomplete(
            "Base branch:",
            choices=remote + local,
            default=default,
            validate=ref_validator(repo),
            complete_while_typing=False,
            bottom_toolbar=" Enter: accept · Tab: complete · Ctrl-C: cancel",
            style=STYLE,
        ))
    return prompt("Base branch (e.g. origin/main): ")


def git_root_validator(value):
    path = Path(value.strip()).expanduser()
    if not value.strip():
        return "A value is required."
    if not path.is_dir():
        return "Directory not found."
    if subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--show-toplevel"], capture_output=True
    ).returncode:
        return "Not a Git repository."
    return True


def prompt_repo_path():
    if interactive():
        return ask(questionary.text(
            "Repository path:",
            completer=PathCompleter(only_directories=True, expanduser=True),
            validate=git_root_validator,
            complete_while_typing=False,
            bottom_toolbar=" Tab: complete path · Enter: accept · Ctrl-C: cancel",
            style=STYLE,
        ))
    return prompt("Repository path: ")


def choose_repo(repos):
    entries = list(repos)
    if interactive():
        width = max(len(path) for path in entries)
        choices = [
            questionary.Choice(f"{path.ljust(width)}  base: {repos[path]}", value=path)
            for path in entries
        ]
        choices += [
            questionary.Separator(),
            questionary.Choice("+ Add a new repository", value="", shortcut_key="0"),
        ]
        shortcuts = len(entries) <= 9
        return ask(questionary.select(
            "Repository:",
            choices=choices,
            use_shortcuts=shortcuts,
            use_search_filter=not shortcuts,
            use_jk_keys=False,
            instruction="(↑/↓ or number, Enter to select)" if shortcuts
            else "(↑/↓ or type to filter, Enter to select)",
            style=STYLE,
        ))

    numbers = [str(index) for index in range(1, len(entries) + 1)] + ["0"]
    print("Saved repositories:", file=sys.stderr)
    for number, path in zip(numbers, entries):
        print(f"  {number}) {path} (base: {repos[path]})", file=sys.stderr)
    print("  0) Add a new repository", file=sys.stderr)
    while True:
        choice = prompt("Choose a repository: ")
        if choice in numbers:
            index = numbers.index(choice)
            return entries[index] if index < len(entries) else ""
        print("Choose a listed repository number or 0.", file=sys.stderr)


def resolve_settings(repo, base, branch, config_path):
    repos = load_repos(config_path)
    if not repo:
        if repos:
            repo = choose_repo(repos)
        if not repo:
            repo = prompt_repo_path()

    repo = str(Path(repo).expanduser().resolve())
    repo = git(repo, "rev-parse", "--show-toplevel")
    base = base or repos.get(repo) or prompt_base(repo)
    branch = branch or prompt_branch(repo)
    if any("\n" in value or "\r" in value for value in (repo, base, branch)):
        raise ValueError("Repository path and branch names must not contain newlines.")
    for ref in (base, branch):
        git(repo, "rev-parse", "--verify", "--end-of-options", f"{ref}^{{commit}}")

    if repos.get(repo) != base:
        repos[repo] = base
        save_repos(config_path, repos)
        print(f"Saved repository and base branch in {config_path}", file=sys.stderr)
    if interactive():
        print(
            f"\033[2m  repo   \033[0m{repo}\n"
            f"\033[2m  base   \033[0m{base}\n"
            f"\033[2m  branch \033[0m{branch}",
            file=sys.stderr,
        )
    return repo, base, branch


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default="")
    parser.add_argument("--base", default="")
    parser.add_argument("--branch", default="")
    args = parser.parse_args()
    config_dir = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    config_path = config_dir / "generate-pull-request-description" / "repos.json"
    # stdout carries the result back to describe.sh; render all UI on stderr.
    sys.stdout.flush()
    data = os.fdopen(os.dup(1), "w")
    os.dup2(2, 1)
    try:
        settings = resolve_settings(args.repo, args.base, args.branch, config_path)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        print(f"Repository settings error: {detail}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nCancelled.", file=sys.stderr)
        return 1
    print("\n".join(settings), file=data, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
