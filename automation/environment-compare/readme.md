# Environment Comparison Tool

## Quick Start

1. **Setup the project:**
   ```bash
   ./setup.sh
   ```

2. **Edit URL lists:**
   - Add your UAT URLs to `uat_urls.txt`
   - Add your PROD URLs to `prod_urls.txt`

3. **Run comparison:**
   ```bash
   # Basic comparison
   ./compare_environments.sh
   
   # With authentication
   UAT_COOKIE="accessToken=xyz..." PROD_COOKIE="accessToken=abc..." ./compare_environments.sh
   ```

4. **View results:**
   - Screenshots: `output/screenshots/`
   - HTML Report: `output/reports/comparison_report_[timestamp].html`

## Features

- ✅ Takes full-page screenshots of both environments
- ✅ Generates side-by-side HTML comparison report
- ✅ Supports authentication via cookies
- ✅ Responsive HTML report with statistics
- ✅ Error handling and logging
- ✅ Configurable viewport and timeouts

## Files Structure

```
environment-compare/
├── compare_environments.sh    # Main comparison script
├── setup.sh                   # Setup and configuration helper
├── config.sh                  # Configuration settings
├── uat_urls.txt              # UAT environment URLs
├── prod_urls.txt             # PROD environment URLs
├── readme.md                 # Documentation
└── output/                   # Generated files
    ├── screenshots/
    │   ├── uat/              # UAT screenshots
    │   └── prod/             # PROD screenshots
    └── reports/              # HTML comparison reports
```

## Configuration

Edit `config.sh` to customize:
- Screenshot viewport size
- Browser timeout settings
- Default cookies
- Report appearance

## Authentication

For pages requiring authentication, provide cookies in these ways:

1. **Environment variables:**
   ```bash
   export UAT_COOKIE="accessToken=xyz..."
   export PROD_COOKIE="accessToken=abc..."
   ```

2. **Command line:**
   ```bash
   ./compare_environments.sh --uat-cookie "accessToken=xyz..." --prod-cookie "accessToken=abc..."
   ```

3. **Config file:**
   Edit `DEFAULT_UAT_COOKIE` and `DEFAULT_PROD_COOKIE` in `config.sh`

## Dependencies

- Node.js (for Puppeteer)
- Bash shell
- Internet connection

The script will automatically install Puppeteer if not present.

## Troubleshooting

- **"node not found"**: Install Node.js from https://nodejs.org
- **Screenshot failures**: Check URL accessibility and cookie validity
- **Empty report**: Verify URL files have valid URLs (one per line)

### Puppeteer Chrome Not Found Error

**Problem:**
```
Error: Could not find Chrome (ver. 140.0.7339.207). This can occur if either
 1. you did not perform an installation before running the script (e.g. `npx puppeteer browsers install chrome`) or
 2. your cache path is incorrectly configured (which is: /Users/username/.cache/puppeteer).
```

**Cause:**
The project uses `puppeteer-core` which doesn't include a bundled Chrome browser. The Chrome browser needs to be installed separately.

**Solutions:**

**Option 1: Install Chrome for Puppeteer (Recommended)**
```bash
npx puppeteer browsers install chrome
```

**Option 2: Use full Puppeteer package**
```bash
npm uninstall puppeteer-core
npm install puppeteer
```

The first option is recommended as it keeps your current setup but adds the required browser. The full `puppeteer` package includes a bundled version of Chrome but increases the package size significantly.

## Examples

The project comes with example URLs for supersportbet.com:
- UAT: `uat.supersportbet.com`
- PROD: `www.supersportbet.com`

Replace these with your actual URLs in the respective text files.
