#!/usr/bin/env node

/**
 * Configuration display utility
 * This script loads and displays the current configuration settings
 */

const config = require('./config.js');

function displayConfig() {
  console.log('\n🔧 Environment Comparison Tool - Current Configuration\n');
  console.log('=' .repeat(60));

  console.log('\n📱 Viewport Settings:');
  console.log(`   Width: ${config.viewport.width}px`);
  console.log(`   Height: ${config.viewport.height}px`);

  console.log('\n⏱️  Timeout Settings:');
  console.log(`   Page Timeout: ${config.timeouts.pageTimeout}ms`);
  console.log(`   Screenshot Delay: ${config.timeouts.screenshotDelay}s`);

  console.log('\n🌐 Browser Settings:');
  console.log(`   Headless Mode: ${config.browser.headlessMode}`);
  console.log(`   Browser Args: ${config.browser.args.join(', ')}`);

  console.log('\n📁 Output Settings:');
  console.log(`   Full Page Screenshots: ${config.output.fullPageScreenshots}`);
  console.log(`   Generate Thumbnails: ${config.output.generateThumbnails}`);
  console.log(`   Thumbnail Width: ${config.output.thumbnailWidth}px`);

  console.log('\n📊 Report Settings:');
  console.log(`   Title: "${config.report.title}"`);
  console.log(`   Include Summary Stats: ${config.report.includeSummaryStats}`);
  console.log(`   Include Timestamp: ${config.report.includeTimestamp}`);

  console.log('\n📝 Logging Settings:');
  console.log(`   Log Level: ${config.logging.level}`);
  console.log(`   Log to File: ${config.logging.logToFile}`);

  console.log('\n' + '=' .repeat(60));
  console.log('\n💡 To modify these settings, edit: config/config.js');
  console.log('📚 For more information, see: readme.md\n');
}

// Run the display function if this script is executed directly
if (require.main === module) {
  displayConfig();
}

module.exports = { displayConfig };
