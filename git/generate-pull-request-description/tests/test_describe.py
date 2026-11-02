import itertools
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


class DescribeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.tool = self.root / "tool"
        self.tool.mkdir()
        source = Path(__file__).resolve().parents[1]
        for name in ("describe.sh", "repo_config.py"):
            shutil.copy2(source / name, self.tool / name)
        python = self.tool / ".venv" / "bin" / "python"
        python.parent.mkdir(parents=True)
        # Stub the OpenAI dependency check and generator; never call the API.
        python.write_text(
            '#!/bin/bash\nif [ "$1" = "-c" ]; then exit 0; fi\n'
            f'exec {shlex.quote(sys.executable)} "$@"\n'
        )
        python.chmod(0o755)
        (self.tool / "generate_pr.py").write_text(
            "import json, os, sys\n"
            "print(json.dumps({'ticket': sys.argv[2], 'diff': sys.stdin.read(), "
            "'model': os.environ['OPENAI_MODEL'], 'repo': os.getcwd()}))\n"
        )
        self.config_home = self.root / "config"
        self.config = self.config_home / "generate-pull-request-description" / "repos.json"
        self.env = {
            **os.environ,
            "XDG_CONFIG_HOME": str(self.config_home),
            "OPENAI_API_KEY": "test-key-not-sent",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
        }
        self.repo = self.make_repo("repo with spaces")

    def git(self, repo, *args):
        return subprocess.run(
            ["git", "-C", str(repo), *args], env=self.env,
            check=True, capture_output=True, text=True,
        )

    def make_repo(self, name):
        repo = self.root / name
        repo.mkdir()
        self.git(repo, "init", "-q")
        self.git(repo, "checkout", "-q", "-b", "main")
        self.git(repo, "config", "user.name", "Test")
        self.git(repo, "config", "user.email", "test@example.invalid")
        self.git(repo, "config", "commit.gpgsign", "false")
        (repo / "file.txt").write_text("before\n")
        self.git(repo, "add", "file.txt")
        self.git(repo, "commit", "-qm", "Initial")
        self.git(repo, "checkout", "-qb", "chore/A20-195")
        (repo / "file.txt").write_text("after\n")
        self.git(repo, "commit", "-qam", "Change")
        return repo

    def run_script(self, *args, input=""):
        return subprocess.run(
            ["bash", str(self.tool / "describe.sh"), *map(str, args)],
            cwd=self.root, env=self.env, input=input, text=True, capture_output=True,
        )

    def assert_generated(self, result, repo=None, model="gpt-4o-mini"):
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(output["repo"], str(repo or self.repo))
        self.assertEqual(output["ticket"], "A20-195")
        self.assertEqual(output["model"], model)
        self.assertIn("+after", output["diff"])
        return output

    def save_first_repo(self):
        self.assert_generated(self.run_script(
            "--repo", self.repo, "--base", "main", "--branch", "chore/A20-195"
        ))

    def test_first_run_prompts_and_second_run_reuses_saved_base(self):
        result = self.run_script(input=f"{self.repo}\nmain\nchore/A20-195\n")
        self.assert_generated(result)
        self.assertEqual(json.loads(self.config.read_text()), {str(self.repo): "main"})
        result = self.run_script(input="bad\n7\n1\nchore/A20-195\n")
        self.assert_generated(result)
        self.assertIn("Choose a listed repository number or 0.", result.stderr)
        self.assertNotIn("Base branch (", result.stderr)
        self.assertNotIn("Repository path: ", result.stderr)

    def test_add_and_choose_another_repo(self):
        self.save_first_repo()
        second = self.make_repo("second")
        result = self.run_script(input=f"0\n{second}\nmain\nchore/A20-195\n")
        self.assert_generated(result, repo=second)
        self.assertEqual(
            json.loads(self.config.read_text()), {str(self.repo): "main", str(second): "main"}
        )
        self.assert_generated(
            self.run_script(input="2\nchore/A20-195\n"), repo=second
        )

    def test_blank_branch_uses_selected_repos_current_branch(self):
        self.assert_generated(self.run_script(input=f"{self.repo}\nmain\n\n"))
        self.assert_generated(self.run_script(input="1\n\n"))
        self.git(self.repo, "checkout", "-qb", "chore/A20-196")
        result = self.run_script("--repo", self.repo, input="\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["ticket"], "A20-196")
        self.assertIn("Branch to describe [chore/A20-196]", result.stderr)

    def test_detached_head_requires_explicit_branch(self):
        self.git(self.repo, "checkout", "-q", "--detach")
        result = self.run_script(
            "--repo", self.repo, "--base", "main", input="\nchore/A20-195\n"
        )
        self.assert_generated(result)
        self.assertIn("detached HEAD", result.stderr)
        self.assertIn("A value is required.", result.stderr)
        result = self.run_script("--repo", self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Input ended.", result.stderr)
        self.assert_generated(self.run_script(
            "--repo", self.repo, "--branch", "chore/A20-195"
        ))

    def test_branch_eof_does_not_accept_default(self):
        result = self.run_script("--repo", self.repo, "--base", "main")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Input ended.", result.stderr)
        self.assertFalse(self.config.exists())

    def test_typed_or_explicit_branch_overrides_current_branch(self):
        self.git(self.repo, "checkout", "-q", "main")
        self.assert_generated(self.run_script(
            "--repo", self.repo, "--base", "main", input="chore/A20-195\n"
        ))
        self.assert_generated(self.run_script(
            "--repo", self.repo, "--branch", "chore/A20-195"
        ))

    def test_all_named_option_orders_and_model(self):
        pairs = [
            ("--repo", self.repo), ("--base", "main"),
            ("--branch", "chore/A20-195"), ("--model", "gpt-4o"),
        ]
        for permutation in itertools.permutations(pairs):
            with self.subTest(order=[pair[0] for pair in permutation]):
                args = [value for pair in permutation for value in pair]
                self.assert_generated(self.run_script(*args), model="gpt-4o")

    def test_explicit_base_updates_saved_base_and_legacy_syntax_works(self):
        self.save_first_repo()
        self.git(self.repo, "branch", "alternate-base", "main")
        self.assert_generated(self.run_script(
            "chore/A20-195", self.repo, "--base", "alternate-base"
        ))
        self.assertEqual(
            json.loads(self.config.read_text()), {str(self.repo): "alternate-base"}
        )
        self.assert_generated(self.run_script(
            "--repo", self.repo, "--branch", "chore/A20-195"
        ))

    def test_subdirectory_normalizes_to_saved_repo_root(self):
        self.save_first_repo()
        subdirectory = self.repo / "subdirectory"
        subdirectory.mkdir()
        self.assert_generated(self.run_script(
            "--repo", subdirectory, "--branch", "chore/A20-195"
        ))
        self.assertEqual(json.loads(self.config.read_text()), {str(self.repo): "main"})

    def test_invalid_repo_or_refs_are_not_saved(self):
        for repo, base, branch in (
            (self.root, "main", "chore/A20-195"),
            (self.repo, "missing", "chore/A20-195"),
            (self.repo, "main", "missing"),
        ):
            with self.subTest(repo=repo, base=base, branch=branch):
                result = self.run_script("--repo", repo, "--base", base, "--branch", branch)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Repository settings error:", result.stderr)
                self.assertFalse(self.config.exists())
                self.assertEqual(result.stdout, "")

    def test_corrupt_config_is_reported_and_not_overwritten(self):
        self.config.parent.mkdir(parents=True)
        for content in ("not json", "[]", '{"repo": 123}'):
            self.config.write_text(content)
            result = self.run_script(
                "--repo", self.repo, "--base", "main", "--branch", "chore/A20-195"
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Repository settings error:", result.stderr)
            self.assertEqual(self.config.read_text(), content)

    def test_eof_reports_missing_input(self):
        for args in ((), ("--repo", self.repo, "--branch", "chore/A20-195")):
            result = self.run_script(*args)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Input ended.", result.stderr)
            self.assertFalse(self.config.exists())

    def test_help_and_invalid_arguments(self):
        result = self.run_script("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("saved per repository", result.stdout)
        for args, message in (
            (("--repo",), "Missing value for --repo"),
            (("--base", "--branch", "feature"), "Missing value for --base"),
            (("--unknown",), "Unknown option: --unknown"),
            (("branch", "repo", "extra"), "Unexpected argument: extra"),
        ):
            result = self.run_script(*args)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(message, result.stderr)


if __name__ == "__main__":
    unittest.main()
