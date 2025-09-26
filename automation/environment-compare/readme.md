# Environment Comparison Tool

## Quick Start

1. **Set up the project:**
   ```bash
   ./scripts/setup.sh
   ```

2. **Edit URL list:**
   - Add your UAT URLs to `config/urls.txt` (PROD URLs are generated automatically)

3. **Run comparison:**
   ```bash
   # Basic comparison
   ./scripts/compare_environments.sh
   
   # With authentication
   UAT_COOKIE="accessToken=xyz..." PROD_COOKIE="accessToken=abc..." ./scripts/compare_environments.sh
   ```

4. **View results:**
   - Screenshots: `output/screenshots/`

## Features

-  Takes full-page screenshots of both environments
-  Supports authentication via cookies
-  Error handling and logging
-  Configurable viewport and timeouts

## Files Structure

```
environment-compare/
├── scripts/                   # All execution scripts
│   ├── compare_environments.sh    # Main comparison script
│   └── setup.sh                   # Setup and configuration helper
├── config/                    # All configuration files
│   ├── config.sh              # Configuration settings
│   └── urls.txt               # UAT URLs (PROD URLs are generated automatically)
├── readme.md                  # Documentation
└── output/                    # Generated files
    └── screenshots/
        ├── uat/               # UAT screenshots
        └── prod/              # PROD screenshots
```

## Configuration

Edit `config/config.sh` to customize:
- Screenshot viewport size
- Browser timeout settings
- Default cookies (set `DEFAULT_UAT_COOKIE` and `DEFAULT_PROD_COOKIE`)

## Authentication

Set your cookies as environment variables or in your shell profile:
```bash
export UAT_COOKIE="accessToken=xyz..."
export PROD_COOKIE="accessToken=abc..."
```
