# Pull request descriptions

Run `./setup.sh` once and export `OPENAI_API_KEY`, then start the interactive flow:

```bash
~/work/scripts/git/generate-pull-request-description/describe.sh
```

Prompts use [questionary](https://github.com/tmbakker/questionary), the same
style of interactive CLI used by tools such as `npm init` and Yeoman:

- **Repository menu**: Up/Down arrows or a number shortcut, then **Enter**.
  Choose `0) + Add a new repository` to add another one. With more than nine
  saved repositories, type to filter instead.
- **Repository path**: **Tab** completes directories (`~` is expanded). The
  path must be a Git repository.
- **Base branch** (new repositories only): pre-filled with `origin/main` (or
  `origin/master`/`main`/`master`); **Tab** completes local and remote branches.
- **Branch to describe**: pre-filled with the repository's current branch, so
  **Enter** accepts it; **Tab** completes local branches.
- Invalid paths and branches are rejected inline before continuing. A hint bar
  shows the available keys, and **Ctrl-C** cancels.

The repository and base are saved locally, so later runs need only two Enter
presses. The current branch comes from the selected repository's checkout, not
the directory you launched the script from. With a detached HEAD, you must type
a branch.

Piped input, missing `questionary`, or `TERM=dumb` fall back to plain numbered
prompts. After pulling this change, rerun `./setup.sh` to install `questionary`.

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
