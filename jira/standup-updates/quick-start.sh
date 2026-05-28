#!/bin/bash

# Quick Start Guide for Jira Status Update Generator
# Run: bash quick-start.sh

echo "🚀 Jira Status Update Generator - Quick Start"
echo "================================================"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 16+ from https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js found: $(node --version)"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ .env file created"
    echo ""
    echo "⚠️  NEXT STEP: Edit .env and add your API keys:"
    echo "   - Get Jira API token: https://id.atlassian.com/manage-profile/security/api-tokens"
    echo "   - Get OpenAI API key: https://platform.openai.com/account/api-keys"
    echo "   - Then run: node generate-status-update-with-env.js"
    echo ""
else
    echo "✅ .env file exists"
    echo ""

    # Check if required values are set
    if grep -q "your_jira_api_token_here\|your_openai_key_here" .env; then
        echo "⚠️  Your .env file still has placeholder values!"
        echo "   Edit .env and replace:"
        echo "   - your_jira_api_token_here with your actual Jira API token"
        echo "   - your_openai_key_here with your actual OpenAI key"
        echo ""
    else
        echo "✅ API keys configured"
        echo ""
        echo "🎯 Ready to generate status updates!"
        echo ""
        echo "Usage:"
        echo "  node generate-status-update-with-env.js              # Generate to default file"
        echo "  node generate-status-update-with-env.js status.md    # Generate to custom file"
        echo ""
        echo "Run now? (y/n)"
        read -r response
        if [ "$response" = "y" ]; then
            node generate-status-update-with-env.js
        fi
    fi
fi

