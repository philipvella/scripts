#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function printUsage() {
  console.log('Usage: node json-check-equality.js <json-file-1> <json-file-2>');
  console.log('Example: node json-check-equality.js a.json b.json');
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

if (process.argv.length < 4) {
  printUsage();
  process.exit(1);
}

const file1 = process.argv[2];
const file2 = process.argv[3];

if (!fs.existsSync(file1)) {
  console.error(`Error: File '${file1}' does not exist.`);
  process.exit(1);
}
if (!fs.existsSync(file2)) {
  console.error(`Error: File '${file2}' does not exist.`);
  process.exit(1);
}
if (!isJsonFile(file1) || !isJsonFile(file2)) {
  console.error('Error: Both files must have a .json extension.');
  process.exit(1);
}

let json1, json2;
try {
  json1 = JSON.parse(fs.readFileSync(file1, 'utf8'));
} catch (err) {
  console.error(`Error: '${file1}' does not contain valid JSON.`);
  process.exit(1);
}
try {
  json2 = JSON.parse(fs.readFileSync(file2, 'utf8'));
} catch (err) {
  console.error(`Error: '${file2}' does not contain valid JSON.`);
  process.exit(1);
}

const sorted1 = sortKeysRecursively(json1);
const sorted2 = sortKeysRecursively(json2);

const areEqual = JSON.stringify(sorted1) === JSON.stringify(sorted2);

if (areEqual) {
  console.log('✅ The two JSON files are equal (after sorting keys recursively).');
} else {
  console.log('❌ The two JSON files are NOT equal (after sorting keys recursively).');
}

