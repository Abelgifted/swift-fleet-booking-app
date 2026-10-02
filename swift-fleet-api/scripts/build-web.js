#!/usr/bin/env node
'use strict';

/**
 * Compiles the Flutter web app straight into `swift-fleet-api/public/`, which
 * is the directory `server.js` serves.
 *
 * Cross-platform on purpose (Node + fs only, no shell built-ins) so the same
 * command works on Windows, macOS, Linux and CI.
 *
 *   npm run build:web
 *
 * Flags:
 *   --wasm        also compile the WebAssembly target
 *   --clean-only  empty public/ and exit (no compile)
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const SERVER_DIR = path.resolve(__dirname, '..');
const PROJECT_ROOT = path.resolve(SERVER_DIR, '..');
const PUBLIC_DIR = path.join(SERVER_DIR, 'public');

const args = process.argv.slice(2);
const cleanOnly = args.includes('--clean-only');
const useWasm = args.includes('--wasm');

function log(...parts) {
  console.log('[build:web]', ...parts);
}

function fail(message) {
  console.error(`\n[build:web] ✖ ${message}\n`);
  process.exit(1);
}

function cleanPublic() {
  if (!fs.existsSync(PUBLIC_DIR)) return;

  try {
    fs.rmSync(PUBLIC_DIR, { recursive: true, force: true });
    log('cleared', PUBLIC_DIR);
    return;
  } catch (error) {
    // Some environments intercept recursive deletes (sandboxes, managed
    // shells, antivirus shims) and fail or time out. A stale directory is
    // not worth aborting a build for — move it aside and let Flutter write
    // a fresh one.
    log(`could not remove public/ — ${String(error.message).split('\n')[0]}`);
  }

  const stale = `${PUBLIC_DIR}.stale-${Date.now()}`;
  try {
    fs.renameSync(PUBLIC_DIR, stale);
    log('moved the previous build aside to', stale);
    log('delete that folder once the new build looks good');
  } catch (renameError) {
    // Last resort: build straight over the top. Flutter overwrites its own
    // outputs, so the result is still correct — just with stale extras.
    log(`could not move it aside either — ${String(renameError.message).split('\n')[0]}`);
    log('building over the existing directory instead');
  }
}

// ── Sanity checks ────────────────────────────────────────────────────

if (!fs.existsSync(path.join(PROJECT_ROOT, 'pubspec.yaml'))) {
  fail(`no pubspec.yaml at ${PROJECT_ROOT} — is this the Flutter project root?`);
}

cleanPublic();

if (cleanOnly) {
  fs.mkdirSync(PUBLIC_DIR, { recursive: true });
  log('public/ is empty and ready');
  process.exit(0);
}

// ── Compile ──────────────────────────────────────────────────────────

// `flutter` is a batch file on Windows, so it must go through the shell.
const flutterCmd = process.platform === 'win32' ? 'flutter.bat' : 'flutter';
const flutterArgs = ['build', 'web', '--release', '--output', PUBLIC_DIR];
if (useWasm) flutterArgs.push('--wasm');

log(`project  : ${PROJECT_ROOT}`);
log(`output   : ${PUBLIC_DIR}`);
log(`command  : flutter ${flutterArgs.slice(1).join(' ')}`);
log('this takes a few minutes on a cold build…\n');

const result = spawnSync(flutterCmd, flutterArgs, {
  cwd: PROJECT_ROOT,
  stdio: 'inherit',
  shell: process.platform === 'win32',
});

if (result.error) {
  fail(`could not run Flutter: ${result.error.message}\n` +
    'Is the Flutter SDK on your PATH?');
}
if (result.status !== 0) {
  fail(`flutter build web exited with code ${result.status}`);
}

// ── Verify ───────────────────────────────────────────────────────────

const required = ['index.html', 'main.dart.js', 'flutter_bootstrap.js'];
const missing = required.filter(
  (f) => !fs.existsSync(path.join(PUBLIC_DIR, f)),
);

if (missing.length) {
  fail(`build finished but these are missing from public/: ${missing.join(', ')}`);
}

const indexSize = fs.statSync(path.join(PUBLIC_DIR, 'index.html')).size;
const jsSize = fs.statSync(path.join(PUBLIC_DIR, 'main.dart.js')).size;

log('✔ build complete');
log(`  index.html    ${(indexSize / 1024).toFixed(1)} KB`);
log(`  main.dart.js  ${(jsSize / 1024 / 1024).toFixed(2)} MB`);
log(`  served from   ${PUBLIC_DIR}`);
log('\nNext: `npm start` (or deploy to Render) and open http://localhost:8787');
