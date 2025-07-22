#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

// Read package.json
const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8'));
const version = packageJson.version;

// Generate Dart file content
const dartContent = `// Generated file. Do not edit manually.
// Run 'node scripts/generate_version.js' to update.

const String appVersion = '${version}';
`;

// Write to lib/src/version.dart
const versionFilePath = path.join(__dirname, '..', 'bin', 'src', 'version.dart');
fs.writeFileSync(versionFilePath, dartContent);

console.log(`Generated version.dart with version ${version}`);
