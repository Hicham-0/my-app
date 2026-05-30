const express = require('express');
const path = require('path');
const app = express();

const PORT = process.env.PORT || 8080;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const ENVIRONMENT = process.env.ENVIRONMENT || 'production';
const DEPLOY_COLOR = process.env.DEPLOY_COLOR || 'blue';
const REGION = process.env.AWS_REGION || 'eu-west-1';

// Sert tous les fichiers dans public/ automatiquement
app.use(express.static(path.join(__dirname, 'public')));

// Endpoint info — appelé par le fetch dans index.html
app.get('/info', (req, res) => {
  res.json({
    version: APP_VERSION,
    environment: ENVIRONMENT,
    deployColor: DEPLOY_COLOR,
    region: REGION
  });
});

// Endpoint health — utilisé par l'ALB
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

module.exports = app;

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`App v${APP_VERSION} running on port ${PORT}`);
  });
}