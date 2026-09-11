'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number(process.env.PORT) || 3001;
const publicDir = __dirname;
const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
};

function sendFile(response, filePath) {
  fs.readFile(filePath, (error, data) => {
    if (error) {
      response.writeHead(error.code === 'ENOENT' ? 404 : 500, {
        'Content-Type': 'text/plain; charset=utf-8',
      });
      response.end(error.code === 'ENOENT' ? 'Not found' : 'Server error');
      return;
    }

    response.writeHead(200, {
      'Content-Type': contentTypes[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
      'X-Content-Type-Options': 'nosniff',
    });
    response.end(data);
  });
}

http.createServer((request, response) => {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.writeHead(405, { Allow: 'GET, HEAD' });
    response.end();
    return;
  }

  const requestedPath = new URL(request.url, `http://${request.headers.host}`).pathname;
  const relativePath = requestedPath === '/'
    ? 'index.html'
    : requestedPath === '/privacy'
      ? 'privacy.html'
      : requestedPath.replace(/^\/+/, '');
  const filePath = path.resolve(publicDir, relativePath);

  // Keep requests inside this landing-page directory.
  if (!filePath.startsWith(`${publicDir}${path.sep}`)) {
    response.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('Forbidden');
    return;
  }

  if (request.method === 'HEAD') {
    fs.access(filePath, fs.constants.R_OK, (error) => {
      response.writeHead(error ? 404 : 200);
      response.end();
    });
    return;
  }

  sendFile(response, filePath);
}).listen(port, () => {
  console.log(`MyTaskKing landing page running at http://localhost:${port}`);
});
