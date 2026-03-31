# pnpm-git-changes

`pnpm-git-changes` compares deployed commits between UAT and Production, filters to app-relevant changes in a pnpm workspace, extracts Jira tickets from commit messages, and prints a README-style changelog.

## What it does

1. Fetches commit hashes from each environment URL via `<meta name="git-commit" content="...">`, or accepts manual input of the git hashes and thus not call the website to get the commit hashes.
2. Reads git history between those commits.
3. Filters commits to your app scope:
   - Excludes lockfile-only changes.
   - In pnpm workspaces, keeps changes in the target app and its workspace dependency graph.
4. Extracts Jira IDs from commit messages using pattern `\b[A-Z]{2,10}-\d+\b`.
5. Optionally fetches Jira `summary` and `status` from Jira Cloud API.
6. Prints markdown output with:
   - `## 📝 What Changed` (human-readable bullet summary)
   - `## 🎫 Jira Tickets` (clickable ticket links when URL is known)

## Requirements

- Node.js (ESM-compatible runtime)
- Local clone of the target git repository
- UAT and Production pages that expose the `git-commit` meta tag (only needed when using URL mode)
- Optional Jira Cloud credentials for enriched ticket details

## Install

```bash
cd /Users/philipvella/work/scripts/git/pnpm-git-changes
npm install
```

## Run

```bash
cd /Users/philipvella/work/scripts/git/pnpm-git-changes
node src/index.js
```

## Configuration behavior

The tool stores configuration in `.env` and offers reuse/update on next run.

Prompted values:

1. Commit source mode (`url` or `manual`)
2. If `url`: Production URL + UAT URL
3. If `manual`: Production commit hash + UAT commit hash
4. Local repo path (absolute)
5. App path inside repo (for example `apps/my-app`)
6. Branch name (stored, currently informational)
7. Whether to configure Jira credentials
8. If Jira enabled: Jira base URL, Atlassian email, Atlassian API token

Environment variables supported:

- `PROD_URL`
- `UAT_URL`
- `PROD_COMMIT`
- `UAT_COMMIT`
- `COMMIT_SOURCE` (`url` or `manual`)
- `REPO_PATH`
- `APP_PATH`
- `BRANCH`
- `ATLASSIAN_BASE_URL`
- `ATLASSIAN_EMAIL`
- `ATLASSIAN_API_TOKEN`

## Jira integration

- With Jira credentials, each ticket includes title and status from Jira API.
- Ticket output is markdown and clickable:
  - `[PROJ-123 - Ticket title](https://your-domain.atlassian.net/browse/PROJ-123)`
- If Jira lookup fails, ticket ID still appears and the tool continues.

## Output shape

The tool prints markdown to stdout (it does not currently write files automatically):

```markdown
# Changelog

> Generated on YYYY-MM-DD
> Comparing UAT (`abcdef1`) -> Production (`1234567`)

## 📝 What Changed
- ...
- ...

## 🎫 Jira Tickets
- [PROJ-123 - Title](https://your-domain.atlassian.net/browse/PROJ-123) ✅ `Done`
```

## Notes

- If both environments point to the same commit, the tool exits with no changes.
- If no relevant commits remain after filtering, the tool exits with no changes.
- Jira enrichment is optional; core comparison and ticket extraction still work without it.
