'use strict';

const crypto = require('crypto');

let sharp = null;
try {
  sharp = require('sharp');
} catch {
  sharp = null;
}

const MAX_WIDTH = 1400;
const BROWSER_TYPES = new Set(['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml']);
const EXT = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/gif': 'gif', 'image/webp': 'webp', 'image/svg+xml': 'svg' };

// Collects images for one book: de-duplicates, shrinks huge scans and
// converts formats phones cannot show (TIFF/BMP) when sharp can read them.
class ImageStore {
  constructor() {
    this.files = new Map(); // name -> { buffer, type }
    this.byHash = new Map();
    this.counter = 0;
    this.skipped = 0;
  }

  async add(buffer, contentType) {
    const hash = crypto.createHash('sha1').update(buffer).digest('hex');
    if (this.byHash.has(hash)) return this.byHash.get(hash);
    const optimized = await optimize(buffer, (contentType || '').toLowerCase());
    if (!optimized) {
      this.skipped++;
      return null;
    }
    const name = `images/img-${String(++this.counter).padStart(3, '0')}.${EXT[optimized.type]}`;
    this.files.set(name, optimized);
    this.byHash.set(hash, name);
    return name;
  }

  async addNamed(name, buffer, contentType) {
    const optimized = (await optimize(buffer, contentType)) || { buffer, type: contentType };
    const finalName = name.replace(/\.[a-z0-9]+$/i, '') + '.' + (EXT[optimized.type] || 'jpg');
    this.files.set(finalName, optimized);
    return finalName;
  }
}

async function optimize(buffer, type) {
  const result = await optimizeInner(buffer, type);
  if (result && sharp && !result.width && result.type !== 'image/svg+xml') {
    try {
      const m = await sharp(result.buffer, { failOn: 'none' }).metadata();
      result.width = m.width;
      result.height = m.height;
    } catch {
      /* unknown size is fine */
    }
  }
  return result;
}

async function optimizeInner(buffer, type) {
  if (type === 'image/svg+xml' || type === 'image/gif') return { buffer, type };
  if (!sharp) return BROWSER_TYPES.has(type) ? { buffer, type } : null;
  try {
    const img = sharp(buffer, { failOn: 'none' });
    const meta = await img.metadata();
    const needsResize = meta.width && meta.width > MAX_WIDTH;
    const browserOk = BROWSER_TYPES.has(type);
    if (!needsResize && browserOk && buffer.length < 400 * 1024) return { buffer, type };
    let pipeline = sharp(buffer, { failOn: 'none' }).rotate();
    if (needsResize) pipeline = pipeline.resize({ width: MAX_WIDTH, withoutEnlargement: true });
    if (meta.hasAlpha) {
      const out = await pipeline.png({ compressionLevel: 9, palette: true, quality: 85 }).toBuffer();
      return { buffer: out.length < buffer.length || !browserOk || needsResize ? out : buffer, type: 'image/png' };
    }
    const out = await pipeline.flatten({ background: '#ffffff' }).jpeg({ quality: 82, mozjpeg: true }).toBuffer();
    if (browserOk && !needsResize && out.length >= buffer.length) return { buffer, type };
    return { buffer: out, type: 'image/jpeg' };
  } catch {
    // WMF/EMF and other vector formats from Word: browsers cannot show them.
    return BROWSER_TYPES.has(type) ? { buffer, type } : null;
  }
}

async function makeCover(buffer) {
  if (!sharp) return { buffer, type: 'image/jpeg' };
  const out = await sharp(buffer, { failOn: 'none' })
    .rotate()
    .resize({ width: 800, height: 1200, fit: 'inside', withoutEnlargement: true })
    .flatten({ background: '#ffffff' })
    .jpeg({ quality: 85, mozjpeg: true })
    .toBuffer();
  return { buffer: out, type: 'image/jpeg' };
}

module.exports = { ImageStore, makeCover, hasSharp: () => !!sharp };
