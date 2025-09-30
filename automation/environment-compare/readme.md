# Environment Comparison Tool

A comprehensive tool for comparing web environments by taking screenshots and generating visual comparison reports.

## Requirements

- **Node.js 22.0.0 or higher** - This project requires the latest Node.js features and performance improvements
- NPM or Yarn package manager

### Node.js Version Management

This project includes a `.nvmrc` file that specifies the required Node.js version. If you're using [nvm](https://github.com/nvm-sh/nvm), you can automatically use the correct version:

```bash
# Install and use the specified Node.js version
nvm install
nvm use

# Or in one command
nvm use
```

To verify you're using the correct Node.js version:
```bash
node --version  # Should show v22.x.x or higher
```

## Features

- Take screenshots of multiple environments (UAT, Production, etc.)
- Generate side-by-side comparison HTML reports
- Mobile-responsive viewport support
- Configurable timeouts and browser settings
- Thumbnail generation
- Automated favicon generation

## Installation

1. Clone or navigate to this directory
2. Install dependencies:
   ```bash
   npm install
   ```

## Configuration

The tool uses a JavaScript configuration file located at `config/config.js`. This file contains all the customizable settings for the environment comparison tool.

### Configuration Options

```javascript
{
  // Viewport settings for screenshots
  viewport: {
    width: 375,    // Default mobile width
    height: 812    // Default mobile height
  },

  // Timeout settings (in milliseconds)
  timeouts: {
    pageTimeout: 30000,      // How long to wait for page load
    screenshotDelay: 2       // Delay before taking screenshot
  },

  // Browser configuration
  browser: {
    headlessMode: true,      // Run browser in headless mode
    args: [                  // Browser launch arguments
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage'
    ]
  },

  // Output settings
  output: {
    fullPageScreenshots: true,  // Take full page screenshots
    generateThumbnails: false,  // Generate thumbnail images
    thumbnailWidth: 400         // Thumbnail width in pixels
  },

  // Report generation settings
  report: {
    title: 'Environment Comparison Report',
    includeSummaryStats: true,   // Include statistics in report
    includeTimestamp: true       // Include timestamp in report
  },

  // Logging configuration
  logging: {
    level: 'INFO',              // DEBUG, INFO, WARN, ERROR
    logToFile: false            // Write logs to file
  }
}
```

### Modifying Configuration

To customize the tool behavior, edit the `config/config.js` file and modify the values as needed. The configuration is automatically loaded by all scripts.

## Usage

### NPM Scripts

The following npm scripts are available:

- **`npm run config`** - Display current configuration settings
- **`npm run setup`** - Run initial setup
- **`npm run generate-images`** - Generate environment screenshots
- **`npm run generate-comparison`** - Generate comparison HTML report
- **`npm run generate-favicon`** - Generate favicon for the report
- **`npm start`** - Run the complete workflow (setup → images → comparison)

### Individual Scripts

You can also run individual scripts directly:

```bash
# Setup the environment
node scripts/setup.js

# Generate screenshots for all environments
node scripts/generate_environment_images.js

# Generate the comparison HTML report
node scripts/generate_comparison_html.js

# Generate favicon
node scripts/generate_favicon.js
```

### URL Configuration

URLs for comparison are configured in `config/urls.txt`. Add one URL per line:

```
https://example.com
https://example.com/page1
https://example.com/page2
```

## Output

The tool generates:

- **Screenshots**: Stored in `public/screenshots/` organized by environment
- **Comparison Report**: Generated as `public/index.html`
- **Favicon**: Generated as `public/favicon.ico`
- **Deploy Files**: Ready-to-deploy files in `scripts/output/deploy/`

## Environment Variables

Some sensitive configurations (like cookies) should be set as environment variables in your `~/.zshrc` or `~/.bashrc`:

```bash
export ENVIRONMENT_COOKIES="your-cookie-string"
```

## Migration from Shell Script

This tool was migrated from a shell script configuration (`config.sh`) to JavaScript for better maintainability and integration with Node.js tooling. The JavaScript configuration provides:

- Better type safety and validation
- Integration with package.json scripts
- Easier programmatic access from Node.js scripts
- More structured configuration organization

## Troubleshooting

- If screenshots are failing, try increasing the `pageTimeout` value
- For memory issues, add `--max-old-space-size=4096` to browser args
- Enable debug logging by setting `logging.level` to `'DEBUG'`
