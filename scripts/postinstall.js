const downloadBinary = require('./download-binary');

console.log('Installing Cirrus CLI...');

downloadBinary()
  .then(() => console.log('✓ Cirrus CLI installed successfully!'))
  .catch((err) => {
    console.error('✗ Failed to download Cirrus binary:', err.message);
    console.error('You can manually download the binary from:');
    console.error('https://github.com/cesarParra/cirrus/releases');
    process.exit(1);
  });
