'use strict';

// Background conversion queue: uploads return immediately, books are turned
// into reader packages one at a time.

const fsp = require('fs/promises');
const path = require('path');
const config = require('./config');
const { q } = require('./db');
const { convertBook, writePackage } = require('./converter');
const { bookDir, packageDir } = require('./storage');
const { notify } = require('./services/platform');

const queue = [];
let running = false;

function enqueue(bookId) {
  q.run("UPDATE books SET conversion_status = 'pending', conversion_error = NULL WHERE id = ?", bookId);
  if (!queue.includes(bookId)) queue.push(bookId);
  setImmediate(tick);
}

async function tick() {
  if (running) return;
  const id = queue.shift();
  if (id === undefined) return;
  running = true;
  try {
    await convertOne(id);
  } finally {
    running = false;
    setImmediate(tick);
  }
}

async function convertOne(id) {
  const book = q.get('SELECT * FROM books WHERE id = ?', id);
  if (!book || !book.source_file) return;
  q.run("UPDATE books SET conversion_status = 'processing' WHERE id = ?", id);
  const started = Date.now();
  try {
    let coverBuffer = null;
    if (book.photo) coverBuffer = await fsp.readFile(path.join(config.publicDir, book.photo)).catch(() => null);
    const src = path.join(bookDir(id), book.source_file);
    const res = await convertBook(
      { path: src, filename: book.source_name || book.source_file },
      { id: String(id), title: book.auto_title ? null : book.title, authors: book.author_name ? book.author_name.split(/\s*,\s*/) : [], coverBuffer }
    );
    // Build next to the live package and swap, so readers never see a half-written book.
    const target = packageDir(id);
    const fresh = target + '.new';
    await writePackage(fresh, res.manifest, res.chapters, res.images, { epub: true, zip: true });
    await fsp.rm(target + '.old', { recursive: true, force: true });
    await fsp.rename(target, target + '.old').catch(() => {});
    await fsp.rename(fresh, target);
    await fsp.rm(target + '.old', { recursive: true, force: true });

    const r = res.report;
    if (book.auto_title && res.manifest.title) {
      q.run('UPDATE books SET title = ?, auto_title = 0 WHERE id = ?', res.manifest.title, id);
    }
    q.run(
      `UPDATE books SET conversion_status = 'ready', conversion_error = NULL, conversion_report = ?, package_version = package_version + 1,
       lang = ?, chapters = ?, words = ?, updated_at = datetime('now') WHERE id = ?`,
      JSON.stringify({ ...r, toc: res.manifest.toc.filter((t) => t.level <= 2).slice(0, 400), stats: res.manifest.stats }),
      res.manifest.lang,
      r.chapters,
      r.words,
      id
    );
    if (book.owner_user_id && book.status === 'pending') {
      notify(book.owner_user_id, 'book', 'Kitob tayyorlandi', `«${res.manifest.title || book.title}» moderatorga yuborildi. Odatda 1 kun ichida ko'rib chiqiladi.`, { book_id: id });
    }
    console.log(`[convert] book ${id} ready: ${r.chapters} chapters, ${r.words} words in ${Date.now() - started} ms`);
  } catch (e) {
    console.error(`[convert] book ${id} failed:`, e);
    q.run("UPDATE books SET conversion_status = 'failed', conversion_error = ?, updated_at = datetime('now') WHERE id = ?", String(e.message || e).slice(0, 2000), id);
    if (book.owner_user_id) notify(book.owner_user_id, 'book', "Faylni o'qib bo'lmadi", `«${book.title}»: ${String(e.message || e).slice(0, 200)}`, { book_id: id });
  }
}

// Books left half-way by a restart are converted again.
function resume() {
  for (const row of q.all("SELECT id FROM books WHERE conversion_status IN ('pending', 'processing') ORDER BY id")) enqueue(row.id);
}

const status = () => ({ running, queued: queue.length });

module.exports = { enqueue, resume, status };
