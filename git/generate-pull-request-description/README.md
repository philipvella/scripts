# Pull request descriptions

Run `./setup.sh` once and export `OPENAI_API_KEY`, then start the interactive flow:

```bash
~/work/scripts/git/generate-pull-request-description/describe.sh
```

On first use, enter the repository path, base branch (such as `origin/main`),
and branch to describe. The repository and base are saved locally. Later runs
show a numbered repository menu; choose a saved repository and enter the branch
to describe, or choose `0` to add another repository.

You can also supply any or all values by name, in any order:

```bash
~/work/scripts/git/generate-pull-request-description/describe.sh \
  --repo /Users/philipvella/work/strapi-cms \
  --base origin/main \
  --branch chore/A20-195
```

After that repository has been saved, omit `--base` to reuse it:

```bash
~/work/scripts/git/generate-pull-request-description/describe.sh \
  --branch chore/A20-195 \
  --repo /Users/philipvella/work/strapi-cms
```

An explicit `--base` updates the saved base. The branch to describe is never
saved. Missing values are prompted for; unattended runs must supply `--repo`,
`--branch`, and either a saved base or `--base`. The original positional
`<branch-name> <repo-path>` syntax and optional `--model` remain supported.

Settings are stored as a JSON object mapping repository paths to base branches
in `${XDG_CONFIG_HOME:-$HOME/.config}/generate-pull-request-description/repos.json`,
outside this repository. Paths are normalized to their Git repository roots.
Only repositories with valid base and target commit references are saved.
Edit this file to remove entries, or delete it to reset the menu.
