// Node.js setup script for Environment Comparison Tool
const fs = require('fs');
const path = require('path');

const CONFIG_DIR = path.join(__dirname, '../config');
const URLS_FILE = path.join(CONFIG_DIR, 'urls.txt');

const GREEN = '\x1b[32m';
const BLUE = '\x1b[34m';
const YELLOW = '\x1b[33m';
const NC = '\x1b[0m';

console.log(`${BLUE}Environment Comparison Tool Setup${NC}`);
console.log('==================================');
console.log();

// Check for urls.txt
if (fs.existsSync(URLS_FILE) && fs.statSync(URLS_FILE).size > 0) {
  console.log(`${GREEN}\u2713 URLs file exists and has content${NC}`);
} else {
  console.log(`${YELLOW}\u26a0 Please add URLs to urls.txt${NC}`);
}

console.log();
console.log('Usage Examples:');
console.log('===============');
console.log();
console.log('1. Basic comparison (no authentication):');
console.log('   npm run generate:images');
console.log();
console.log('2. With authentication cookies:');
console.log("   UAT_COOKIE='accessToken=xyz...' PROD_COOKIE='accessToken=abc...' npm run generate:images");
console.log();
console.log('3. Generate HTML report:');
console.log('   npm run generate:html');
console.log();
console.log('4. Build and deploy:');
console.log('   npm run build-and-deploy');
console.log();
console.log('Files you can customize:');
console.log('=======================');
console.log('- config/urls.txt: List of UAT environment URLs (PROD URLs are generated automatically)');
console.log();
console.log(`${GREEN}Setup complete! You\'re ready to run environment comparisons.${NC}`);

