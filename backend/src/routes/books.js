'use strict';

const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const express = require('express');
const config = require('../config');
const { q } = require('../db');
const { HttpError, wrap, paging, toInt, toBool, normalizePhone, parseJson } = require('../util');
const { optionalAuth, requireAuth, requireAdmin, bookReader, signReadToken, ROLE_ADMIN } = require('../auth');
const { upload, moveUpload, removePublic, cleanupTmp, bookDir, packageDir } = require('../storage');
const { slugify } = require('../converter/util');
const jobs = require('../jobs');
const S = require('../serializers');

const router = express.Router();

const isAdmin = (u) => !!u && u.role_id === ROLE_ADMIN;

function getBook(id) {
  const row = q.get(`${S.BOOK_SELECT} WHERE b.id = ?`, toInt(id));
  if (!row) throw new HttpError(404, 'Kitob topilmadi');
  return row;
}

function purchaseOf(userId, bookId) {
  return userId ? q.get('SELECT * FROM purchases WHERE user_id = ? AND book_id = ?', userId, bookId) : null;
}

function canRead(user, book) {
  if (!user) return false;
  if (isAdmin(user)) return true;
  if (!book.is_published || book.conversion_status !== 'ready') return false;
  return !!book.is_free || !!purchaseOf(user.id, book.id);
}

function assertRead(user, book) {
  if (isAdmin(user)) {
    if (book.conversion_status !== 'ready') throw new HttpError(409, 'Kitob hali tayyor emas (konvertatsiya)');
    return;
  }
  if (!canRead(user, book)) {
    if (book.conversion_status !== 'ready' || !book.is_published) throw new HttpError(404, 'Kitob mavjud emas');
    throw new HttpError(403, "Bu kitobni o'qish uchun avval sotib oling");
  }
}

function userFields(user, row) {
  if (!user) return {};
  const p = purchaseOf(user.id, row.id);
  const r = q.get('SELECT percent, updated_at FROM reading WHERE user_id = ? AND book_id = ?', user.id, row.id);
  return {
    is_purchased: !!p,
    has_access: canRead(user, row),
    purchase_date: p ? p.created_at : null,
    progress: r ? r.percent : 0,
    last_read_at: r && r.updated_at ? new Date(r.updated_at).toISOString() : null,
  };
}

// ---------------------------------------------------------------- listing
router.get('/books/get-books', optionalAuth, (req, res) => {
  const { limit, offset, page } = paging(req.query, 50, 500);
  const where = [];
  const params = [];
  const admin = isAdmin(req.user);
  if (!admin || !toBool(req.query.all ?? '1')) {
    where.push("b.is_published = 1 AND b.conversion_status = 'ready'");
  }
  if (req.query.is_free !== undefined && req.query.is_free !== '') {
    where.push('b.is_free = ?');
    params.push(toBool(req.query.is_free) ? 1 : 0);
  }
  if (req.query.category_id) {
    where.push('b.category_id = ?');
    params.push(toInt(req.query.category_id));
  }
  if (req.query.author_id) {
    where.push('b.author_id = ?');
    params.push(toInt(req.query.author_id));
  }
  const search = String(req.query.q || '').trim();
  if (search) {
    where.push('(b.title LIKE ? OR b.description LIKE ? OR a.name_uz LIKE ?)');
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  const w = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const rows = q.all(`${S.BOOK_SELECT} ${w} ORDER BY b.created_at DESC, b.id DESC LIMIT ? OFFSET ?`, ...params, limit, offset);
  const total = q.get(`SELECT COUNT(*) AS n FROM books b LEFT JOIN authors a ON a.id = b.author_id ${w}`, ...params).n;
  res.json({ books: rows.map((r) => S.book(r, { withReport: admin, fields: userFields(req.user, r) })), total, page, limit });
});

// "My books": everything the user may read — bought books and free books.
router.get('/books/my-books', requireAuth, (req, res) => {
  const rows = q.all(
    `${S.BOOK_SELECT}
     LEFT JOIN purchases p ON p.book_id = b.id AND p.user_id = ?
     LEFT JOIN reading r ON r.book_id = b.id AND r.user_id = ?
     WHERE b.is_published = 1 AND b.conversion_status = 'ready' AND (p.user_id IS NOT NULL OR b.is_free = 1)
     ORDER BY COALESCE(r.updated_at, 0) DESC, p.created_at DESC, b.created_at DESC`,
    req.user.id, req.user.id
  );
  res.json({ books: rows.map((r) => S.book(r, { fields: userFields(req.user, r) })), total: rows.length });
});

router.get('/books/:id(\\d+)', optionalAuth, (req, res) => {
  const row = getBook(req.params.id);
  const admin = isAdmin(req.user);
  if (!admin && (!row.is_published || row.conversion_status !== 'ready')) throw new HttpError(404, 'Kitob topilmadi');
  const report = parseJson(row.conversion_report, {});
  res.json(S.book(row, { withReport: admin, fields: { ...userFields(req.user, row), toc: (report.toc || []).filter((t) => t.level === 1).map((t) => t.title) } }));
});

// ---------------------------------------------------------------- admin CRUD
function bookFields(body, existing, hasFile) {
  const title = String(body.title ?? existing?.title ?? '').trim().slice(0, 300);
  if (!title && !hasFile) throw new HttpError(400, 'Kitob nomini kiriting');
  const isFree = body.is_free !== undefined ? toBool(body.is_free) : existing ? !!existing.is_free : true;
  const price = isFree ? 0 : Math.max(0, toInt(body.price ?? existing?.price, 0));
  if (!isFree && !price) throw new HttpError(400, "Pullik kitob uchun narxni kiriting");
  const authorId = body.author_id !== undefined && body.author_id !== '' ? toInt(body.author_id) || null : existing?.author_id ?? null;
  const categoryId = body.category_id !== undefined && body.category_id !== '' ? toInt(body.category_id) || null : existing?.category_id ?? null;
  if (authorId && !q.get('SELECT id FROM authors WHERE id = ?', authorId)) throw new HttpError(400, 'Muallif topilmadi');
  if (categoryId && !q.get('SELECT id FROM categories WHERE id = ?', categoryId)) throw new HttpError(400, 'Kategoriya topilmadi');
  return {
    title,
    description: String(body.description ?? existing?.description ?? '').trim().slice(0, 10000),
    author_id: authorId,
    category_id: categoryId,
    is_free: isFree ? 1 : 0,
    price,
    is_published: body.is_published !== undefined ? (toBool(body.is_published) ? 1 : 0) : existing ? existing.is_published : 1,
  };
}

async function saveSource(bookId, file) {
  const dir = bookDir(bookId);
  await fsp.mkdir(dir, { recursive: true });
  const ext = path.extname(file.originalname || '').toLowerCase();
  for (const f of await fsp.readdir(dir)) if (f.startsWith('source.')) await fsp.rm(path.join(dir, f), { force: true });
  const name = `source${ext}`;
  await fsp.copyFile(file.path, path.join(dir, name));
  // Browsers send latin1-decoded names; recover UTF-8 (Cyrillic/Uzbek names).
  let original = file.originalname || name;
  try {
    const fixed = Buffer.from(original, 'latin1').toString('utf8');
    if (!fixed.includes('�')) original = fixed;
  } catch { /* keep as is */ }
  return { source_file: name, source_name: original };
}

const bookUpload = upload.fields([{ name: 'image', maxCount: 1 }, { name: 'file', maxCount: 1 }]);

router.post('/books/create-book', requireAdmin, bookUpload, wrap(async (req, res) => {
  try {
    const image = req.files && req.files.image && req.files.image[0];
    const file = req.files && req.files.file && req.files.file[0];
    const f = bookFields(req.body, null, !!file);
    // No title typed: use the file name for now, the converter reads the real
    // one from the title page.
    const autoTitle = !f.title;
    if (autoTitle) f.title = path.basename(file.originalname || 'Kitob', path.extname(file.originalname || '')).replace(/[_]+/g, ' ');
    const photo = await moveUpload(image, 'covers');
    let slug = slugify(f.title);
    if (q.get('SELECT id FROM books WHERE slug = ?', slug)) slug = `${slug}-${Date.now().toString(36)}`;
    const r = q.run(
      'INSERT INTO books (title, slug, description, author_id, category_id, is_free, price, is_published, photo, auto_title) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      f.title, slug, f.description, f.author_id, f.category_id, f.is_free, f.price, f.is_published, photo, autoTitle ? 1 : 0
    );
    const id = Number(r.lastInsertRowid);
    if (file) {
      const src = await saveSource(id, file);
      q.run('UPDATE books SET source_file = ?, source_name = ? WHERE id = ?', src.source_file, src.source_name, id);
      jobs.enqueue(id);
    }
    res.status(201).json({ message: file ? 'Kitob yaratildi. Konvertatsiya boshlandi' : 'Kitob yaratildi', book: S.book(getBook(id), { withReport: true }) });
  } finally {
    await cleanupTmp(req.files);
  }
}));

router.put('/books/update-book/:id', requireAdmin, bookUpload, wrap(async (req, res) => {
  try {
    const existing = getBook(req.params.id);
    const image = req.files && req.files.image && req.files.image[0];
    const file = req.files && req.files.file && req.files.file[0];
    const f = bookFields(req.body, existing);
    let photo = existing.photo;
    if (image) {
      photo = await moveUpload(image, 'covers');
      await removePublic(existing.photo);
    }
    q.run(
      "UPDATE books SET title = ?, description = ?, author_id = ?, category_id = ?, is_free = ?, price = ?, is_published = ?, photo = ?, auto_title = CASE WHEN title = ? THEN auto_title ELSE 0 END, updated_at = datetime('now') WHERE id = ?",
      f.title, f.description, f.author_id, f.category_id, f.is_free, f.price, f.is_published, photo, f.title, existing.id
    );
    if (file) {
      const src = await saveSource(existing.id, file);
      q.run('UPDATE books SET source_file = ?, source_name = ? WHERE id = ?', src.source_file, src.source_name, existing.id);
    }
    // New file, or a title/author/cover change that shows inside the book.
    const changedInside = file || image || f.title !== existing.title || f.author_id !== existing.author_id;
    if (changedInside && (file || existing.source_file)) jobs.enqueue(existing.id);
    res.json({ message: 'Kitob yangilandi', book: S.book(getBook(existing.id), { withReport: true }) });
  } finally {
    await cleanupTmp(req.files);
  }
}));

router.delete('/books/delete-book/:id', requireAdmin, wrap(async (req, res) => {
  const row = getBook(req.params.id);
  q.run('DELETE FROM books WHERE id = ?', row.id);
  await removePublic(row.photo);
  await fsp.rm(bookDir(row.id), { recursive: true, force: true });
  res.json({ message: "Kitob o'chirildi" });
}));

router.post('/books/:id/reconvert', requireAdmin, (req, res) => {
  const row = getBook(req.params.id);
  if (!row.source_file) throw new HttpError(400, 'Kitob fayli yuklanmagan');
  jobs.enqueue(row.id);
  res.json({ message: 'Konvertatsiya navbatga qo‘yildi', book: S.book(getBook(row.id), { withReport: true }) });
});

router.get('/books/:id/source', requireAdmin, (req, res) => {
  const row = getBook(req.params.id);
  if (!row.source_file) throw new HttpError(404, 'Manba fayl yo‘q');
  res.download(path.join(bookDir(row.id), row.source_file), row.source_name || row.source_file);
});

// Give a book to a user without payment (gift, school licence, support).
router.post('/books/:id/grant', requireAdmin, (req, res) => {
  const row = getBook(req.params.id);
  let userId = toInt(req.body.user_id, 0);
  if (!userId && req.body.phone) {
    const phone = normalizePhone(req.body.phone);
    const u = phone && q.get('SELECT id FROM users WHERE phone_number = ?', phone);
    if (!u) throw new HttpError(404, 'Bu raqamli foydalanuvchi topilmadi');
    userId = u.id;
  }
  if (!q.get('SELECT id FROM users WHERE id = ?', userId)) throw new HttpError(404, 'Foydalanuvchi topilmadi');
  q.run("INSERT INTO purchases (user_id, book_id, source) VALUES (?, ?, 'admin') ON CONFLICT DO NOTHING", userId, row.id);
  res.json({ message: 'Kitob foydalanuvchiga berildi' });
});

router.delete('/books/:id/grant/:userId', requireAdmin, (req, res) => {
  q.run('DELETE FROM purchases WHERE book_id = ? AND user_id = ?', toInt(req.params.id), toInt(req.params.userId));
  res.json({ message: 'Ruxsat olib tashlandi' });
});

router.get('/books/:id/readers', requireAdmin, (req, res) => {
  const rows = q.all(
    `SELECT u.id, u.name, u.phone_number, p.source, p.created_at AS purchased_at, r.percent, r.updated_at
     FROM purchases p JOIN users u ON u.id = p.user_id LEFT JOIN reading r ON r.user_id = p.user_id AND r.book_id = p.book_id
     WHERE p.book_id = ? ORDER BY p.created_at DESC`,
    toInt(req.params.id)
  );
  res.json({ readers: rows });
});

// ---------------------------------------------------------------- content
const sendOpts = { headers: { 'Cache-Control': 'private, no-cache' }, dotfiles: 'deny' };

// Whole package for offline reading in the app (manifest.json, book.js, images/).
router.get('/books/:id/package.zip', bookReader, (req, res) => {
  const row = getBook(req.params.id);
  assertRead(req.user, row);
  const file = path.join(packageDir(row.id), 'package.zip');
  if (!fs.existsSync(file)) throw new HttpError(404, 'Paket topilmadi');
  res.setHeader('X-Package-Version', String(row.package_version));
  res.setHeader('Content-Disposition', `attachment; filename="book-${row.id}-v${row.package_version}.zip"`);
  res.sendFile(file, { ...sendOpts, headers: { ...sendOpts.headers, 'Content-Type': 'application/zip' } });
});

// Single files for the online web reader.
router.get(/^\/books\/(\d+)\/package\/(.+)$/, (req, _res, next) => {
  req.params.id = req.params[0];
  req.params.file = req.params[1];
  next();
}, bookReader, (req, res) => {
  const row = getBook(req.params.id);
  assertRead(req.user, row);
  const base = packageDir(row.id);
  const rel = path.normalize(decodeURIComponent(req.params.file)).replace(/^([/\\])+/, '');
  if (!/^(book\.js|manifest\.json|images[/\\][\w.-]+)$/.test(rel)) throw new HttpError(404, 'Fayl topilmadi');
  const full = path.join(base, rel);
  if (!full.startsWith(base) || !fs.existsSync(full)) throw new HttpError(404, 'Fayl topilmadi');
  res.sendFile(full, rel.startsWith('images') ? { headers: { 'Cache-Control': 'private, max-age=86400' } } : sendOpts);
});

router.get('/books/:id/epub', bookReader, (req, res) => {
  const row = getBook(req.params.id);
  assertRead(req.user, row);
  const file = path.join(packageDir(row.id), 'book.epub');
  if (!fs.existsSync(file)) throw new HttpError(404, 'EPUB topilmadi');
  res.download(file, `${row.slug || 'book'}.epub`);
});

// Link for reading in a browser: /reader/reader.html?remote=<id>&rt=<token>
router.get('/books/:id/read-token', requireAuth, (req, res) => {
  const row = getBook(req.params.id);
  assertRead(req.user, row);
  const token = signReadToken(req.user.id, row.id);
  res.json({ token, reader_url: `${config.publicUrl}/reader/reader.html?remote=${row.id}&rt=${encodeURIComponent(token)}` });
});

// ---------------------------------------------------------------- reading sync
function readingOut(row) {
  if (!row) return { position: null, percent: 0, bookmarks: [], highlights: [], updatedAt: 0 };
  return { position: parseJson(row.position, null), percent: row.percent, bookmarks: parseJson(row.bookmarks, []), highlights: parseJson(row.highlights, []), updatedAt: row.updated_at };
}

router.get('/books/:id/reading', bookReader, (req, res) => {
  const row = getBook(req.params.id);
  assertRead(req.user, row);
  res.json(readingOut(q.get('SELECT * FROM reading WHERE user_id = ? AND book_id = ?', req.user.id, row.id)));
});

function saveReading(req, res) {
  const row = getBook(req.params.id);
  assertRead(req.user, row);
  const b = typeof req.body === 'string' ? parseJson(req.body, {}) : req.body || {};
  const current = q.get('SELECT * FROM reading WHERE user_id = ? AND book_id = ?', req.user.id, row.id);
  const updatedAt = toInt(b.updatedAt, Date.now());
  const bookmarks = Array.isArray(b.bookmarks) ? b.bookmarks.slice(0, 2000) : null;
  const highlights = Array.isArray(b.highlights) ? b.highlights.slice(0, 10000) : null;
  const position = b.position && typeof b.position === 'object' ? { c: toInt(b.position.c), b: toInt(b.position.b), o: toInt(b.position.o) } : null;
  const percent = Math.min(1, Math.max(0, Number(b.percent) || 0));
  const payload = JSON.stringify([bookmarks, highlights]);
  if (payload.length > 3 * 1024 * 1024) throw new HttpError(413, 'Juda katta');
  if (!current) {
    q.run(
      'INSERT INTO reading (user_id, book_id, position, percent, bookmarks, highlights, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      req.user.id, row.id, JSON.stringify(position), percent, JSON.stringify(bookmarks || []), JSON.stringify(highlights || []), updatedAt
    );
  } else if (updatedAt >= current.updated_at) {
    // Position always follows the latest device; annotations only when sent.
    q.run(
      'UPDATE reading SET position = COALESCE(?, position), percent = ?, bookmarks = COALESCE(?, bookmarks), highlights = COALESCE(?, highlights), updated_at = ? WHERE user_id = ? AND book_id = ?',
      position ? JSON.stringify(position) : null, percent, bookmarks ? JSON.stringify(bookmarks) : null, highlights ? JSON.stringify(highlights) : null, updatedAt, req.user.id, row.id
    );
  }
  res.json(readingOut(q.get('SELECT * FROM reading WHERE user_id = ? AND book_id = ?', req.user.id, row.id)));
}

router.put('/books/:id/reading', bookReader, saveReading);
router.post('/books/:id/reading/beacon', express.text({ type: '*/*', limit: '4mb' }), bookReader, saveReading);

module.exports = router;
