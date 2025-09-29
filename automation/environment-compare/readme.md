# Environment Comparison Tool

A cross-environment screenshot and visual comparison tool for UAT and PROD web environments. All automation is handled by npm scripts and Node.js—no shell scripts required.

---

## 🚀 Quick Start

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Project setup:**
   ```bash
   npm run setup
   ```
   - This checks your config and gives usage instructions.

3. **Edit URL list:**
   - Add your UAT URLs to `config/urls.txt` (PROD URLs are generated automatically).

4. **Run screenshot generation:**
   ```bash
   # Basic screenshot generation
   npm run generate:images

   # With authentication
   UAT_COOKIE="accessToken=xyz..." PROD_COOKIE="accessToken=abc..." npm run generate:images
   ```

5. **Generate HTML comparison report:**
   ```bash
   npm run generate:html
   ```

6. **Build and deploy to Cloudflare Workers:**
   ```bash
   npm run build-and-deploy
   ```

---

## 🗂️ File Structure

```
environment-compare/
├── scripts/                      # All automation scripts (Node.js)
│   ├── generate_environment_images.js   # Screenshot generator
│   ├── generate_comparison_html.js      # HTML report generator
│   └── setup.js                        # Project setup/usage helper
├── config/                       # Configuration files
│   └── urls.txt                  # UAT URLs (PROD URLs are generated automatically)
├── output/                       # Generated files
│   ├── screenshots/
│   │   ├── uat/                  # UAT screenshots
│   │   └── prod/                 # PROD screenshots
│   └── deploy/                   # Deployable HTML report and screenshots
├── readme.md                     # Documentation
└── package.json                  # npm scripts and dependencies
```

---

## ⚙️ Configuration

- Edit `config/urls.txt` to add UAT URLs (one per line). PROD URLs are generated automatically.
- Set authentication cookies as environment variables or in your shell profile:
  ```bash
  export UAT_COOKIE="accessToken=xyz..."
  export PROD_COOKIE="accessToken=abc..."
  ```

---

## ✨ Features

- Takes device-sized screenshots of both environments
- Supports authentication via cookies
- Generates a side-by-side HTML comparison report
- Error handling and logging
- Configurable viewport and timeouts (edit scripts if needed)

---

## 📝 Usage Reference

- **Setup/check config:**
  ```bash
  npm run setup
  ```
- **Generate screenshots:**
  ```bash
  npm run generate:images
  ```
- **Generate HTML report:**
  ```bash
  npm run generate:html
  ```
- **Build and deploy:**
  ```bash
  npm run build-and-deploy
  ```

---

## 🧹 Migration Notice

- All automation is now handled by npm scripts and Node.js. No shell scripts are required.
- The following scripts have been replaced by Node.js:
  - generate_comparison_html.sh
  - generate_environment_images.sh
  - setup.sh
- You can safely remove all .sh files from the scripts directory.

---

## 📄 License

MIT
