#!/usr/bin/env node
'use strict';

// Copies the reader engine into the Flutter app (assets/reader/), so the app
// reads downloaded books offline with exactly the same reader as the web.
//   npm run sync-reader

const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', 'public', 'reader');
const dst = path.join(__dirname, '..', '..', 'assets', 'reader');
fs.mkdirSync(dst, { recursive: true });
for (const f of ['reader.html', 'reader.css', 'reader.js']) {
  fs.copyFileSync(path.join(src, f), path.join(dst, f));
  console.log(`copied ${f} -> ${path.relative(process.cwd(), path.join(dst, f))}`);
}
