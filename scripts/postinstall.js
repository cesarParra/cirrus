const downloadBinary = require('./download-binary');
const fs = require('fs');
const path = require('path');

console.log('Installing Cirrus CLI...');

downloadBinary()
  .then(() => {
    // Ensure the wrapper script is executable
    const wrapperPath = path.join(__dirname, '..', 'bin', 'cirrus');
    if (fs.existsSync(wrapperPath)) {
      try {
        fs.chmodSync(wrapperPath, '755');
        console.log('✓ Made wrapper script executable');
      } catch (err) {
        console.warn('⚠ Could not set wrapper script permissions:', err.message);
      }
    }
    console.log('✓ Cirrus CLI installed successfully!');
  })
  .catch((err) => {
    console.error('✗ Failed to download Cirrus binary:', err.message);
    console.error('You can manually download the binary from:');
    console.error('https://github.com/cesarParra/cirrus/releases');
    process.exit(1);
  });
