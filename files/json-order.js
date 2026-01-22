#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function printUsage() {
  console.log('Usage: node json-order.js [output-directory]');
  console.log('Example: node json-order.js ./output');
  console.log('If no directory is provided, uses "./output" by default');
}

function isJsonFile(filename) {
  return filename.endsWith('.json');
}

function sortKeysRecursively(obj) {
  if (Array.isArray(obj)) {
    return obj.map(sortKeysRecursively);
  } else if (obj !== null && typeof obj === 'object') {
    return Object.keys(obj).sort().reduce((acc, key) => {
      acc[key] = sortKeysRecursively(obj[key]);
      return acc;
    }, {});
  }
  return obj;
}

function processJsonFile(filePath) {
  try {
    console.log(`🔄 Processing: ${filePath}`);
    const fileContent = fs.readFileSync(filePath, 'utf8');
    const jsonData = JSON.parse(fileContent);

    const orderedJson = sortKeysRecursively(jsonData);
    fs.writeFileSync(filePath, JSON.stringify(orderedJson, null, 2));

    console.log(`✅ Successfully sorted: ${filePath}`);
    return true;
  } catch (err) {
    console.error(`❌ Error processing ${filePath}: ${err.message}`);
    return false;
  }
}

// Get directory path from command line or use default
const outputDir = process.argv[2] || './output';

if (!fs.existsSync(outputDir)) {
  console.error(`Error: Directory '${outputDir}' does not exist.`);
  process.exit(1);
}

const stats = fs.statSync(outputDir);
if (!stats.isDirectory()) {
  console.error(`Error: '${outputDir}' is not a directory.`);
  process.exit(1);
}

console.log(`📁 Processing JSON files in directory: ${outputDir}`);

try {
  const files = fs.readdirSync(outputDir);
  const jsonFiles = files.filter(isJsonFile);

  if (jsonFiles.length === 0) {
    console.log('ℹ️ No JSON files found in the directory.');
    process.exit(0);
  }

  console.log(`Found ${jsonFiles.length} JSON file(s) to process:`);
  jsonFiles.forEach(file => console.log(`  - ${file}`));
  console.log('');

  let processed = 0;
  let failed = 0;

  jsonFiles.forEach(file => {
    const filePath = path.join(outputDir, file);
    if (processJsonFile(filePath)) {
      processed++;
    } else {
      failed++;
    }
  });

  console.log('\n📊 Summary:');
  console.log(`  ✅ Successfully processed: ${processed} files`);
  console.log(`  ❌ Failed to process: ${failed} files`);

} catch (err) {
  console.error(`Error reading directory: ${err.message}`);
  process.exit(1);
}
