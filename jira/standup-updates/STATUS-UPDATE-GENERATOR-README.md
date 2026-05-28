# Jira Status Update Generator

Automatically generate formatted status updates from Jira issues using OpenAI's ChatGPT.

## Setup

### 1. Install Node.js
Requires Node.js >= 16.0.0

### 2. Get API Keys

#### Jira API Token
1. Go to: https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Copy the token

#### OpenAI API Key
1. Go to: https://platform.openai.com/account/api-keys
2. Click "Create new secret key"
3. Copy the key

### 3. Configure Environment Variables

Create a `.env` file in this directory:

```bash
JIRA_HOST=kingmakers.atlassian.net
JIRA_EMAIL=your-email@kingmakers.com
JIRA_API_TOKEN=your_jira_api_token_here
OPENAI_API_KEY=sk-your_openai_key_here
```

Or export them in your shell:

```bash
export JIRA_HOST=kingmakers.atlassian.net
export JIRA_EMAIL=your-email@kingmakers.com
export JIRA_API_TOKEN=your_jira_api_token
export OPENAI_API_KEY=sk-your_openai_key
```

### 4. Customize Issue Keys

Edit `generate-status-update.js` and update the `issueKeys` array in the `main()` function:

```javascript
const issueKeys = ['PAY-8330', 'PAY-8331', 'PAY-8411', 'PAY-8325', 'PAY-8329', 'PAY-7559'];
```

Change these to your target Jira tickets.

### 5. Run the Generator

```bash
node generate-status-update.js
```

Or to save to a custom file:

```bash
node generate-status-update.js my-status-update.md
```

The script will:
1. ✅ Fetch all issues from Jira
2. 🤖 Send them to OpenAI for formatting
3. 📄 Generate a concise markdown status update
4. 💾 Save to file and display preview

## Output Format

The generated markdown will follow this structure:

```markdown
# Status Update - [Project]

**Last 2 Days: [Date Range]**

## Yesterday:
- ✅ Finished [PAY-XXXX](link) Task description
- 🔄 Working on [PAY-YYYY](link) Task description

## Today:
- Handle task on [PAY-ZZZZ](link) Task description

## Blockers:
- NA

---

**Parent Epic:** [PAY-7559](link) Epic title
```

## Troubleshooting

### "Error: JIRA_EMAIL and JIRA_API_TOKEN environment variables are required"
- Make sure your `.env` file is created with correct values
- Or export them: `export JIRA_EMAIL=...`

### "Jira API error: 401"
- Your Jira API token is invalid or expired
- Generate a new one at: https://id.atlassian.com/manage-profile/security/api-tokens

### "OpenAI API error: 401"
- Your OpenAI API key is invalid
- Check your key at: https://platform.openai.com/account/api-keys

### Rate limits
- OpenAI has rate limits. If you hit them, wait and retry.
- Jira might rate limit if fetching many issues. Add delays if needed.

## Example Usage

```bash
# Generate to default file
node generate-status-update.js

# Generate to custom file
node generate-status-update.js status-may-28.md

# With environment variables
JIRA_Email=user@company.com JIRA_API_TOKEN=token123 OPENAI_API_KEY=sk-... node generate-status-update.js
```

## Notes

- The script uses GPT-4 model. You can change it to `gpt-3.5-turbo` in the code if you want faster/cheaper responses.
- Customize the GPT prompt in `formatIssuesForGPT()` to change output format.
- The script only uses HTTPS (secure) connections.

