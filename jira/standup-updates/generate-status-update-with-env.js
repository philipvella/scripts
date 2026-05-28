#!/usr/bin/env node

/**
 * Generate Jira Status Update using OpenAI (with .env support)
 *
 * Setup:
 * 1. Copy .env.example to .env
 * 2. Fill in your API keys
 * 3. Update issue keys in the main() function
 * 4. Run: node generate-status-update-with-env.js
 */

// Load .env file if available
try {
  require('dotenv').config();
} catch (e) {
  console.warn('⚠️  dotenv not installed. Using environment variables directly.');
  console.warn('   To use .env files, install: npm install dotenv\n');
}

const https = require('https');
const fs = require('fs');

// Configuration from environment
const JIRA_HOST = process.env.JIRA_HOST || 'kingmakers.atlassian.net';
const JIRA_EMAIL = process.env.JIRA_EMAIL;
const JIRA_API_TOKEN = process.env.JIRA_API_TOKEN;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4';
const path = require('path');
// ...existing code...
const OUTPUT_FILE = process.argv[2] || path.join('output', 'status-update-generated.md');

// Color codes for terminal output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

function log(color, message) {
  console.log(`${color}${message}${colors.reset}`);
}

// Validate environment variables
function validateEnv() {
  const missing = [];

  if (!JIRA_EMAIL) missing.push('JIRA_EMAIL');
  if (!JIRA_API_TOKEN) missing.push('JIRA_API_TOKEN');
  if (!OPENAI_API_KEY) missing.push('OPENAI_API_KEY');

  if (missing.length > 0) {
    log(colors.red, '❌ Missing environment variables:');
    missing.forEach(v => log(colors.red, `   - ${v}`));
    log(colors.yellow, '\n📝 Copy .env.example to .env and fill in your API keys:');
    log(colors.cyan, '   cp .env.example .env');
    process.exit(1);
  }

  log(colors.green, '✅ All environment variables configured');
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

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error(`Failed to parse Jira response: ${e.message}`));
          }
        } else {
          reject(new Error(`Jira API error ${res.statusCode}: ${data.substring(0, 200)}`));
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

// OpenAI API request helper
async function openaiRequest(messages) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      model: OPENAI_MODEL,
      messages: messages,
      temperature: 0.7,
      max_tokens: 1500,
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

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error(`Failed to parse OpenAI response: ${e.message}`));
          }
        } else {
          reject(new Error(`OpenAI API error ${res.statusCode}: ${data.substring(0, 200)}`));
        }
      });
    });

    req.on('error', reject);
    req.end(payload);
  });
}

// Search issues by JQL
async function fetchIssuesByJql(jql, maxResults = 50) {
  const encodedJql = encodeURIComponent(jql);
  const result = await jiraRequest(`/search/jql?jql=${encodedJql}&maxResults=${maxResults}&fields=summary,status,updated`);

  const issues = {};
  for (const issue of result.issues || []) {
    issues[issue.key] = {
      key: issue.key,
      summary: issue.fields.summary,
      status: issue.fields.status.name,
      updated: issue.fields.updated,
    };
  }

  return issues;
}

// Format issues for ChatGPT
function formatIssuesForGPT(issues) {
  const issuesList = Object.values(issues)
    .map(issue => `- ${issue.key} (${issue.status}): ${issue.summary}`)
    .join('\n');

  return `Format the following Jira issues into a concise status update markdown file.

Use this exact format:

# Status Update - Help-Centre Migration

**Last 2 Days: May 26-28, 2026**

## Yesterday:
- ✅ Finished [PAY-8330](https://kingmakers.atlassian.net/browse/PAY-8330) Make workers work behind a cookie for testing
- ✅ Finished [PAY-8331](https://kingmakers.atlassian.net/browse/PAY-8331) Introduce FARO and OTEL to 'help-centre'
- ✅ Finished [PAY-8411](https://kingmakers.atlassian.net/browse/PAY-8411) Add git commit SHA vite plugin to remaining frontend apps
- 🔄 Working on [PAY-8325](https://kingmakers.atlassian.net/browse/PAY-8325) Migrate help-centre CI from cloudflare-pages to unified-v2 worker pipelines

## Today:
- Handle naming normalization on [PAY-8329](https://kingmakers.atlassian.net/browse/PAY-8329) Normalise and rename 'help-center' to 'help-centre'

## Blockers:
- NA

---

**Parent Epic:** [PAY-7559](https://kingmakers.atlassian.net/browse/PAY-7559) 🛠 Payments Tech SRE (2026)

Now format these issues in that same style:

${issuesList}

Requirements:
- Use ✅ for completed/archived items
- Use 🔄 for in-progress items
- Include ticket keys with markdown links format: [KEY](https://kingmakers.atlassian.net/browse/KEY)
- Keep descriptions concise (one line each)
- Organize by yesterday's work, today's work, and blockers
- Include the parent epic link at bottom`;
}

// Main execution
async function main() {
  try {
    log(colors.blue, '\n🚀 Jira Status Update Generator\n');

    // Validate environment
    validateEnv();

    // Fetch issues dynamically via JQL
    const jql = '(assignee = currentUser() or assignee WAS IN (currentUser()) and status CHANGED) ORDER BY updated DESC';
    log(colors.cyan, '\n📥 Fetching issues from Jira via JQL...');
    log(colors.cyan, `   JQL: ${jql}`);
    const issues = await fetchIssuesByJql(jql);

    if (Object.keys(issues).length === 0) {
      log(colors.red, '❌ No issues fetched. Check your Jira API token and host.');
      process.exit(1);
    }

    log(colors.green, `✅ Fetched ${Object.keys(issues).length} issues`);

    // Format for GPT
    log(colors.cyan, '\n🤖 Sending to OpenAI for formatting...');
    const gptPrompt = formatIssuesForGPT(issues);
    const response = await openaiRequest([
      {
        role: 'system',
        content: 'You are a technical writer who creates concise status updates for developers.',
      },
      {
        role: 'user',
        content: gptPrompt,
      },
    ]);

    const markdown = response.choices[0].message.content;

    // Save to file
    fs.writeFileSync(OUTPUT_FILE, markdown);
    log(colors.green, `\n✅ Status update generated!`);
    log(colors.green, `💾 Saved to: ${OUTPUT_FILE}\n`);

    log(colors.cyan, '📄 Preview:\n');
    log(colors.reset, '─'.repeat(60));
    console.log(markdown);
    log(colors.reset, '─'.repeat(60));

  } catch (error) {
    log(colors.red, `\n❌ Error: ${error.message}`);
    if (error.message.includes('401')) {
      log(colors.yellow, '\n💡 This usually means your API keys are invalid or expired.');
      log(colors.yellow, '   Check your .env file and update your API keys if needed.');
    }
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { fetchIssuesByJql, openaiRequest, jiraRequest };

