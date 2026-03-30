#!/usr/bin/env node

import chalk from 'chalk';
import { loadConfig } from './config.js';
import { fetchCommitFromUrl } from './fetcher.js';
import { getCommitsWithFiles } from './git.js';
import { filterRelevantCommits } from './pnpm.js';
import { extractJiraTickets, fetchJiraDetails } from './jira.js';
import { generateSummary } from './openai-helper.js';

async function main() {
  console.log(chalk.bold.blue('\n🔍  pnpm-git-changes\n'));

  // ── 1. Load or collect configuration ─────────────────────────────────────
  const config = await loadConfig();

  // ── 2. Fetch git commit hashes from environment meta tags ─────────────────
  console.log(chalk.cyan('\nFetching git commits from environments...'));

  let prodCommit, uatCommit;

  try {
    prodCommit = await fetchCommitFromUrl(config.prodUrl);
    console.log(chalk.green(`  ✓ Production : ${prodCommit}`));
  } catch (err) {
    console.error(chalk.red(`  ✗ Failed to fetch production commit: ${err.message}`));
    process.exit(1);
  }

  try {
    uatCommit = await fetchCommitFromUrl(config.uatUrl);
    console.log(chalk.green(`  ✓ UAT        : ${uatCommit}`));
  } catch (err) {
    console.error(chalk.red(`  ✗ Failed to fetch UAT commit: ${err.message}`));
    process.exit(1);
  }

  if (prodCommit === uatCommit) {
    console.log(
      chalk.yellow('\n⚠️  Both environments are on the same commit — no changes to report.\n')
    );
    process.exit(0);
  }

  // ── 3. Get commits between environments ───────────────────────────────────
  console.log(chalk.cyan('\nAnalysing git history...'));

  let commits;
  try {
    commits = await getCommitsWithFiles(config.repoPath, uatCommit, prodCommit);
    if (commits.length === 0) {
      // UAT may be ahead of PROD — try the other direction
      console.log(
        chalk.yellow('  ⚠️  No commits found in that direction, trying reverse...')
      );
      commits = await getCommitsWithFiles(config.repoPath, prodCommit, uatCommit);
    }
    console.log(chalk.green(`  ✓ Found ${commits.length} commit(s) between environments`));
  } catch (err) {
    console.error(chalk.red(`  ✗ Failed to read git history: ${err.message}`));
    process.exit(1);
  }

  if (commits.length === 0) {
    console.log(chalk.yellow('\nNo changes found between the two environments.\n'));
    process.exit(0);
  }

  // ── 4. Filter to commits relevant to the application ──────────────────────
  console.log(chalk.cyan('\nFiltering relevant changes via pnpm workspace analysis...'));

  let relevantCommits;
  try {
    relevantCommits = await filterRelevantCommits(commits, config.repoPath, config.appPath);
    console.log(
      chalk.green(
        `  ✓ ${relevantCommits.length} relevant commit(s) (${commits.length - relevantCommits.length} filtered out)`
      )
    );
  } catch (err) {
    console.warn(chalk.yellow(`  ⚠️  pnpm workspace filter failed — using all commits: ${err.message}`));
    relevantCommits = commits;
  }

  if (relevantCommits.length === 0) {
    console.log(chalk.yellow('\nNo changes found between the two environments.\n'));
    process.exit(0);
  }

  // ── 5. Extract JIRA tickets ────────────────────────────────────────────────
  const tickets = extractJiraTickets(relevantCommits);

  // ── 6. Fetch JIRA details if credentials are available ────────────────────
  let ticketDetails = {};
  if (config.atlassianEmail && config.atlassianApiToken && config.atlassianBaseUrl) {
    console.log(chalk.cyan('\nFetching JIRA ticket details...'));
    try {
      ticketDetails = await fetchJiraDetails(tickets, config);
      const ok = Object.values(ticketDetails).filter((d) => d.status !== 'Error' && d.status !== 'Not Found').length;
      console.log(chalk.green(`  ✓ Fetched ${ok}/${tickets.length} ticket(s)`));
    } catch (err) {
      console.warn(chalk.yellow(`  ⚠️  Failed to fetch JIRA details: ${err.message}`));
    }
  }

  // ── 7. Print results ───────────────────────────────────────────────────────
  console.log(chalk.bold.green('\n📋  JIRA Tickets:\n'));

  if (tickets.length === 0) {
    console.log(chalk.gray('  No JIRA ticket references found in commit messages.\n'));
    console.log(chalk.gray('  Relevant commits:'));
    relevantCommits.forEach((c) =>
      console.log(chalk.gray(`    ${c.shortHash} ${c.message}`))
    );
  } else {
    for (const ticket of tickets) {
      const d = ticketDetails[ticket];
      if (d) {
        const statusColor =
          d.status === 'Done' || d.status === 'Closed'
            ? chalk.green
            : d.status === 'In Progress'
            ? chalk.yellow
            : chalk.gray;
        console.log(
          `  ${chalk.bold.cyan(ticket)}  ${d.summary}  ${statusColor(`[${d.status}]`)}  ${chalk.gray(d.url)}`
        );
      } else {
        console.log(`  ${chalk.bold.cyan(ticket)}`);
      }
    }
  }

  // ── 8. AI summary ─────────────────────────────────────────────────────────
  if (config.openaiApiKey) {
    console.log(chalk.cyan('\nGenerating AI summary...'));
    try {
      const summary = await generateSummary(relevantCommits, tickets, ticketDetails, config);
      console.log(chalk.bold.green('\n🤖  AI Summary:\n'));
      console.log(summary);
    } catch (err) {
      console.warn(chalk.yellow(`  ⚠️  Failed to generate AI summary: ${err.message}`));
    }
  }

  console.log('\n');
}

main().catch((err) => {
  console.error(chalk.red('\nFatal error:'), err.message);
  process.exit(1);
});

