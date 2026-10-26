'use strict';

// Author cabinet ("Studio"): become an author, upload books for moderation,
// see sales, earnings and monthly payouts.

const fsp = require('fs/promises');
const path = require('path');
const express = require('express');
const { q } = require('../db');
const { HttpError, wrap, toInt, toBool } = require('../util');
const { requireAuth } = require('../auth');
const { upload, moveUpload, removePublic, cleanupTmp, bookDir } = require('../storage');
const { slugify } = require('../converter/util');
const { settings, authorBalance, notify, period } = require('../services/platform');
const jobs = require('../jobs');
const S = require('../serializers');

const router = express.Router();

function profileOf(userId) {
  return q.get('SELECT * FROM author_profiles WHERE user_id = ?', userId);
}

function requireAuthor(req, _res, next) {
  const p = profileOf(req.user.id);
  if (!p) return next(new HttpError(403, "Avval muallif profilini to'ldiring"));
  if (p.status !== 'active') return next(new HttpError(403, 'Muallif hisobi bloklangan'));
  req.author = p;
  next();
}

function cardOr400(raw, required) {
  const digits = String(raw || '').replace(/\D/g, '');
  if (!digits && !required) return '';
  if (!/^\d{16}$/.test(digits)) throw new HttpError(400, "Karta raqami 16 ta raqamdan iborat bo'lishi kerak (Uzcard/Humo)");
  return digits.replace(/(\d{4})(?=\d)/g, '$1 ');
}

// ---------------------------------------------------------------- profile
router.get('/studio/profile', requireAuth, (req, res) => {
  const p = profileOf(req.user.id);
  res.json({ profile: S.authorProfile(p, { full: true }), commission_percent: settings().commission_percent, payout_min: settings().payout_min });
});

/** Become an author / update the profile (multipart: photo). */
router.put('/studio/profile', requireAuth, upload.fields([{ name: 'photo', maxCount: 1 }]), wrap(async (req, res) => {
  try {
    const existing = profileOf(req.user.id);
    const name = String(req.body.display_name ?? existing?.display_name ?? req.user.name ?? '').trim().slice(0, 120);
    if (!name) throw new HttpError(400, 'Muallif ismini kiriting');
    const bio = String(req.body.bio ?? existing?.bio ?? '').trim().slice(0, 3000);
    const card = req.body.card_number !== undefined ? cardOr400(req.body.card_number, false) : existing?.card_number || '';
    const holder = String(req.body.card_holder ?? existing?.card_holder ?? '').trim().toUpperCase().slice(0, 80);
    let photo = existing?.photo || null;
    const file = req.files && req.files.photo && req.files.photo[0];
    if (file) {
      photo = await moveUpload(file, 'authors');
      if (existing?.photo) await removePublic(existing.photo);
    }
    // Changing the card needs a new check before money is sent to it.
    const cardChanged = existing && (existing.card_number !== card || existing.card_holder !== holder);
    if (!existing) {
      if (!toBool(req.body.accept_terms)) throw new HttpError(400, 'Muallif shartlarini qabul qiling');
      q.run('INSERT INTO author_profiles (user_id, display_name, bio, photo, card_number, card_holder) VALUES (?, ?, ?, ?, ?, ?)', req.user.id, name, bio, photo, card, holder);
      notify(req.user.id, 'author', "Muallif profili yaratildi", "Endi kitob yuklashingiz mumkin. Har bir kitob moderatsiyadan o'tadi.");
    } else {
      q.run(
        "UPDATE author_profiles SET display_name = ?, bio = ?, photo = ?, card_number = ?, card_holder = ?, card_verified = CASE WHEN ? THEN 0 ELSE card_verified END, updated_at = datetime('now') WHERE user_id = ?",
        name, bio, photo, card, holder, cardChanged ? 1 : 0, req.user.id
      );
    }
    res.json({ profile: S.authorProfile(profileOf(req.user.id), { full: true }) });
  } finally {
    await cleanupTmp(req.files);
  }
}));

// ---------------------------------------------------------------- dashboard
router.get('/studio/dashboard', requireAuth, requireAuthor, (req, res) => {
  const uid = req.user.id;
  const books = q.get(
    `SELECT COUNT(*) AS total,
            SUM(status = 'approved') AS approved, SUM(status = 'pending') AS pending,
            SUM(status = 'rejected') AS rejected, COALESCE(SUM(sales_count), 0) AS sales
     FROM books WHERE owner_user_id = ?`,
    uid
  );
  // Last 12 months of author income.
  const months = q.all('SELECT period, SUM(author_amount) AS amount, SUM(CASE WHEN author_amount > 0 THEN 1 ELSE -1 END) AS sales FROM earnings WHERE author_user_id = ? GROUP BY period ORDER BY period DESC LIMIT 12', uid);
  const top = q.all("SELECT id, title, sales_count, rating_avg, rating_count, price, is_free FROM books WHERE owner_user_id = ? AND status = 'approved' ORDER BY sales_count DESC LIMIT 5", uid);
  const readers = q.get('SELECT COUNT(DISTINCT r.user_id) AS n FROM reading r JOIN books b ON b.id = r.book_id WHERE b.owner_user_id = ?', uid).n;
  res.json({
    profile: S.authorProfile(req.author, { full: true }),
    balance: authorBalance(uid),
    commission_percent: settings().commission_percent,
    payout_min: settings().payout_min,
    books: { total: books.total || 0, approved: books.approved || 0, pending: books.pending || 0, rejected: books.rejected || 0, sales: books.sales || 0 },
    readers,
    months: months.reverse(),
    top_books: top,
  });
});

router.get('/studio/earnings', requireAuth, requireAuthor, (req, res) => {
  const rows = q.all(
    `SELECT e.*, b.title AS book_title FROM earnings e LEFT JOIN books b ON b.id = e.book_id
     WHERE e.author_user_id = ? ORDER BY e.id DESC LIMIT 200`,
    req.user.id
  );
  res.json({ earnings: rows, balance: authorBalance(req.user.id) });
});

router.get('/studio/payouts', requireAuth, requireAuthor, (req, res) => {
  const rows = q.all('SELECT * FROM payouts WHERE author_user_id = ? ORDER BY id DESC', req.user.id);
  res.json({ payouts: rows.map(S.payout), balance: authorBalance(req.user.id), card_verified: !!req.author.card_verified });
});

// ---------------------------------------------------------------- books
function myBook(req) {
  const row = q.get(`${S.BOOK_SELECT} WHERE b.id = ? AND b.owner_user_id = ?`, toInt(req.params.id), req.user.id);
  if (!row) throw new HttpError(404, 'Kitob topilmadi');
  return row;
}

router.get('/studio/books', requireAuth, requireAuthor, (req, res) => {
  const rows = q.all(`${S.BOOK_SELECT} WHERE b.owner_user_id = ? ORDER BY b.updated_at DESC`, req.user.id);
  res.json({ books: rows.map((r) => S.book(r, { owner: true })) });
});

router.get('/studio/books/:id', requireAuth, requireAuthor, (req, res) => {
  const row = myBook(req);
  const monthly = q.all('SELECT period, COUNT(*) AS sales, SUM(author_amount) AS amount FROM earnings WHERE book_id = ? AND author_amount > 0 GROUP BY period ORDER BY period DESC LIMIT 12', row.id);
  res.json(S.book(row, { owner: true, fields: { monthly: monthly.reverse() } }));
});

function fieldsFrom(body, existing) {
  const title = String(body.title ?? existing?.title ?? '').trim().slice(0, 300);
  const isFree = body.is_free !== undefined ? toBool(body.is_free) : existing ? !!existing.is_free : false;
  const price = isFree ? 0 : Math.round(Number(body.price ?? existing?.price ?? 0));
  if (!isFree && (price < 1000 || price > 10000000)) throw new HttpError(400, "Narx 1 000 dan 10 000 000 so'mgacha bo'lishi kerak");
  const categoryId = body.category_id !== undefined && body.category_id !== '' ? toInt(body.category_id) || null : existing?.category_id ?? null;
  if (categoryId && !q.get('SELECT id FROM categories WHERE id = ?', categoryId)) throw new HttpError(400, 'Kategoriya topilmadi');
  return {
    title,
    description: String(body.description ?? existing?.description ?? '').trim().slice(0, 10000),
    author_name: String(body.author_name ?? existing?.author_name ?? '').trim().slice(0, 200),
    category_id: categoryId,
    is_free: isFree ? 1 : 0,
    price,
  };
}

async function saveSource(bookId, file) {
  const dir = bookDir(bookId);
  await fsp.mkdir(dir, { recursive: true });
  for (const f of await fsp.readdir(dir)) if (f.startsWith('source.')) await fsp.rm(path.join(dir, f), { force: true });
  const name = `source${path.extname(file.originalname || '').toLowerCase()}`;
  await fsp.copyFile(file.path, path.join(dir, name));
  let original = file.originalname || name;
  try {
    const fixed = Buffer.from(original, 'latin1').toString('utf8');
    if (!fixed.includes('�')) original = fixed;
  } catch { /* keep */ }
  return { source_file: name, source_name: original };
}

const bookUpload = upload.fields([{ name: 'cover', maxCount: 1 }, { name: 'file', maxCount: 1 }]);

/** Upload a new book: converted automatically, then waits for moderation. */
router.post('/studio/books', requireAuth, requireAuthor, bookUpload, wrap(async (req, res) => {
  try {
    const file = req.files && req.files.file && req.files.file[0];
    const cover = req.files && req.files.cover && req.files.cover[0];
    if (!file) throw new HttpError(400, 'Kitob faylini tanlang (.docx, .epub, .txt)');
    const f = fieldsFrom(req.body);
    const autoTitle = !f.title;
    if (autoTitle) f.title = path.basename(file.originalname || 'Kitob', path.extname(file.originalname || '')).replace(/[_]+/g, ' ');
    if (!f.author_name) f.author_name = req.author.display_name;
    const photo = await moveUpload(cover, 'covers');
    const r = q.run(
      `INSERT INTO books (title, slug, description, author_name, category_id, is_free, price, photo, owner_user_id, status, submitted_at, auto_title)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', datetime('now'), ?)`,
      f.title, `${slugify(f.title)}-${Date.now().toString(36)}`, f.description, f.author_name, f.category_id, f.is_free, f.price, photo, req.user.id, autoTitle ? 1 : 0
    );
    const id = Number(r.lastInsertRowid);
    const src = await saveSource(id, file);
    q.run('UPDATE books SET source_file = ?, source_name = ? WHERE id = ?', src.source_file, src.source_name, id);
    jobs.enqueue(id);
    res.status(201).json({ message: "Kitob yuklandi. Konvertatsiyadan so'ng moderatorga yuboriladi", book: S.book(myBook({ ...req, params: { id } }), { owner: true }) });
  } finally {
    await cleanupTmp(req.files);
  }
}));

/**
 * Edit. Price/description changes of a published book apply at once; a new
 * file or title sends the book back to moderation.
 */
router.put('/studio/books/:id', requireAuth, requireAuthor, bookUpload, wrap(async (req, res) => {
  try {
    const existing = myBook(req);
    const f = fieldsFrom(req.body, existing);
    if (!f.title) throw new HttpError(400, 'Kitob nomini kiriting');
    const file = req.files && req.files.file && req.files.file[0];
    const cover = req.files && req.files.cover && req.files.cover[0];
    let photo = existing.photo;
    if (cover) {
      photo = await moveUpload(cover, 'covers');
      await removePublic(existing.photo);
    }
    const needsReview = !!file || f.title !== existing.title || existing.status === 'rejected';
    const status = needsReview && existing.status !== 'draft' ? 'pending' : existing.status;
    q.run(
      `UPDATE books SET title = ?, description = ?, author_name = ?, category_id = ?, is_free = ?, price = ?, photo = ?, status = ?,
        submitted_at = CASE WHEN ? THEN datetime('now') ELSE submitted_at END, rejection_reason = CASE WHEN ? THEN NULL ELSE rejection_reason END,
        auto_title = 0, updated_at = datetime('now') WHERE id = ?`,
      f.title, f.description, f.author_name || req.author.display_name, f.category_id, f.is_free, f.price, photo, status, needsReview ? 1 : 0, needsReview ? 1 : 0, existing.id
    );
    if (file) {
      const src = await saveSource(existing.id, file);
      q.run('UPDATE books SET source_file = ?, source_name = ? WHERE id = ?', src.source_file, src.source_name, existing.id);
    }
    if (file || cover || f.title !== existing.title) jobs.enqueue(existing.id);
    res.json({ message: needsReview ? 'Saqlandi va qayta moderatsiyaga yuborildi' : 'Saqlandi', book: S.book(myBook(req), { owner: true }) });
  } finally {
    await cleanupTmp(req.files);
  }
}));

router.post('/studio/books/:id/unpublish', requireAuth, requireAuthor, (req, res) => {
  const b = myBook(req);
  if (b.status !== 'approved') throw new HttpError(400, 'Faqat nashr qilingan kitobni yashirish mumkin');
  q.run("UPDATE books SET status = 'unpublished', updated_at = datetime('now') WHERE id = ?", b.id);
  res.json({ message: "Kitob do'kondan yashirildi. Sotib olganlar o'qishda davom etadi", book: S.book(myBook(req), { owner: true }) });
});

router.post('/studio/books/:id/publish', requireAuth, requireAuthor, (req, res) => {
  const b = myBook(req);
  if (b.status !== 'unpublished') throw new HttpError(400, 'Kitob yashirilmagan');
  // It was approved before, so it comes back without a new review.
  q.run("UPDATE books SET status = 'approved', updated_at = datetime('now') WHERE id = ?", b.id);
  res.json({ message: "Kitob yana do'konda", book: S.book(myBook(req), { owner: true }) });
});

router.delete('/studio/books/:id', requireAuth, requireAuthor, wrap(async (req, res) => {
  const b = myBook(req);
  if (q.get('SELECT 1 FROM purchases WHERE book_id = ? LIMIT 1', b.id)) {
    throw new HttpError(400, "Kitobni sotib olganlar bor — o'chirib bo'lmaydi. Uni do'kondan yashirishingiz mumkin");
  }
  q.run('DELETE FROM books WHERE id = ?', b.id);
  await removePublic(b.photo);
  await fsp.rm(bookDir(b.id), { recursive: true, force: true });
  res.json({ message: "Kitob o'chirildi" });
}));

// Read-only helpers for the upload form.
router.get('/studio/rules', (_req, res) => {
  const s = settings();
  res.json({
    commission_percent: s.commission_percent,
    payout_min: s.payout_min,
    payout_schedule: "Har oy boshida o'tgan oy daromadi kartangizga o'tkaziladi",
    formats: ['docx', 'doc', 'epub', 'txt', 'rtf', 'odt'],
    max_mb: require('../config').uploads.maxBookMb,
    period: period(),
  });
});

module.exports = router;
