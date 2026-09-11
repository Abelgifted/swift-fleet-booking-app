'use strict';

/**
 * Swift Fleet — single-service web server.
 *
 * Serves the compiled Flutter web app and proxies the fleet API on the SAME
 * origin, so the deployed app can call `/api/fleet/*` as a relative path with
 * no CORS preflight and no hardcoded host.
 *
 *   GET /                    → public/index.html   (Flutter app)
 *   GET /trips               → public/index.html   (SPA deep link)
 *   GET /main.dart.js        → public/main.dart.js
 *   GET /health              → {"status":"ok", …}  (Render health check)
 *   ANY /api/fleet/*         → https://ecomapi.swift.ng/api/fleet/*
 *
 * Uses only Node built-ins (http, https, fs, path, zlib, url) so there is
 * nothing to install — which keeps cold starts fast on Render's free tier.
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// ── Configuration ────────────────────────────────────────────────────

const PORT = Number(process.env.PORT || 8787);
const UPSTREAM_HOST = process.env.UPSTREAM_HOST || 'ecomapi.swift.ng';
const UPSTREAM_PORT = Number(process.env.UPSTREAM_PORT || 443);
const UPSTREAM_SCHEME = process.env.UPSTREAM_SCHEME || 'https';

// Store credentials. Supplied by the environment on Render so the key can be
// rotated without a rebuild; the defaults keep local development working.
const API_KEY = process.env.API_KEY || 'SK_live_e5a57f63ebff4fdb822efc23';
const STORE_ID = process.env.STORE_ID || 'bentalsupermarket';

// Flutter's build output. `npm run build:web` compiles into this folder.
const PUBLIC_DIR = path.resolve(__dirname, 'public');
const API_PREFIX = '/api/';

const VERSION = process.env.APP_VERSION || '1.0.0';
const STARTED_AT = Date.now();

// ── Helpers ──────────────────────────────────────────────────────────

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.otf2': 'font/otf',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.pdf': 'application/pdf',
  '.mp4': 'video/mp4',
};

function contentTypeFor(filePath) {
  return MIME_TYPES[path.extname(filePath).toLowerCase()] ||
    'application/octet-stream';
}

/** CORS is applied to every response, including errors. */
function applyCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader(
    'Access-Control-Allow-Methods',
    'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  );
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, X-Api-Key, Authorization, Accept, Origin',
  );
  res.setHeader('Access-Control-Max-Age', '86400');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Type');
}

function sendJson(res, status, payload) {
  const body = Buffer.from(JSON.stringify(payload, null, 2));
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': body.length,
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

function log(...args) {
  console.log(`[${new Date().toISOString()}]`, ...args);
}

// ── Static files ─────────────────────────────────────────────────────

/**
 * Flutter's service worker and the HTML shell must never be cached, or a
 * deploy will not reach returning visitors. Everything else is content
 * addressed or safe to hold briefly.
 */
function cacheControlFor(filePath) {
  const name = path.basename(filePath);
  if (name === 'flutter_service_worker.js' || name === 'index.html') {
    return 'no-cache, no-store, must-revalidate';
  }
  if (name === 'version.json' || name === 'flutter_bootstrap.js') {
    return 'no-cache';
  }
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.html' || ext === '.js' || ext === '.json') {
    return 'no-cache';
  }
  if (['.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.ico',
    '.ttf', '.otf', '.woff', '.woff2'].includes(ext)) {
    return 'public, max-age=604800';
  }
  return 'public, max-age=3600';
}

/** Small gzip cache — Flutter's main.dart.js is multi-megabyte. */
const gzipCache = new Map();
const GZIP_MAX_ENTRIES = 32;

function gzipFor(filePath, buffer, mtimeMs) {
  const key = `${filePath}:${mtimeMs}`;
  const hit = gzipCache.get(key);
  if (hit) return hit;
  const zipped = zlib.gzipSync(buffer, { level: 6 });
  if (gzipCache.size >= GZIP_MAX_ENTRIES) {
    gzipCache.delete(gzipCache.keys().next().value);
  }
  gzipCache.set(key, zipped);
  return zipped;
}

const COMPRESSIBLE = new Set([
  '.html', '.js', '.mjs', '.json', '.css', '.map', '.svg', '.txt', '.xml',
]);

function sendFile(req, res, filePath, { spaFallback = false } = {}) {
  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
      if (spaFallback) {
        return sendFile(req, res, path.join(PUBLIC_DIR, 'index.html'));
      }
      return notFound(res);
    }

    const headers = {
      'Content-Type': contentTypeFor(filePath),
      'Cache-Control': cacheControlFor(filePath),
      'Last-Modified': stat.mtime.toUTCString(),
      'X-Content-Type-Options': 'nosniff',
    };

    const ext = path.extname(filePath).toLowerCase();
    const acceptsGzip = /\bgzip\b/.test(req.headers['accept-encoding'] || '');
    const compressible = COMPRESSIBLE.has(ext);

    if (!compressible) {
      headers['Content-Length'] = stat.size;
      res.writeHead(200, headers);
      if (req.method === 'HEAD') return res.end();
      return fs.createReadStream(filePath).pipe(res);
    }

    fs.readFile(filePath, (readErr, buffer) => {
      if (readErr) return notFound(res);
      if (acceptsGzip) {
        const zipped = gzipFor(filePath, buffer, stat.mtimeMs);
        headers['Content-Encoding'] = 'gzip';
        headers['Content-Length'] = zipped.length;
        headers['Vary'] = 'Accept-Encoding';
        res.writeHead(200, headers);
        if (req.method === 'HEAD') return res.end();
        return res.end(zipped);
      }
      headers['Content-Length'] = buffer.length;
      headers['Vary'] = 'Accept-Encoding';
      res.writeHead(200, headers);
      if (req.method === 'HEAD') return res.end();
      res.end(buffer);
    });
  });
}

function notFound(res) {
  const body = Buffer.from('Not found');
  res.writeHead(404, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Content-Length': body.length,
  });
  res.end(body);
}

/**
 * Resolves a request path to a file inside PUBLIC_DIR.
 * Returns null when the path escapes the root.
 */
function resolveStaticPath(urlPath) {
  const clean = decodeURIComponent(urlPath.split('?')[0]);
  const normalized = path.normalize(clean).replace(/^(\.\.[/\\])+/, '');
  const filePath = path.join(PUBLIC_DIR, normalized);
  if (!filePath.startsWith(PUBLIC_DIR)) return null;
  return filePath;
}

function handleStatic(req, res, urlPath) {
  const filePath = resolveStaticPath(urlPath);
  if (!filePath) return notFound(res);

  fs.stat(filePath, (err, stat) => {
    // Directory request → its index.html.
    if (!err && stat.isDirectory()) {
      return sendFile(req, res, path.join(filePath, 'index.html'),
        { spaFallback: true });
    }
    if (!err && stat.isFile()) {
      return sendFile(req, res, filePath);
    }

    // Missing file. Deep links (no extension) are Flutter routes and must
    // boot the app; a missing asset should stay a 404 so build mistakes are
    // visible instead of silently returning HTML.
    const looksLikeAsset = path.extname(filePath) !== '';
    if (looksLikeAsset) return notFound(res);
    return sendFile(req, res, path.join(PUBLIC_DIR, 'index.html'),
      { spaFallback: false });
  });
}

// ── API proxy ────────────────────────────────────────────────────────

const HOP_BY_HOP = new Set([
  'host', 'connection', 'content-length', 'transfer-encoding', 'keep-alive',
  'upgrade', 'proxy-authorization', 'proxy-authenticate', 'te', 'trailer',
  'origin', 'referer',
]);

function proxyApi(req, res) {
  // Rebuild the upstream URL and force the store credentials server-side so
  // the deployed client never has to carry the real key.
  const incoming = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  incoming.searchParams.set('apiKey', API_KEY);
  incoming.searchParams.set('storeId', STORE_ID);

  const headers = {};
  for (const [key, value] of Object.entries(req.headers)) {
    if (HOP_BY_HOP.has(key.toLowerCase())) continue;
    headers[key] = value;
  }
  headers['Host'] = UPSTREAM_HOST;
  headers['X-Api-Key'] = API_KEY;
  // Ask for identity so we can hand the body straight back without having to
  // undo upstream compression.
  headers['Accept-Encoding'] = 'identity';

  const transport = UPSTREAM_SCHEME === 'http' ? http : https;
  const options = {
    protocol: `${UPSTREAM_SCHEME}:`,
    hostname: UPSTREAM_HOST,
    port: UPSTREAM_PORT,
    path: `${incoming.pathname}${incoming.search}`,
    method: req.method,
    headers,
    timeout: 30000,
  };

  const started = Date.now();
  const proxyReq = transport.request(options, (proxyRes) => {
    const responseHeaders = {};
    for (const [key, value] of Object.entries(proxyRes.headers)) {
      const lower = key.toLowerCase();
      // Drop upstream CORS/encoding headers; we set our own.
      if (lower.startsWith('access-control-') ||
          lower === 'content-encoding' ||
          lower === 'transfer-encoding') {
        continue;
      }
      responseHeaders[key] = value;
    }

    res.writeHead(proxyRes.statusCode || 502, responseHeaders);
    proxyRes.pipe(res);

    proxyRes.on('end', () => {
      log(`PROXY ${req.method} ${incoming.pathname}` +
        `${incoming.search.replace(/apiKey=[^&]*/, 'apiKey=***')} ` +
        `→ ${proxyRes.statusCode} (${Date.now() - started}ms)`);
    });
  });

  proxyReq.on('timeout', () => {
    proxyReq.destroy(new Error('Upstream timeout'));
  });

  proxyReq.on('error', (error) => {
    log(`PROXY ERROR ${req.method} ${incoming.pathname}: ${error.message}`);
    if (res.headersSent) return res.end();
    sendJson(res, 502, {
      Success: false,
      Message: `Upstream unreachable: ${error.message}`,
      Data: null,
    });
  });

  req.pipe(proxyReq);
}

// ── Health check ─────────────────────────────────────────────────────

function handleHealth(res) {
  const indexPath = path.join(PUBLIC_DIR, 'index.html');
  const hasBuild = fs.existsSync(indexPath);
  sendJson(res, hasBuild ? 200 : 503, {
    status: hasBuild ? 'ok' : 'degraded',
    service: 'swift-fleet',
    version: VERSION,
    uptimeSeconds: Math.round((Date.now() - STARTED_AT) / 1000),
    flutterBuildPresent: hasBuild,
    publicDir: PUBLIC_DIR,
    upstream: `${UPSTREAM_SCHEME}://${UPSTREAM_HOST}`,
    storeId: STORE_ID,
    apiKeyConfigured: Boolean(API_KEY),
    note: hasBuild
      ? undefined
      : 'Run `npm run build:web` to compile the Flutter app into public/.',
  });
}

// ── Router ───────────────────────────────────────────────────────────

const server = http.createServer((req, res) => {
  applyCors(res);

  // Preflight.
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  const urlPath = (req.url || '/').split('?')[0];

  if (urlPath === '/health' || urlPath === '/healthz') {
    return handleHealth(res);
  }

  if (urlPath.startsWith(API_PREFIX)) {
    return proxyApi(req, res);
  }

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return sendJson(res, 405, {
      Success: false,
      Message: `${req.method} not allowed`,
    });
  }

  return handleStatic(req, res, urlPath);
});

server.on('clientError', (err, socket) => {
  if (socket.writable) socket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
});

server.listen(PORT, '0.0.0.0', () => {
  log('🚀 Swift Fleet server listening on port', PORT);
  log(`   static : ${PUBLIC_DIR}`);
  log(`   api    : /api/* → ${UPSTREAM_SCHEME}://${UPSTREAM_HOST}`);
  log(`   health : /health`);
  log(`   store  : ${STORE_ID}`);
  log(`   apiKey : ${API_KEY.slice(0, 8)}…${API_KEY.slice(-4)}`);
  if (!fs.existsSync(path.join(PUBLIC_DIR, 'index.html'))) {
    log('   ⚠️  public/index.html missing — run `npm run build:web`');
  }
});

// Render sends SIGTERM on redeploy; close cleanly so requests finish.
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    log(`Received ${signal}, shutting down`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 5000).unref();
  });
}
