#!/usr/bin/env node
// Tiny static server for the ESPN app, port 8091 (the Yahoo app, if served,
// uses a different port). No dependencies. Serves this folder only.
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8091;
const ROOT = __dirname;
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.webmanifest': 'application/manifest+json',
  '.svg': 'image/svg+xml',
  '.css': 'text/css',
  '.txt': 'text/plain'
};

http.createServer((req, res) => {
  let rel = decodeURIComponent(req.url.split('?')[0]);
  if (rel === '/' || rel === '') rel = '/index.html';
  const file = path.normalize(path.join(ROOT, rel));
  if (!file.startsWith(ROOT)) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(PORT, () => console.log(`Draft OS ESPN on http://localhost:${PORT}/index.html`));
