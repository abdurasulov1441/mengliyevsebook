'use strict';

const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const multer = require('multer');
const config = require('./config');
const { HttpError } = require('./util');

for (const d of [config.publicDir, config.privateDir, config.tmpDir]) fs.mkdirSync(d, { recursive: true });

const IMAGE_EXT = new Set(['jpg', 'jpeg', 'png', 'webp', 'gif']);
const BOOK_EXT = new Set(['docx', 'doc', 'rtf', 'odt', 'epub', 'txt']);

const upload = multer({
  storage: multer.diskStorage({
    destination: config.tmpDir,
    filename: (_req, file, cb) => cb(null, crypto.randomUUID() + path.extname(file.originalname || '').toLowerCase()),
  }),
  limits: { fileSize: config.uploads.maxBookMb * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').slice(1).toLowerCase();
    if (file.fieldname === 'file') {
      return BOOK_EXT.has(ext) ? cb(null, true) : cb(new HttpError(400, `Kitob fayli formati qo'llab-quvvatlanmaydi (.${ext}). Ruxsat: .docx, .doc, .epub, .txt, .rtf, .odt`));
    }
    if (IMAGE_EXT.has(ext) || /^image\//.test(file.mimetype)) return cb(null, true);
    cb(new HttpError(400, `Rasm formati noto'g'ri (.${ext})`));
  },
});

// Multer files are written to tmp/ first; move them where they belong.
async function moveUpload(file, subdir, isPublic = true) {
  if (!file) return null;
  if (file.fieldname !== 'file' && file.size > config.uploads.maxImageMb * 1024 * 1024) {
    await fsp.rm(file.path, { force: true });
    throw new HttpError(400, `Rasm hajmi ${config.uploads.maxImageMb} MB dan oshmasligi kerak`);
  }
  const base = isPublic ? config.publicDir : config.privateDir;
  const dir = path.join(base, subdir);
  await fsp.mkdir(dir, { recursive: true });
  let ext = path.extname(file.originalname || '').toLowerCase() || '.bin';
  if (ext === '.jpeg') ext = '.jpg';
  const name = crypto.randomUUID() + ext;
  await fsp.rename(file.path, path.join(dir, name)).catch(async () => {
    await fsp.copyFile(file.path, path.join(dir, name));
    await fsp.rm(file.path, { force: true });
  });
  return `/${subdir}/${name}`.replace(/\\/g, '/');
}

// Public files are referenced as "/covers/x.jpg" and served at /_files/...
async function removePublic(rel) {
  if (!rel) return;
  const p = path.join(config.publicDir, rel.replace(/^\/?_files/, ''));
  if (p.startsWith(config.publicDir)) await fsp.rm(p, { force: true }).catch(() => {});
}

async function cleanupTmp(files) {
  for (const f of Object.values(files || {}).flat()) if (f && f.path) await fsp.rm(f.path, { force: true }).catch(() => {});
}

const bookDir = (id) => path.join(config.privateDir, 'books', String(id));
const packageDir = (id) => path.join(bookDir(id), 'package');

module.exports = { upload, moveUpload, removePublic, cleanupTmp, bookDir, packageDir };
