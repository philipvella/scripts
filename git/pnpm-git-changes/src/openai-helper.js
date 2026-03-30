import OpenAI from 'openai';

/**
 * Generate an AI summary of the changes using OpenAI.
 *
 * @param {Array<{hash, message, files}>} commits
 * @param {string[]} tickets
 * @param {Record<string, {summary, status, url}>} ticketDetails
 * @param {{ openaiApiKey: string }} config
 * @returns {Promise<string>}
 */
export async function generateSummary(commits, tickets, ticketDetails, config) {
  const client = new OpenAI({ apiKey: config.openaiApiKey });

  // Build context for the prompt
  const ticketList = tickets
    .map((t) => {
      const detail = ticketDetails[t];
      if (detail && detail.summary !== '(Could not fetch)') {
        return `- ${t}: ${detail.summary} [${detail.status}]`;
      }
      return `- ${t}`;
    })
    .join('\n');

  // Include commit messages (excluding lock-file-only commits)
  const commitList = commits
    .map((c) => {
      const nonLock = c.files.filter(
        (f) => !f.endsWith('.lock') && f !== 'pnpm-lock.yaml'
      );
      const filePreview = nonLock.slice(0, 5).join(', ') + (nonLock.length > 5 ? '...' : '');
      return `- [${c.shortHash}] ${c.message}${filePreview ? ` (files: ${filePreview})` : ''}`;
    })
    .join('\n');

  const prompt = `You are a technical release assistant. Given the following git commits and JIRA tickets that represent changes deployed to production (compared to the UAT environment), write a concise, human-readable summary of what changed.

Focus on:
- The functional areas affected
- The impact to end users
- Any notable fixes or features

JIRA Tickets:
${ticketList || '(none found)'}

Commits:
${commitList}

Write a clear, 3–6 sentence summary suitable for a release note or team Slack message. Do not just list the tickets — synthesise what they mean together.`;

  const completion = await client.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
    max_tokens: 500,
    temperature: 0.4,
  });

  return completion.choices[0]?.message?.content?.trim() || '(No summary generated)';
}

