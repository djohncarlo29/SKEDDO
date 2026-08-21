'use strict';

// Static Flutter web server for SKEDDO. All analysis, speech recognition,
// rule parsing, and event extraction run locally in the app.
const http = require('http');
const path = require('path');
const fs = require('fs');

const PORT = process.env.PORT || 24355;
const WEB_DIR = path.join(
  __dirname,
  '..',
  'artifacts',
  'smart-scheduler',
  'build',
  'web',
);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
};

function serveStatic(req, res) {
  const urlPath = req.url.split('?')[0];
  let filePath = path.join(WEB_DIR, urlPath === '/' ? 'index.html' : urlPath);

  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(WEB_DIR, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME[ext] || 'application/octet-stream';
  const isHtml = ext === '.html' || filePath.endsWith('index.html');
  const isHashedAsset = filePath.includes(`${path.sep}assets${path.sep}`);
  const cacheControl =
    isHashedAsset && !isHtml
      ? 'public, max-age=31536000, immutable'
      : 'no-cache, no-store, must-revalidate';

  fs.readFile(filePath, (error, data) => {
    if (error) {
      res.writeHead(404);
      res.end('Not Found');
      return;
    }
    res.writeHead(200, {
      'Content-Type': contentType,
      'Cache-Control': cacheControl,
    });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  serveStatic(req, res);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`SKEDDO offline web server listening on port ${PORT}`);
});