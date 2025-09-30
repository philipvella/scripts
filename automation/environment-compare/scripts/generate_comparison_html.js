// Node.js script to generate the HTML comparison report and copy screenshots
const fs = require('fs');
const path = require('path');
const fse = require('fs-extra');
const config = require('../config/config.js');

const OUTPUT_DIR = path.join(__dirname, 'output');
const UAT_DIR = path.join(OUTPUT_DIR, 'screenshots', 'uat');
const PROD_DIR = path.join(OUTPUT_DIR, 'screenshots', 'prod');
const DEPLOY_DIR = path.join(OUTPUT_DIR, 'deploy');
const DEPLOY_UAT = path.join(DEPLOY_DIR, 'screenshots', 'uat');
const DEPLOY_PROD = path.join(DEPLOY_DIR, 'screenshots', 'prod');

function mkdirp(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function copyPngs(srcDir, destDir) {
  if (!fs.existsSync(srcDir)) return 0;
  const files = fs.readdirSync(srcDir).filter(f => f.endsWith('.png'));
  files.forEach(f => fs.copyFileSync(path.join(srcDir, f), path.join(destDir, f)));
  return files.length;
}

function getUatFiles() {
  if (!fs.existsSync(DEPLOY_UAT)) return [];
  return fs.readdirSync(DEPLOY_UAT).filter(f => f.endsWith('.png'));
}

function getTimestamp() {
  if (!config.report.includeTimestamp) return '';
  const now = new Date();
  return now.toLocaleString('en-US', { dateStyle: 'long', timeStyle: 'short' });
}

function generateHtml(uatFiles, uatCount, prodCount, pairsCount) {
  const timestamp = getTimestamp();
  let html = `<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="UTF-8">\n<meta name="viewport" content="width=device-width, initial-scale=1.0">\n<title>${config.report.title}</title>\n<link rel="icon" href="favicon.ico" type="image/x-icon">\n<style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#f8f9fa;margin:0;padding:20px;line-height:1.6}html{scroll-behavior:smooth}.header{text-align:center;background:#fff;padding:30px;border-radius:12px;box-shadow:0 4px 12px rgba(0,0,0,0.1);margin-bottom:30px}.header h1{margin:0 0 10px 0;color:#2c3e50;font-size:2.5em}.header p{color:#7f8c8d;margin:0;font-size:1.1em}.comparison{background:#fff;border-radius:12px;box-shadow:0 4px 12px rgba(0,0,0,0.08);margin-bottom:30px;padding:25px;transition:transform 0.2s ease}.comparison:hover{transform:translateY(-2px);box-shadow:0 8px 25px rgba(0,0,0,0.12)}.comparison:target{border-left:4px solid #3498db;box-shadow:0 8px 25px rgba(52,152,219,0.2)}.url{font-weight:600;margin-bottom:20px;word-break:break-all;font-size:1.1em;color:#34495e;padding:15px;background:#f8f9fa;border-radius:8px;border-left:4px solid #3498db}.screenshots{display:grid;grid-template-columns:1fr 1fr;gap:25px}@media (max-width:768px){.screenshots{grid-template-columns:1fr}}.env{text-align:center}.env-label{font-weight:600;margin-bottom:15px;padding:12px 20px;border-radius:25px;color:#fff;font-size:.95em;text-transform:uppercase;letter-spacing:.5px}.uat-label{background:linear-gradient(135deg,#ff6b35,#f39c12)}.prod-label{background:linear-gradient(135deg,#27ae60,#2ecc71)}.img-container{position:relative;border-radius:8px;overflow:hidden;box-shadow:0 4px 15px rgba(0,0,0,0.1);width:max-content;margin:auto}img{width:100%;height:auto;display:block;transition:transform .3s ease}.img-container:hover img{transform:scale(1.02)}.missing{color:#7f8c8d;font-style:italic;background:#ecf0f1;padding:60px 20px;border-radius:8px;text-align:center;font-size:1.1em}.stats{background:#fff;padding:20px;border-radius:12px;box-shadow:0 4px 12px rgba(0,0,0,0.08);margin-bottom:30px;text-align:center}.stats h2{margin:0 0 15px 0;color:#2c3e50}.stat-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:15px;margin-top:20px}.stat-item{padding:15px;background:#f8f9fa;border-radius:8px}.stat-number{font-size:2em;font-weight:bold;color:#3498db}.stat-label{color:#7f8c8d;font-size:.9em;text-transform:uppercase;letter-spacing:.5px}.urls-section{margin-top:30px;text-align:left}.urls-section h3{text-align:center;margin-bottom:20px;color:#2c3e50}.urls-grid{display:grid;grid-template-columns:1fr 1fr;gap:30px;max-width:1000px;margin:0 auto}@media (max-width:768px){.urls-grid{grid-template-columns:1fr}}.urls-column{background:#f8f9fa;padding:20px;border-radius:8px}.urls-column h4{margin:0 0 15px 0;padding:10px 15px;border-radius:20px;color:#fff;text-align:center;font-size:.9em;text-transform:uppercase;letter-spacing:.5px}.uat-header{background:linear-gradient(135deg,#ff6b35,#f39c12)}.prod-header{background:linear-gradient(135deg,#27ae60,#2ecc71)}.urls-list{list-style:none;padding:0;margin:0}.urls-list li{margin-bottom:8px}.url-link{display:block;padding:8px 12px;text-decoration:none;border-radius:6px;transition:all 0.2s ease;font-family:monospace;font-size:.9em}.url-link:hover{transform:translateX(5px);box-shadow:0 2px 8px rgba(0,0,0,0.1)}.uat-link{color:#d35400;background:rgba(255,107,53,0.1);border-left:3px solid #ff6b35}.uat-link:hover{background:rgba(255,107,53,0.2)}.prod-link{color:#27ae60;background:rgba(46,204,113,0.1);border-left:3px solid #2ecc71}.prod-link:hover{background:rgba(46,204,113,0.2)}</style>\n</head>\n<body>\n<div class="header">\n<h1>${config.report.title}</h1>`;

  if (timestamp) {
    html += `\n<p>Generated on ${timestamp}</p>`;
  }

  html += `\n</div>\n`;

  // Only include stats section if configured
  if (config.report.includeSummaryStats) {
    html += `<div class="stats">\n<h2>Comparison Statistics</h2>\n<div class="stat-grid">\n<div class="stat-item">\n<div class="stat-number">${uatCount}</div>\n<div class="stat-label">UAT Screenshots</div>\n</div>\n<div class="stat-item">\n<div class="stat-number">${prodCount}</div>\n<div class="stat-label">PROD Screenshots</div>\n</div>\n<div class="stat-item">\n<div class="stat-number">${pairsCount}</div>\n<div class="stat-label">Complete Pairs</div>\n</div>\n</div>\n`;

    // Add URLs list section
    if (uatFiles.length > 0) {
      html += `<div class="urls-section">\n<h3>URLs Compared</h3>\n<div class="urls-grid">\n<div class="urls-column">\n<h4 class="uat-header">UAT Paths</h4>\n<ul class="urls-list uat-urls">\n`;

      uatFiles.forEach((uatFile, index) => {
        const path = uatFile.replace('uat.supersportbet.com_', '').replace(/_/g, '/').replace('.png', '');
        const displayPath = path === '' ? '/' : `/${path}`;
        html += `<li><a href="#comparison-${index}" class="url-link uat-link">${displayPath}</a></li>\n`;
      });

      html += `</ul>\n</div>\n<div class="urls-column">\n<h4 class="prod-header">PROD Paths</h4>\n<ul class="urls-list prod-urls">\n`;

      uatFiles.forEach((uatFile, index) => {
        const path = uatFile.replace('uat.supersportbet.com_', '').replace(/_/g, '/').replace('.png', '');
        const displayPath = path === '' ? '/' : `/${path}`;
        html += `<li><a href="#comparison-${index}" class="url-link prod-link">${displayPath}</a></li>\n`;
      });

      html += `</ul>\n</div>\n</div>\n</div>\n`;
    }

    html += `</div>\n`;
  }

  uatFiles.forEach((uatFile, index) => {
    const prodFile = uatFile.replace('uat.supersportbet.com', 'www.supersportbet.com');
    const uatUrl = 'https://uat.supersportbet.com/' + uatFile.replace('uat.supersportbet.com_', '').replace(/_/g, '/').replace('.png', '');
    const prodUrl = uatUrl.replace('uat.supersportbet.com', 'www.supersportbet.com');
    html += `<div class="comparison" id="comparison-${index}">
<div class="url">
  <strong>UAT:</strong> <a href="${uatUrl}" target="_blank">${uatUrl}</a><br>
  <strong>PROD:</strong> <a href="${prodUrl}" target="_blank">${prodUrl}</a>
</div>
<div class="screenshots">
<div class="env">
<div class="env-label uat-label">UAT Environment</div>
`;
    if (fs.existsSync(path.join(DEPLOY_UAT, uatFile))) {
      html += `<div class="img-container"><img src="screenshots/uat/${uatFile}" alt="UAT Screenshot" loading="lazy"></div>`;
    } else {
      html += `<div class="missing">No UAT screenshot available</div>`;
    }
    html += `</div>
<div class="env">
<div class="env-label prod-label">PROD Environment</div>
`;
    if (fs.existsSync(path.join(DEPLOY_PROD, prodFile))) {
      html += `<div class="img-container"><img src="screenshots/prod/${prodFile}" alt="PROD Screenshot" loading="lazy"></div>`;
    } else {
      html += `<div class="missing">No PROD screenshot available</div>`;
    }
    html += `</div>
</div>
</div>`;
  });
  html += `</body>\n</html>`;
  return html;
}

async function syncPublicWithDeploy() {
  const publicDir = path.join(__dirname, '../public');
  const deployDir = path.join(__dirname, 'output', 'deploy');
  if (fs.existsSync(publicDir)) {
    fse.emptyDirSync(publicDir);
  } else {
    fs.mkdirSync(publicDir, { recursive: true });
  }
  if (fs.existsSync(deployDir)) {
    fse.copySync(deployDir, publicDir, { overwrite: true });
  }
}

async function main() {
  mkdirp(DEPLOY_UAT);
  mkdirp(DEPLOY_PROD);

  // Copy favicon from src to deploy directory
  const srcDir = path.join(__dirname, '../src');
  const faviconSrc = path.join(srcDir, 'favicon.ico');
  const faviconDest = path.join(DEPLOY_DIR, 'favicon.ico');

  if (fs.existsSync(faviconSrc)) {
    fs.copyFileSync(faviconSrc, faviconDest);
    console.log('Copied favicon.ico from src to deploy directory');
  } else {
    console.log('Warning: favicon.ico not found in src directory');
  }

  const uatCount = copyPngs(UAT_DIR, DEPLOY_UAT);
  const prodCount = copyPngs(PROD_DIR, DEPLOY_PROD);
  const uatFiles = getUatFiles();
  let pairsCount = 0;
  let prodFiles = 0;
  uatFiles.forEach(uatFile => {
    const prodFile = uatFile.replace('uat.supersportbet.com', 'www.supersportbet.com');
    if (fs.existsSync(path.join(DEPLOY_PROD, prodFile))) prodFiles++;
    if (fs.existsSync(path.join(DEPLOY_UAT, uatFile)) && fs.existsSync(path.join(DEPLOY_PROD, prodFile))) pairsCount++;
  });
  const html = generateHtml(uatFiles, uatCount, prodFiles, pairsCount);
  fs.writeFileSync(path.join(DEPLOY_DIR, 'index.html'), html);
  console.log('============================================');
  console.log('Deployment folder created:', DEPLOY_DIR);
  console.log('============================================');
  console.log('Contents:');
  console.log('  - index.html (main comparison page)');
  console.log(`  - screenshots/uat/ (${uatCount} files)`);
  console.log(`  - screenshots/prod/ (${prodFiles} files)`);
  console.log('\nReady to upload to Cloudflare Workers!');
  console.log(`Just upload the entire '${DEPLOY_DIR}' folder contents.`);
  console.log('============================================');
}

// IIFE to run main logic and sync
(async () => {
  await main();
  await syncPublicWithDeploy();
})();
