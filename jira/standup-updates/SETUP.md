# Jira Status Update Generator - Complete Setup

I've created a Node.js automation tool that:
1. ✅ Fetches issue details from Jira
2. 🤖 Uses ChatGPT to format them into a concise status update
3. 📄 Generates a clean markdown file

## 📁 Files Created

### Main Scripts
- **`generate-status-update-with-env.js`** ⭐ (Recommended - easier to use)
  - Uses `.env` file for API keys
  - Better error messages and colored output
  - Ready to use out of the box

- **`generate-status-update.js`**
  - Alternative version using environment variables directly

### Configuration Files
- **`.env.example`** - Template for API keys (copy to `.env` and fill in)
- **`package-status-gen.json`** - Node.js package metadata

### Documentation
- **`STATUS-UPDATE-GENERATOR-README.md`** - Complete setup guide
- **`quick-start.sh`** - Bash script for quick setup
- **`SETUP.md`** - This file

## 🚀 Quick Start (3 steps)

### Step 1: Setup Environment
```bash
# From the kingmakers-frontend directory
cp .env.example .env
```

### Step 2: Get Your API Keys

**Jira API Token:**
1. Go to: https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Copy the token

**OpenAI API Key:**
1. Go to: https://platform.openai.com/account/api-keys
2. Click "Create new secret key"
3. Copy the key

**Edit `.env` file:**
```
JIRA_HOST=kingmakers.atlassian.net
JIRA_EMAIL=your-email@kingmakers.com
JIRA_API_TOKEN=paste_your_jira_token_here
OPENAI_API_KEY=sk-paste_your_openai_key_here
```

### Step 3: Customize Issue Keys
Edit `generate-status-update-with-env.js` around line 160:

```javascript
// TODO: Customize these issue keys for your needs
const issueKeys = ['PAY-8330', 'PAY-8331', 'PAY-8411', 'PAY-8325', 'PAY-8329', 'PAY-7559'];
```

### Step 4: Run It!
```bash
node generate-status-update-with-env.js
```

Or with custom output file:
```bash
node generate-status-update-with-env.js my-status-update.md
```

## 📋 What It Does

The script will:
1. Connect to Jira and fetch all issue details (summary, status, updated date)
2. Send the issues to OpenAI's GPT-4 with instructions to format them
3. Generate formatted markdown file with:
   - Yesterday's completed/in-progress tasks
   - Today's planned tasks
   - Blockers section
   - Clickable Jira links
4. Save to file and show preview

## 📊 Output Example

```markdown
# Status Update - Help-Centre Migration

**Last 2 Days: May 26-28, 2026**

## Yesterday:
- ✅ Finished [PAY-8330](https://kingmakers.atlassian.net/browse/PAY-8330) Make workers work behind a cookie for testing
- ✅ Finished [PAY-8331](https://kingmakers.atlassian.net/browse/PAY-8331) Introduce FARO and OTEL to 'help-centre'
- 🔄 Working on [PAY-8325](https://kingmakers.atlassian.net/browse/PAY-8325) Migrate help-centre CI...

## Today:
- Handle naming normalization on [PAY-8329](https://kingmakers.atlassian.net/browse/PAY-8329) Normalise and rename 'help-center' to 'help-centre'

## Blockers:
- NA

---

**Parent Epic:** [PAY-7559](https://kingmakers.atlassian.net/browse/PAY-7559) 🛠 Payments Tech SRE (2026)
```

## 🔧 Customization

### Change OpenAI Model
Edit `.env`:
```
OPENAI_MODEL=gpt-3.5-turbo   # Faster/cheaper (default: gpt-4)
```

### Change Jira Host
```
JIRA_HOST=your-domain.atlassian.net
```

### Customize GPT Prompt
Edit `generate-status-update-with-env.js` - function `formatIssuesForGPT()` around line 120

## ❓ Troubleshooting

### "❌ Missing environment variables"
- Copy `.env.example` to `.env`
- Fill in your API keys

### "Jira API error 401"
- Your Jira API token is invalid
- Generate a new one: https://id.atlassian.com/manage-profile/security/api-tokens

### "OpenAI API error 401"
- Your OpenAI API key is invalid or expired
- Check your key: https://platform.openai.com/account/api-keys

### "❌ No issues fetched"
- Check your issue keys in the script
- Make sure they exist in Jira
- Verify JIRA_HOST is correct

## 💡 Pro Tips

1. **Run periodically:** Set up a cron job to generate status updates daily
   ```bash
   0 9 * * * cd /path/to/kingmakers-frontend && node generate-status-update-with-env.js status-$(date +\%Y-\%m-\%d).md
   ```

2. **Customize for different teams:** Create different issue key arrays for different teams/projects

3. **Save API keys securely:** Don't commit `.env` to git (it's in `.gitignore`)

4. **Monitor costs:** OpenAI GPT-4 costs money. Monitor your usage at https://platform.openai.com/account/usage/overview

## 📚 Documentation Files

- **STATUS-UPDATE-GENERATOR-README.md** - Detailed setup and troubleshooting
- **quick-start.sh** - Automated quick setup script
- **SETUP.md** - This file

## 🎯 Next Steps

1. Get your API keys (Jira and OpenAI)
2. Copy `.env.example` to `.env` and fill in your keys
3. Update issue keys to match your workflow
4. Run: `node generate-status-update-with-env.js`
5. Customize the GPT prompt if needed
6. Integrate into your workflow!

---

Happy automating! 🚀

