'use strict';

// Public catalog and reading: home, search, book page, reviews, favorites,
// library, free books, sample chapters, protected book files, reading sync.

const fs = require('fs');
const path = require('path');
const express = require('express');
const config = require('../config');
const { q } = require('../db');
const { HttpError, wrap, paging, toInt, toBool, parseJson } = require('../util');
const { optionalAuth, requireAuth, bookReader, signReadToken, ROLE_ADMIN } = require('../auth');
const { packageDir } = require('../storage');
const S = require('../serializers');

const router = express.Router();

const isAdmin = (u) => !!u && u.role_id === ROLE_ADMIN;
const PUBLIC = "b.status = 'approved' AND b.conversion_status = 'ready'";

function getBook(id) {
  const row = q.get(`${S.BOOK_SELECT} WHERE b.id = ?`, toInt(id));
  if (!row) throw new HttpError(404, 'Kitob topilmadi');
  return row;
}

const isPublic = (b) => b.status === 'approved' && b.conversion_status === 'ready';
const ownsBook = (u, b) => !!u && b.owner_user_id === u.id;
const purchaseOf = (uid, bid) => (uid ? q.get('SELECT * FROM purchases WHERE user_id = ? AND book_id = ?', uid, bid) : null);

function canRead(user, book) {
  if (!user || book.conversion_status !== 'ready') return false;
  if (isAdmin(user) || ownsBook(user, book)) return true;
  // Hidden by the author: people who already have it keep reading.
  if (book.status === 'unpublished') return !!purchaseOf(user.id, book.id);
  if (!isPublic(book)) return false;
  return !!book.is_free || !!purchaseOf(user.id, book.id);
}

function assertRead(user, book) {
  if (canRead(user, book)) return;
  if (book.conversion_status !== 'ready') throw new HttpError(409, 'Kitob hali tayyor emas');
  if (!isPublic(book) && !isAdmin(user) && !ownsBook(user, book)) throw new HttpError(404, 'Kitob mavjud emas');
  throw new HttpError(403, "Bu kitobni o'qish uchun avval sotib oling");
}

// Per-user fields for lists and pages.
function viewerFields(user, rows) {
  if (!user || !rows.length) return new Map();
  const ids = rows.map((r) => r.id);
  const marks = ids.map(() => '?').join(',');
  const owned = new Map(q.all(`SELECT book_id, created_at, source FROM purchases WHERE user_id = ? AND book_id IN (${marks})`, user.id, ...ids).map((r) => [r.book_id, r]));
  const fav = new Set(q.all(`SELECT book_id FROM favorites WHERE user_id = ? AND book_id IN (${marks})`, user.id, ...ids).map((r) => r.book_id));
  const reading = new Map(q.all(`SELECT book_id, percent, updated_at FROM reading WHERE user_id = ? AND book_id IN (${marks})`, user.id, ...ids).map((r) => [r.book_id, r]));
  const out = new Map();
  for (const r of rows) {
    const p = owned.get(r.id);
    const rd = reading.get(r.id);
    out.set(r.id, {
      in_library: !!p,
      is_purchased: !!p && p.source !== 'free',
      has_access: canRead(user, r),
      is_favorite: fav.has(r.id),
      is_mine: ownsBook(user, r),
      purchase_date: p ? p.created_at : null,
      progress: rd ? rd.percent : 0,
      last_read_at: rd && rd.updated_at ? new Date(rd.updated_at).toISOString() : null,
    });
  }
  return out;
}

const listOut = (user, rows) => {
  const vf = viewerFields(user, rows);
  return rows.map((r) => S.book(r, { fields: vf.get(r.id) || {} }));
};

const SORTS = {
  new: 'COALESCE(b.published_at, b.created_at) DESC, b.id DESC',
  popular: 'b.sales_count DESC, b.rating_count DESC, b.id DESC',
  rating: 'b.rating_avg DESC, b.rating_count DESC, b.id DESC',
  price_asc: 'b.is_free DESC, b.price ASC, b.id DESC',
  price_desc: 'b.price DESC, b.id DESC',
  title: 'b.title COLLATE NOCASE ASC',
};

// ---------------------------------------------------------------- catalog
router.get('/home', optionalAuth, (req, res) => {
  const pick = (where, order, limit = 12, ...params) => q.all(`${S.BOOK_SELECT} WHERE ${PUBLIC} ${where ? 'AND ' + where : ''} ORDER BY ${order} LIMIT ?`, ...params, limit);
  const sections = [
    { key: 'new', title: 'Yangi kitoblar', books: pick('', SORTS.new) },
    { key: 'popular', title: 'Ommabop', books: pick('b.sales_count > 0', SORTS.popular) },
    { key: 'rating', title: 'Eng yuqori baholangan', books: pick('b.rating_count > 0', SORTS.rating) },
    { key: 'free', title: 'Bepul kitoblar', books: pick('b.is_free = 1', SORTS.new) },
  ].filter((s) => s.books.length);
  const categories = q.all(`SELECT c.*, (SELECT COUNT(*) FROM books b WHERE b.category_id = c.id AND ${PUBLIC}) AS books_count FROM categories c ORDER BY books_count DESC, c.name_uz`);
  const authors = q.all(
    `SELECT ap.*, COUNT(b.id) AS books_count FROM author_profiles ap JOIN books b ON b.owner_user_id = ap.user_id AND ${PUBLIC}
     WHERE ap.status = 'active' GROUP BY ap.user_id ORDER BY SUM(b.sales_count) DESC, books_count DESC LIMIT 12`
  );
  res.json({
    sections: sections.map((s) => ({ key: s.key, title: s.title, books: listOut(req.user, s.books) })),
    categories: categories.map(S.category),
    authors: authors.map((a) => S.authorProfile(a)),
  });
});

router.get('/books', optionalAuth, (req, res) => {
  const { limit, offset, page } = paging(req.query, 30, 100);
  const where = [PUBLIC];
  const params = [];
  if (req.query.category_id) {
    where.push('b.category_id = ?');
    params.push(toInt(req.query.category_id));
  }
  if (req.query.author_user_id) {
    where.push('b.owner_user_id = ?');
    params.push(toInt(req.query.author_user_id));
  }
  if (req.query.is_free !== undefined && req.query.is_free !== '') {
    where.push('b.is_free = ?');
    params.push(toBool(req.query.is_free) ? 1 : 0);
  }
  const search = String(req.query.q || '').trim();
  if (search) {
    where.push('(b.title LIKE ? OR b.author_name LIKE ? OR b.description LIKE ? OR ap.display_name LIKE ?)');
    params.push(...Array(4).fill(`%${search}%`));
  }
  const order = SORTS[req.query.sort] || SORTS.new;
  const w = where.join(' AND ');
  const rows = q.all(`${S.BOOK_SELECT} WHERE ${w} ORDER BY ${order} LIMIT ? OFFSET ?`, ...params, limit, offset);
  const total = q.get(`SELECT COUNT(*) AS n FROM books b LEFT JOIN author_profiles ap ON ap.user_id = b.owner_user_id WHERE ${w}`, ...params).n;
  res.json({ books: listOut(req.user, rows), total, page, limit });
});

router.get('/categories', (_req, res) => {
  const rows = q.all(`SELECT c.*, (SELECT COUNT(*) FROM books b WHERE b.category_id = c.id AND ${PUBLIC}) AS books_count FROM categories c ORDER BY c.name_uz`);
  res.json(rows.map(S.category));
});

router.get('/books/:id(\\d+)', optionalAuth, (req, res) => {
  const row = getBook(req.params.id);
  const mine = ownsBook(req.user, row);
  if (!isPublic(row) && !isAdmin(req.user) && !mine) throw new HttpError(404, 'Kitob topilmadi');
  const report = parseJson(row.conversion_report, {});
  const vf = viewerFields(req.user, [row]).get(row.id) || {};
  const myReview = req.user ? q.get('SELECT r.*, u.name AS user_name FROM reviews r JOIN users u ON u.id = r.user_id WHERE r.user_id = ? AND r.book_id = ?', req.user.id, row.id) : null;
  const more = row.owner_user_id
    ? q.all(`${S.BOOK_SELECT} WHERE ${PUBLIC} AND b.owner_user_id = ? AND b.id <> ? ORDER BY ${SORTS.popular} LIMIT 10`, row.owner_user_id, row.id)
    : [];
  const similar = q.all(`${S.BOOK_SELECT} WHERE ${PUBLIC} AND b.category_id IS ? AND b.id <> ? ORDER BY ${SORTS.popular} LIMIT 10`, row.category_id, row.id);
  const reviews = q.all('SELECT r.*, u.name AS user_name FROM reviews r JOIN users u ON u.id = r.user_id WHERE r.book_id = ? ORDER BY r.updated_at DESC LIMIT 5', row.id);
  res.json(
    S.book(row, {
      owner: mine,
      admin: isAdmin(req.user),
      fields: {
        ...vf,
        toc: (report.toc || []).filter((t) => t.level === 1).map((t) => t.title).slice(0, 60),
        has_preview: isPublic(row),
        my_review: myReview ? S.review(myReview) : null,
        reviews: reviews.map(S.review),
        more_by_author: listOut(req.user, more),
        similar: listOut(req.user, similar),
      },
    })
  );
});

// ---------------------------------------------------------------- library & favorites
router.get('/me/library', requireAuth, (req, res) => {
  const rows = q.all(
    `${S.BOOK_SELECT}
     JOIN purchases p ON p.book_id = b.id AND p.user_id = ?
     LEFT JOIN reading r ON r.book_id = b.id AND r.user_id = ?
     WHERE b.conversion_status = 'ready' AND b.status IN ('approved', 'unpublished')
     ORDER BY COALESCE(r.updated_at, 0) DESC, p.created_at DESC`,
    req.user.id, req.user.id
  );
  res.json({ books: listOut(req.user, rows) });
});

// Free book -> library.
router.post('/books/:id/get', requireAuth, (req, res) => {
  const row = getBook(req.params.id);
  if (!isPublic(row)) throw new HttpError(404, 'Kitob topilmadi');
  if (!row.is_free) throw new HttpError(402, 'Bu kitob pullik');
  q.run("INSERT INTO purchases (user_id, book_id, source) VALUES (?, ?, 'free') ON CONFLICT DO NOTHING", req.user.id, row.id);
  res.json({ ok: true, message: "Kitob kutubxonangizga qo'shildi" });
});

router.delete('/me/library/:id', requireAuth, (req, res) => {
  // Only free books can be removed; bought ones stay forever.
  q.run("DELETE FROM purchases WHERE user_id = ? AND book_id = ? AND source = 'free'", req.user.id, toInt(req.params.id));
  res.json({ ok: true });
});

router.post('/books/:id/favorite', requireAuth, (req, res) => {
  const row = getBook(req.params.id);
  const exists = q.get('SELECT 1 FROM favorites WHERE user_id = ? AND book_id = ?', req.user.id, row.id);
  if (exists) q.run('DELETE FROM favorites WHERE user_id = ? AND book_id = ?', req.user.id, row.id);
  else q.run('INSERT INTO favorites (user_id, book_id) VALUES (?, ?)', req.user.id, row.id);
  res.json({ is_favorite: !exists });
});

router.get('/me/favorites', requireAuth, (req, res) => {
  const rows = q.all(`${S.BOOK_SELECT} JOIN favorites f ON f.book_id = b.id AND f.user_id = ? WHERE ${PUBLIC} ORDER BY f.created_at DESC`, req.user.id);
  res.json({ books: listOut(req.user, rows) });
});

// ---------------------------------------------------------------- reviews
function refreshRating(bookId) {
  const r = q.get('SELECT COUNT(*) AS n, COALESCE(AVG(rating), 0) AS avg FROM reviews WHERE book_id = ?', bookId);
  q.run('UPDATE books SET rating_avg = ?, rating_count = ? WHERE id = ?', r.avg, r.n, bookId);
}

router.get('/books/:id/reviews', (req, res) => {
  const { limit, offset } = paging(req.query, 20, 100);
  const rows = q.all('SELECT r.*, u.name AS user_name FROM reviews r JOIN users u ON u.id = r.user_id WHERE r.book_id = ? ORDER BY r.updated_at DESC LIMIT ? OFFSET ?', toInt(req.params.id), limit, offset);
  const dist = q.all('SELECT rating, COUNT(*) AS n FROM reviews WHERE book_id = ? GROUP BY rating', toInt(req.params.id));
  res.json({ reviews: rows.map(S.review), distribution: Object.fromEntries(dist.map((d) => [d.rating, d.n])) });
});

router.post('/books/:id/reviews', requireAuth, (req, res) => {
  const row = getBook(req.params.id);
  if (!canRead(req.user, row) || ownsBook(req.user, row)) throw new HttpError(403, "Fikr qoldirish uchun kitob kutubxonangizda bo'lishi kerak");
  const rating = toInt(req.body.rating);
  if (rating < 1 || rating > 5) throw new HttpError(400, 'Baho 1 dan 5 gacha');
  const text = String(req.body.text || '').trim().slice(0, 2000);
  q.run(
    `INSERT INTO reviews (user_id, book_id, rating, text) VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id, book_id) DO UPDATE SET rating = excluded.rating, text = excluded.text, updated_at = datetime('now')`,
    req.user.id, row.id, rating, text
  );
  refreshRating(row.id);
  res.json({ ok: true, review: S.review(q.get('SELECT r.*, u.name AS user_name FROM reviews r JOIN users u ON u.id = r.user_id WHERE r.user_id = ? AND r.book_id = ?', req.user.id, row.id)) });
});

router.delete('/books/:id/reviews', requireAuth, (req, res) => {
  q.run('DELETE FROM reviews WHERE user_id = ? AND book_id = ?', req.user.id, toInt(req.params.id));
  refreshRating(toInt(req.params.id));
  res.json({ ok: true });
});

// ---------------------------------------------------------------- authors (public)
router.get('/authors/:userId', optionalAuth, (req, res) => {
  const a = q.get("SELECT * FROM author_profiles WHERE user_id = ? AND status = 'active'", toInt(req.params.userId));
  if (!a) throw new HttpError(404, 'Muallif topilmadi');
  const rows = q.all(`${S.BOOK_SELECT} WHERE ${PUBLIC} AND b.owner_user_id = ? ORDER BY ${SORTS.popular}`, a.user_id);
  const stats = q.get(`SELECT COALESCE(SUM(sales_count), 0) AS sales, COALESCE(SUM(rating_count), 0) AS reviews FROM books b WHERE ${PUBLIC} AND b.owner_user_id = ?`, a.user_id);
  res.json({ ...S.authorProfile(a), books: listOut(req.user, rows), books_count: rows.length, readers: stats.sales, reviews: stats.reviews });
});

// ---------------------------------------------------------------- book files
const sendOpts = { headers: { 'Cache-Control': 'private, no-cache' }, dotfiles: 'deny' };

// Whole package for offline reading in the app (manifest.json, book.js, images/).
router.get('/books/:id/package.zip', bookReader, (req, res) => {
  const row = getBook(req.params.id);
  assertRead(req.user, row);
  const file = path.join(packageDir(row.id), 'package.zip');
  if (!fs.existsSync(file)) throw new HttpError(404, 'Paket topilmadi');
  res.setHeader('X-Package-Version', String(row.package_version));
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

// Sample for everyone: the first chapters (about 15% of the book).
const previewCache = new Map();
router.get('/books/:id/preview.js', (req, res) => {
  const row = getBook(req.params.id);
  if (!isPublic(row)) throw new HttpError(404, 'Kitob topilmadi');
  // Pictures load from a public route; the host is whatever the client used.
  const origin = `${req.protocol}://${req.get('host')}`;
  const key = `${row.id}:${row.package_version}:${origin}`;
  let js = previewCache.get(key);
  if (!js) {
    const src = fs.readFileSync(path.join(packageDir(row.id), 'book.js'), 'utf8');
    const data = JSON.parse(src.slice(src.indexOf('})(') + 3, src.lastIndexOf(');')));
    const total = data.chapters.reduce((a, c) => a + (c.chars || 0), 0) || 1;
    const keep = [];
    let acc = 0;
    let real = 0;
    for (const c of data.chapters) {
      keep.push(c);
      acc += c.chars || 0;
      if (c.kind === 'chapter') real++;
      if ((acc / total >= 0.15 && real >= 1) || real >= 3) break;
    }
    const imgBase = `${origin}/api/books/${row.id}/preview-images/`;
    const chapters = keep.map((c) => ({ ...c, html: c.html.replace(/(<img\b[^>]*?\ssrc=")images\//g, `$1${imgBase}`) }));
    const sample = { ...data, preview: true, cover: data.cover ? imgBase + data.cover.replace(/^images\//, '') : null, chapters, toc: data.toc.filter((t) => t.chapter < keep.length) };
    js = `(window.MBookLoad||function(b){window.MBOOK=b})(${JSON.stringify(sample)});\n`;
    previewCache.set(key, js);
  }
  res.type('application/javascript').set('Cache-Control', 'public, max-age=600').send(js);
});

router.get('/books/:id/preview-images/:name', (req, res) => {
  const row = getBook(req.params.id);
  if (!isPublic(row) || !/^[\w.-]+$/.test(req.params.name)) throw new HttpError(404, 'Topilmadi');
  const full = path.join(packageDir(row.id), 'images', req.params.name);
  if (!fs.existsSync(full)) throw new HttpError(404, 'Topilmadi');
  res.sendFile(full, { headers: { 'Cache-Control': 'public, max-age=86400' } });
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
  if (JSON.stringify([bookmarks, highlights]).length > 3 * 1024 * 1024) throw new HttpError(413, 'Juda katta');
  if (!current) {
    q.run(
      'INSERT INTO reading (user_id, book_id, position, percent, bookmarks, highlights, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      req.user.id, row.id, JSON.stringify(position), percent, JSON.stringify(bookmarks || []), JSON.stringify(highlights || []), updatedAt
    );
  } else if (updatedAt >= current.updated_at) {
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
module.exports.helpers = { getBook, canRead, assertRead, listOut, isPublic };
