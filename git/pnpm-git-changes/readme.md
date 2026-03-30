# pnpm-git-changes

`pnpm-git-changes` compares deployed commits between UAT and Production, filters to app-relevant changes in a pnpm workspace, extracts Jira tickets from commit messages, and prints a README-style changelog.

## What it does

1. Fetches commit hashes from each environment URL via `<meta name="git-commit" content="...">`.
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
- UAT and Production pages that expose the `git-commit` meta tag
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

1. Production URL
2. UAT URL
3. Local repo path (absolute)
4. App path inside repo (for example `apps/my-app`)
5. Branch name (stored, currently informational)
6. Whether to configure Jira credentials
7. If Jira enabled: Jira base URL, Atlassian email, Atlassian API token

Environment variables supported:

- `PROD_URL`
- `UAT_URL`
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
