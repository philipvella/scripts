// Node.js script to generate environment screenshots for UAT and PROD
const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer');
const config = require('../config/config.js');

const CONFIG_DIR = path.join(__dirname, '../config');
const OUTPUT_DIR = path.join(__dirname, 'output');
const SCREENSHOTS_DIR = path.join(OUTPUT_DIR, 'screenshots');
const URLS_FILE = path.join(CONFIG_DIR, 'urls.txt');
const UAT_COOKIE = process.env.UAT_COOKIE || '';
const PROD_COOKIE = process.env.PROD_COOKIE || '';

// Base URLs for environments
const UAT_BASE = 'https://uat.supersportbet.com';
const PROD_BASE = 'https://www.supersportbet.com';

function log(msg) {
  if (config.logging.level === 'DEBUG' || config.logging.level === 'INFO') {
    console.log(`\x1b[34m[${new Date().toISOString()}]\x1b[0m ${msg}`);
  }
}
function error(msg) {
  console.error(`\x1b[31m[ERROR]\x1b[0m ${msg}`);
}
function success(msg) {
  if (config.logging.level === 'DEBUG' || config.logging.level === 'INFO') {
    console.log(`\x1b[32m[SUCCESS]\x1b[0m ${msg}`);
  }
}
function warn(msg) {
  if (config.logging.level === 'DEBUG' || config.logging.level === 'INFO' || config.logging.level === 'WARN') {
    console.warn(`\x1b[33m[WARNING]\x1b[0m ${msg}`);
  }
}

function mkdirp(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function urlToFilename(url) {
  return url.replace(/^https?:\/\//, '').replace(/[\/\?&=]/g, '_');
}

function uatToProdUrl(url) {
  return url.replace('uat.supersportbet.com', 'www.supersportbet.com');
}

function pathToFilename(relativePath) {
  // Convert relative path to safe filename
  return relativePath.replace(/^\/+/, '').replace(/[\/\?&=]/g, '_') || 'root';
}

function constructUrl(relativePath, baseUrl) {
  // Ensure path starts with /
  const cleanPath = relativePath.startsWith('/') ? relativePath : `/${relativePath}`;
  return `${baseUrl}${cleanPath}`;
}

async function takeScreenshot(url, outputPath, cookie, envName) {
  log(`Taking screenshot of ${url} (${envName})`);
  log(`Screenshot will be saved to: ${outputPath}`);
  try {
    const browser = await puppeteer.launch({
      headless: config.browser.headlessMode ? 'new' : false,
      args: config.browser.args
    });
    const page = await browser.newPage();
    await page.setViewport({
      width: config.viewport.width,
      height: config.viewport.height
    });
    if (cookie) {
      const cookies = cookie.split(';').map(pair => {
        const [name, ...rest] = pair.trim().split('=');
        if (["Path", "Expires", "Max-Age", "Domain", "Secure", "HttpOnly", "SameSite"].includes(name)) return null;
        if (!name || rest.length === 0) return null;
        const value = rest.join('=');
        return { name, value, domain: new URL(url).hostname };
      }).filter(Boolean);
      if (cookies.length > 0) {
        await page.setCookie(...cookies);
      }
    }
    await page.goto(url, { waitUntil: 'networkidle2', timeout: config.timeouts.pageTimeout });

    // Add screenshot delay if configured
    if (config.timeouts.screenshotDelay > 0) {
      await new Promise(resolve => setTimeout(resolve, config.timeouts.screenshotDelay * 1000));
    }

    const screenshotOptions = { path: outputPath };
    if (config.output.fullPageScreenshots) {
      screenshotOptions.fullPage = true;
    }

    await page.screenshot(screenshotOptions);
    await browser.close();
    if (fs.existsSync(outputPath)) {
      success(`Screenshot saved: ${outputPath}`);
    } else {
      warn(`Screenshot NOT created: ${outputPath}`);
    }
  } catch (err) {
    error(`Error taking screenshot of ${url}: ${err.message}`);
  }
}

async function processEnvironment(envName, cookie, screenshotDir, baseUrl) {
  if (!fs.existsSync(URLS_FILE)) {
    error(`URLs file not found: ${URLS_FILE}`);
    return;
  }
  log(`Processing ${envName} environment...`);

  // Read relative paths from urls.txt
  const relativePaths = fs.readFileSync(URLS_FILE, 'utf-8')
    .split('\n')
    .map(l => l.trim())
    .filter(l => l && !l.startsWith('#'));

  let count = 0;
  for (const relativePath of relativePaths) {
    const fullUrl = constructUrl(relativePath, baseUrl);
    const filename = pathToFilename(relativePath);
    const outputPath = path.join(screenshotDir, `${filename}.png`);

    await takeScreenshot(fullUrl, outputPath, cookie, envName);
    count++;

    // Random sleep between 0 and 1 seconds
    const sleepMs = Math.floor(Math.random() * 1000);
    await new Promise(res => setTimeout(res, sleepMs));
  }
  success(`Processed ${count} URLs for ${envName}`);
}

async function main() {
  log('Starting environment comparison...');
  mkdirp(path.join(SCREENSHOTS_DIR, 'uat'));
  mkdirp(path.join(SCREENSHOTS_DIR, 'prod'));
  log(`UAT_COOKIE value: ${UAT_COOKIE}`);
  log(`PROD_COOKIE value: ${PROD_COOKIE}`);

  await processEnvironment('UAT', UAT_COOKIE, path.join(SCREENSHOTS_DIR, 'uat'), UAT_BASE);
  await processEnvironment('PROD', PROD_COOKIE, path.join(SCREENSHOTS_DIR, 'prod'), PROD_BASE);

  console.log('\nResults:');
  console.log(`  Screenshots: ${SCREENSHOTS_DIR}`);
  console.log('\nTo view the screenshots, open the files in:', SCREENSHOTS_DIR);
}

main();
