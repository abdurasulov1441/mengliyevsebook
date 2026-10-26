'use strict';

const path = require('path');
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const config = require('./config');
const { HttpError } = require('./util');

const SWAGGER_HTML = `<!doctype html><html><head><meta charset="utf-8"><title>BookHub API</title>
<meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/api/docs/swagger-ui.css">
<style>body{margin:0}.topbar{display:none}</style></head><body><div id="ui"></div>
<script src="/api/docs/swagger-ui-bundle.js"></script><script>
window.ui = SwaggerUIBundle({ url: '/api/openapi.json', dom_id: '#ui', persistAuthorization: true, tryItOutEnabled: true, displayRequestDuration: true });
</script></body></html>`;

function createApp() {
  const app = express();
  app.disable('x-powered-by');
  if (config.trustProxy) app.set('trust proxy', 1);

  app.use(cors({ origin: config.corsOrigins.includes('*') ? true : config.corsOrigins, exposedHeaders: ['X-Package-Version', 'Content-Disposition'] }));
  app.use(express.json({ limit: '4mb' }));
  app.use(express.urlencoded({ extended: false, limit: '1mb' }));
  app.use((req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'same-origin');
    next();
  });

  // Uploaded covers/author photos/receipts (unguessable names).
  app.use('/_files', express.static(config.publicDir, { maxAge: '7d', index: false, dotfiles: 'deny' }));
  // Reader engine (also bundled into the mobile app) and the admin panel.
  app.use('/reader', express.static(path.join(__dirname, '..', 'public', 'reader'), { maxAge: '1h' }));
  app.use('/admin', express.static(path.join(__dirname, '..', 'public', 'admin'), { maxAge: 0 }));
  app.get('/', (_req, res) => res.redirect('/api/docs'));
  app.get('/api/health', (_req, res) => res.json({ ok: true, time: new Date().toISOString() }));

  const api = express.Router();
  api.use(require('./routes/auth'));
  api.use(require('./routes/books'));
  api.use(require('./routes/studio'));
  api.use(require('./routes/orders'));
  api.use(require('./routes/admin'));

  // API documentation: /api/docs (Swagger UI), /api/openapi.json
  app.get('/api/openapi.json', (_req, res) => res.json(require('./openapi')()));
  app.get('/api/docs', (_req, res) => res.type('html').send(SWAGGER_HTML));
  app.use('/api/docs', express.static(require('swagger-ui-dist').getAbsoluteFSPath(), { index: false }));
  app.use('/api', api);

  app.use('/api', (_req, _res, next) => next(new HttpError(404, 'Topilmadi')));

  // Error body carries the message in every place the app looks for it:
  // data.message, data.response.message (HTTP 400) and data.translates.*.
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, _next) => {
    let status = err.status || err.statusCode || 500;
    let message = err.message || 'Server xatosi';
    if (err instanceof multer.MulterError) {
      status = 400;
      message = err.code === 'LIMIT_FILE_SIZE' ? `Fayl juda katta (maksimum ${config.uploads.maxBookMb} MB)` : `Fayl yuklashda xato: ${err.message}`;
    } else if (err.type === 'entity.parse.failed') {
      status = 400;
      message = "So'rov formati noto'g'ri (JSON)";
    }
    if (status >= 500) {
      console.error(`[${req.method} ${req.originalUrl}]`, err);
      if (config.isProd) message = 'Server xatosi. Keyinroq urinib ko‘ring';
    }
    res.status(status).json({ statusCode: status, status, message, response: { message }, translates: { uz: message, ru: message, oz: message } });
  });

  return app;
}

module.exports = { createApp };
