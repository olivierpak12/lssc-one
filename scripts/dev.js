require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const { execSync } = require('child_process');

const defines = ['CONVEX_SITE_URL', 'CONVEX_URL', 'USE_MAINNET']
  .filter(k => process.env[k])
  .map(k => `--dart-define=${k}=${process.env[k]}`)
  .join(' ');

const cmd = `flutter run -d chrome ${defines}`;
console.log(`Running: ${cmd}`);
execSync(cmd, { stdio: 'inherit' });
