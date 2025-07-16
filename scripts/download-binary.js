const https = require('https');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');
const stream = require('stream');

const pipeline = promisify(stream.pipeline);

// Configuration
const REPO_OWNER = 'cesarParra';
const REPO_NAME = 'cirrus';
const VERSION = require('../package.json').version;

async function downloadBinary() {
  const platform = process.platform;
  const arch = process.arch;
  
  // Map Node.js platform names to our binary naming convention
  const platformMap = {
    'darwin': 'darwin',
    'linux': 'linux',
    'win32': 'windows'
  };
  
  const mappedPlatform = platformMap[platform];
  if (!mappedPlatform) {
    throw new Error(`Unsupported platform: ${platform}`);
  }
  
  const binaryName = `cirrus-${mappedPlatform}-${arch}${platform === 'win32' ? '.exe' : ''}`;
  const downloadUrl = `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/v${VERSION}/${binaryName}`;
  
  const binariesDir = path.join(__dirname, '..', 'binaries');
  const binaryPath = path.join(binariesDir, binaryName);
  
  console.log(`Downloading ${binaryName}...`);
  console.log(`From: ${downloadUrl}`);
  
  // Create binaries directory if it doesn't exist
  if (!fs.existsSync(binariesDir)) {
    fs.mkdirSync(binariesDir, { recursive: true });
  }
  
  // Download the binary
  await downloadFile(downloadUrl, binaryPath);
  
  // Make the binary executable on Unix-like systems
  if (platform !== 'win32') {
    fs.chmodSync(binaryPath, '755');
  }
  
  console.log(`Downloaded to: ${binaryPath}`);
}

function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    
    https.get(url, (response) => {
      // Handle redirects
      if (response.statusCode === 302 || response.statusCode === 301) {
        file.destroy();
        return downloadFile(response.headers.location, dest).then(resolve).catch(reject);
      }
      
      if (response.statusCode !== 200) {
        file.destroy();
        fs.unlinkSync(dest);
        reject(new Error(`Failed to download: HTTP ${response.statusCode}`));
        return;
      }
      
      const totalSize = parseInt(response.headers['content-length'], 10);
      let downloadedSize = 0;
      
      response.on('data', (chunk) => {
        downloadedSize += chunk.length;
        const progress = Math.round((downloadedSize / totalSize) * 100);
        process.stdout.write(`\rProgress: ${progress}%`);
      });
      
      pipeline(response, file)
        .then(() => {
          console.log('\nDownload complete!');
          resolve();
        })
        .catch(reject);
    }).on('error', (err) => {
      fs.unlinkSync(dest);
      reject(err);
    });
  });
}

module.exports = downloadBinary;

// Run directly if called from command line
if (require.main === module) {
  downloadBinary()
    .then(() => console.log('Binary downloaded successfully'))
    .catch((err) => {
      console.error('Failed to download binary:', err);
      process.exit(1);
    });
}
