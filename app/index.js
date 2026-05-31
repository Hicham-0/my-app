const express = require('express');
const path = require('path');
const app = express();


const APP_VERSION  = process.env.APP_VERSION        || '1.0.0';
const ENVIRONMENT  = process.env.ENVIRONMENT        || 'development';
const REGION       = process.env.AWS_DEFAULT_REGION || process.env.AWS_REGION || 'us-east-1';
const DEPLOY_COLOR = process.env.DEPLOY_COLOR       || 'blue';

// Sert tous les fichiers dans public/ automatiquement
app.use(express.static(path.join(__dirname, 'public')));

// Endpoint info — appelé par le fetch dans index.html
app.get('/info', (req, res) => {
  res.json({
    version: APP_VERSION,
    environment: ENVIRONMENT,
    region: REGION,
    deployColor : DEPLOY_COLOR
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