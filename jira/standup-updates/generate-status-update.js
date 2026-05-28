#!/usr/bin/env node

/**
 * Generate Jira Status Update using OpenAI
 *
 * Usage:
 * node generate-status-update.js [output-file]
 *
 * Environment variables required:
 * - JIRA_API_TOKEN: Jira API token (from: https://id.atlassian.com/manage-profile/security/api-tokens)
 * - JIRA_EMAIL: Jira account email
 * - JIRA_HOST: Jira host (e.g., kingmakers.atlassian.net)
 * - OPENAI_API_KEY: OpenAI API key
 */

// Load .env file if available
try {
  require('dotenv').config();
} catch (e) {
  // dotenv not installed, fall back to shell environment variables
}

const https = require('https');
const fs = require('fs');
const path = require('path');

// Configuration
const JIRA_HOST = process.env.JIRA_HOST || 'kingmakers.atlassian.net';
const JIRA_EMAIL = process.env.JIRA_EMAIL;
const JIRA_API_TOKEN = process.env.JIRA_API_TOKEN;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const OUTPUT_FILE = process.argv[2] || path.join('output', 'status-update-generated.md');

// Validate environment variables
if (!JIRA_EMAIL || !JIRA_API_TOKEN) {
  console.error('Error: JIRA_EMAIL and JIRA_API_TOKEN environment variables are required');
  process.exit(1);
}

if (!OPENAI_API_KEY) {
  console.error('Error: OPENAI_API_KEY environment variable is required');
  process.exit(1);
}

// Jira API request helper
async function jiraRequest(endpoint) {
  return new Promise((resolve, reject) => {
    const auth = Buffer.from(`${JIRA_EMAIL}:${JIRA_API_TOKEN}`).toString('base64');

    const options = {
      hostname: JIRA_HOST,
      port: 443,
      path: `/rest/api/3${endpoint}`,
      method: 'GET',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Accept': 'application/json',
      },
    };

    https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`Jira API error: ${res.statusCode} - ${data}`));
        }
      });
    }).on('error', reject).end();
  });
}

// OpenAI API request helper
async function openaiRequest(messages) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      model: 'gpt-4',
      messages: messages,
      temperature: 0.7,
      max_tokens: 1000,
    });

    const options = {
      hostname: 'api.openai.com',
      port: 443,
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
    };

    https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`OpenAI API error: ${res.statusCode} - ${data}`));
        }
      });
    }).on('error', reject).end(payload);
  });
}

// Search issues by JQL
async function fetchIssuesByJql(jql, maxResults = 50) {
  const encodedJql = encodeURIComponent(jql);
  const result = await jiraRequest(`/search/jql?jql=${encodedJql}&maxResults=${maxResults}&fields=summary,status,updated,description`);

  const issues = {};
  for (const issue of result.issues || []) {
    issues[issue.key] = {
      key: issue.key,
      summary: issue.fields.summary,
      status: issue.fields.status.name,
      updated: issue.fields.updated,
      description: issue.fields.description?.content || [],
    };
  }

  return issues;
}

// Format issues for ChatGPT
function formatIssuesForGPT(issues, yesterday, today) {
  const issuesList = Object.values(issues)
    .map(issue => `- ${issue.key} (${issue.status}): ${issue.summary}`)
    .join('\n');

  return `
Format the following Jira issues into a concise status update markdown file in this format:

# Status Update - [Project]

**Last 2 Days: [Date Range]**

## Yesterday:
[List completed and in-progress items]

## Today:
[List today's tasks]

## Blockers:
[List blockers or NA]

---

**Parent Epic:** [Link and title]

Issues:
${issuesList}

Requirements:
- Use ✅ for completed items
- Use 🔄 for in-progress items
- Include ticket keys with links format: [PAY-XXXX](https://kingmakers.atlassian.net/browse/PAY-XXXX)
- Keep descriptions concise (one line)
- Show yesterday's completed work
- Show today's planned work
- List any blockers
  `;
}

// Main execution
async function main() {
  try {
    console.log('🚀 Starting status update generation...\n');

    // Fetch issues dynamically via JQL
    const jql = '(assignee = currentUser() or assignee WAS IN (currentUser()) and status CHANGED) ORDER BY updated DESC';
    console.log('📥 Fetching issues from Jira via JQL...');
    console.log(`   JQL: ${jql}`);
    const issues = await fetchIssuesByJql(jql);
    console.log(`✅ Fetched ${Object.keys(issues).length} issues\n`);

    // Format for GPT
    const yesterday = 'May 26-27, 2026';
    const today = 'May 28, 2026';
    const gptPrompt = formatIssuesForGPT(issues, yesterday, today);

    // Call OpenAI
    console.log('🤖 Calling OpenAI to format status update...');
    const response = await openaiRequest([
      {
        role: 'user',
        content: gptPrompt,
      },
    ]);

    const markdown = response.choices[0].message.content;

    // Save to file
    fs.writeFileSync(OUTPUT_FILE, markdown);
    console.log(`\n✅ Status update saved to: ${OUTPUT_FILE}`);
    console.log('\n📄 Preview:\n');
    console.log(markdown);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { fetchIssuesByJql, openaiRequest, jiraRequest };

