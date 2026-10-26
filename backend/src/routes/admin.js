'use strict';

// Administration: moderation, authors, orders, payouts, settings, users,
// categories. Every route here requires role_id = 1.

const fsp = require('fs/promises');
const express = require('express');
const { q } = require('../db');
const { HttpError, wrap, paging, toInt, toBool, normalizePhone, hashPassword } = require('../util');
const { requireAdmin, ROLE_ADMIN, ROLE_USER } = require('../auth');
const { removePublic, bookDir } = require('../storage');
const { settings, saveSettings, notify, period, som, generatePayouts, fulfillOrder } = require('../services/platform');
const jobs = require('../jobs');
const S = require('../serializers');

const router = express.Router();
router.use('/admin', requireAdmin);

const one = (sql, ...p) => q.get(sql, ...p).n;

// ---------------------------------------------------------------- dashboard
router.get('/admin/stats', (_req, res) => {
  const month = period();
  const days = q.all(`
    SELECT date(paid_at) AS day, COUNT(*) AS sales, COALESCE(SUM(amount), 0) AS revenue
    FROM orders WHERE status = 'paid' AND paid_at >= date('now', '-29 days') GROUP BY date(paid_at)`);
  const byDay = new Map(days.map((d) => [d.day, d]));
  const series = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date(Date.now() - i * 86400000).toISOString().slice(0, 10);
    const r = byDay.get(d);
    series.push({ day: d, sales: r ? r.sales : 0, revenue: r ? r.revenue : 0 });
  }
  res.json({
    users: one('SELECT COUNT(*) AS n FROM users'),
    users_today: one("SELECT COUNT(*) AS n FROM users WHERE date(created_at) = date('now')"),
    authors: one("SELECT COUNT(*) AS n FROM author_profiles WHERE status = 'active'"),
    authors_unverified: one("SELECT COUNT(*) AS n FROM author_profiles WHERE card_verified = 0 AND card_number <> ''"),
    books_published: one("SELECT COUNT(*) AS n FROM books WHERE status = 'approved' AND conversion_status = 'ready'"),
    moderation_pending: one("SELECT COUNT(*) AS n FROM books WHERE status = 'pending' AND conversion_status = 'ready'"),
    converting: one("SELECT COUNT(*) AS n FROM books WHERE conversion_status IN ('pending', 'processing')"),
    sales_today: one("SELECT COUNT(*) AS n FROM orders WHERE status = 'paid' AND date(paid_at) = date('now')"),
    revenue_month: one("SELECT COALESCE(SUM(amount), 0) AS n FROM orders WHERE status = 'paid' AND strftime('%Y-%m', paid_at) = ?", month),
    commission_month: one('SELECT COALESCE(SUM(platform_amount), 0) AS n FROM earnings WHERE period = ?', month),
    revenue_total: one("SELECT COALESCE(SUM(amount), 0) AS n FROM orders WHERE status = 'paid'"),
    commission_total: one('SELECT COALESCE(SUM(platform_amount), 0) AS n FROM earnings'),
    payouts_pending: one("SELECT COALESCE(SUM(amount), 0) AS n FROM payouts WHERE status = 'pending'"),
    authors_balance: one('SELECT COALESCE(SUM(author_amount), 0) AS n FROM earnings WHERE payout_id IS NULL'),
    sales_series: series,
    top_books: q.all("SELECT id, title, author_name, sales_count, rating_avg FROM books WHERE status = 'approved' ORDER BY sales_count DESC LIMIT 5"),
    settings: settings(),
    queue: jobs.status(),
  });
});

// ---------------------------------------------------------------- moderation & books
router.get('/admin/books', (req, res) => {
  const { limit, offset, page } = paging(req.query, 50, 200);
  const where = [];
  const params = [];
  if (req.query.status) {
    where.push('b.status = ?');
    params.push(String(req.query.status));
  }
  const search = String(req.query.q || '').trim();
  if (search) {
    where.push('(b.title LIKE ? OR b.author_name LIKE ? OR ap.display_name LIKE ?)');
    params.push(...Array(3).fill(`%${search}%`));
  }
  const w = where.length ? `WHERE ${where.join(' AND ')}` : '';
  // Moderation queue: oldest first; otherwise newest first.
  const order = req.query.status === 'pending' ? 'b.submitted_at ASC' : 'b.updated_at DESC';
  const rows = q.all(`${S.BOOK_SELECT} ${w} ORDER BY ${order} LIMIT ? OFFSET ?`, ...params, limit, offset);
  const total = q.get(`SELECT COUNT(*) AS n FROM books b LEFT JOIN author_profiles ap ON ap.user_id = b.owner_user_id ${w}`, ...params).n;
  res.json({ books: rows.map((r) => S.book(r, { admin: true })), total, page, limit });
});

function bookOr404(id) {
  const b = q.get(`${S.BOOK_SELECT} WHERE b.id = ?`, toInt(id));
  if (!b) throw new HttpError(404, 'Kitob topilmadi');
  return b;
}

router.get('/admin/books/:id', (req, res) => {
  const b = bookOr404(req.params.id);
  const owner = b.owner_user_id ? q.get('SELECT ap.*, u.phone_number FROM author_profiles ap JOIN users u ON u.id = ap.user_id WHERE ap.user_id = ?', b.owner_user_id) : null;
  res.json(S.book(b, { admin: true, fields: { owner_profile: S.authorProfile(owner, { full: true }) } }));
});

router.post('/admin/books/:id/approve', (req, res) => {
  const b = bookOr404(req.params.id);
  if (b.conversion_status !== 'ready') throw new HttpError(409, 'Kitob hali konvertatsiya qilinmagan');
  q.run(
    "UPDATE books SET status = 'approved', rejection_reason = NULL, reviewed_at = datetime('now'), reviewed_by = ?, published_at = COALESCE(published_at, datetime('now')), updated_at = datetime('now') WHERE id = ?",
    req.user.id, b.id
  );
  notify(b.owner_user_id, 'moderation', 'Kitobingiz nashr qilindi 🎉', `«${b.title}» moderatsiyadan o'tdi va do'konda paydo bo'ldi.`, { book_id: b.id });
  res.json({ message: 'Kitob nashr qilindi', book: S.book(bookOr404(b.id), { admin: true }) });
});

router.post('/admin/books/:id/reject', (req, res) => {
  const b = bookOr404(req.params.id);
  const reason = String(req.body.reason || '').trim().slice(0, 1000);
  if (!reason) throw new HttpError(400, 'Rad etish sababini yozing — muallif uni ko‘radi');
  q.run("UPDATE books SET status = 'rejected', rejection_reason = ?, reviewed_at = datetime('now'), reviewed_by = ?, updated_at = datetime('now') WHERE id = ?", reason, req.user.id, b.id);
  notify(b.owner_user_id, 'moderation', 'Kitob rad etildi', `«${b.title}»: ${reason}`, { book_id: b.id });
  res.json({ message: 'Kitob rad etildi', book: S.book(bookOr404(b.id), { admin: true }) });
});

router.post('/admin/books/:id/unpublish', (req, res) => {
  const b = bookOr404(req.params.id);
  const reason = String(req.body.reason || '').trim().slice(0, 1000);
  q.run("UPDATE books SET status = 'unpublished', rejection_reason = ?, updated_at = datetime('now') WHERE id = ?", reason || null, b.id);
  notify(b.owner_user_id, 'moderation', "Kitob do'kondan olindi", `«${b.title}»${reason ? ': ' + reason : ''}`, { book_id: b.id });
  res.json({ message: "Kitob do'kondan olindi", book: S.book(bookOr404(b.id), { admin: true }) });
});

router.put('/admin/books/:id', (req, res) => {
  const b = bookOr404(req.params.id);
  const isFree = req.body.is_free !== undefined ? toBool(req.body.is_free) : !!b.is_free;
  const price = isFree ? 0 : Math.max(0, toInt(req.body.price ?? b.price));
  const categoryId = req.body.category_id !== undefined ? toInt(req.body.category_id) || null : b.category_id;
  q.run("UPDATE books SET is_free = ?, price = ?, category_id = ?, updated_at = datetime('now') WHERE id = ?", isFree ? 1 : 0, price, categoryId, b.id);
  res.json({ book: S.book(bookOr404(b.id), { admin: true }) });
});

router.post('/admin/books/:id/reconvert', (req, res) => {
  const b = bookOr404(req.params.id);
  if (!b.source_file) throw new HttpError(400, 'Manba fayl yo‘q');
  jobs.enqueue(b.id);
  res.json({ message: 'Qayta konvertatsiya boshlandi' });
});

router.delete('/admin/books/:id', wrap(async (req, res) => {
  const b = bookOr404(req.params.id);
  q.run('DELETE FROM books WHERE id = ?', b.id);
  await removePublic(b.photo);
  await fsp.rm(bookDir(b.id), { recursive: true, force: true });
  res.json({ message: "Kitob o'chirildi" });
}));

// Give a book to a user for free (support, gifts).
router.post('/admin/books/:id/grant', (req, res) => {
  const b = bookOr404(req.params.id);
  const phone = normalizePhone(req.body.phone);
  const u = phone ? q.get('SELECT id FROM users WHERE phone_number = ?', phone) : q.get('SELECT id FROM users WHERE id = ?', toInt(req.body.user_id));
  if (!u) throw new HttpError(404, 'Foydalanuvchi topilmadi');
  q.run("INSERT INTO purchases (user_id, book_id, source) VALUES (?, ?, 'admin') ON CONFLICT DO NOTHING", u.id, b.id);
  notify(u.id, 'gift', "Sizga kitob sovg'a qilindi", `«${b.title}» kutubxonangizda`, { book_id: b.id });
  res.json({ message: 'Kitob berildi' });
});

// ---------------------------------------------------------------- authors
router.get('/admin/authors', (req, res) => {
  const where = [];
  const params = [];
  if (req.query.unverified) where.push("ap.card_verified = 0 AND ap.card_number <> ''");
  const search = String(req.query.q || '').trim();
  if (search) {
    where.push('(ap.display_name LIKE ? OR u.phone_number LIKE ?)');
    params.push(`%${search}%`, `%${search.replace(/\D/g, '') || search}%`);
  }
  const w = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const rows = q.all(
    `SELECT ap.*, u.phone_number,
            (SELECT COUNT(*) FROM books b WHERE b.owner_user_id = ap.user_id) AS books_count,
            (SELECT COALESCE(SUM(author_amount), 0) FROM earnings e WHERE e.author_user_id = ap.user_id AND e.payout_id IS NULL) AS balance,
            (SELECT COALESCE(SUM(author_amount), 0) FROM earnings e WHERE e.author_user_id = ap.user_id) AS earned
     FROM author_profiles ap JOIN users u ON u.id = ap.user_id ${w} ORDER BY ap.created_at DESC LIMIT 300`,
    ...params
  );
  res.json({ authors: rows.map((r) => ({ ...S.authorProfile(r, { full: true }), books_count: r.books_count, balance: r.balance, earned: r.earned })) });
});

router.put('/admin/authors/:userId', (req, res) => {
  const a = q.get('SELECT * FROM author_profiles WHERE user_id = ?', toInt(req.params.userId));
  if (!a) throw new HttpError(404, 'Muallif topilmadi');
  const verified = req.body.card_verified !== undefined ? (toBool(req.body.card_verified) ? 1 : 0) : a.card_verified;
  const status = ['active', 'blocked'].includes(req.body.status) ? req.body.status : a.status;
  const note = req.body.admin_note !== undefined ? String(req.body.admin_note).slice(0, 1000) : a.admin_note;
  q.run("UPDATE author_profiles SET card_verified = ?, status = ?, admin_note = ?, updated_at = datetime('now') WHERE user_id = ?", verified, status, note, a.user_id);
  if (verified && !a.card_verified) notify(a.user_id, 'author', 'Karta tasdiqlandi', "Endi har oy daromadingiz kartangizga o'tkaziladi.");
  if (status === 'blocked' && a.status !== 'blocked') {
    q.run("UPDATE books SET status = 'unpublished' WHERE owner_user_id = ? AND status IN ('approved', 'pending')", a.user_id);
    notify(a.user_id, 'author', 'Muallif hisobi bloklandi', note || 'Batafsil: qo‘llab-quvvatlash xizmati');
  }
  res.json({ author: S.authorProfile(q.get('SELECT ap.*, u.phone_number FROM author_profiles ap JOIN users u ON u.id = ap.user_id WHERE ap.user_id = ?', a.user_id), { full: true }) });
});

// ---------------------------------------------------------------- orders
router.get('/admin/orders', (req, res) => {
  const { limit, offset, page } = paging(req.query, 50, 200);
  const status = req.query.status ? String(req.query.status) : 'paid';
  const rows = q.all(
    `SELECT o.*, b.title AS book_title, u.name AS user_name, u.phone_number FROM orders o
     JOIN books b ON b.id = o.book_id JOIN users u ON u.id = o.user_id
     WHERE o.status = ? ORDER BY o.id DESC LIMIT ? OFFSET ?`,
    status, limit, offset
  );
  res.json({ orders: rows.map(S.order), total: one('SELECT COUNT(*) AS n FROM orders WHERE status = ?', status), page, limit });
});

// Mark an order paid by hand (e.g. bank transfer checked by the admin).
router.post('/admin/orders/:id/mark-paid', (req, res) => {
  const order = q.get('SELECT * FROM orders WHERE id = ?', toInt(req.params.id));
  if (!order) throw new HttpError(404, 'Buyurtma topilmadi');
  fulfillOrder(order.id, 'admin');
  res.json({ message: "Buyurtma to'langan deb belgilandi" });
});

// ---------------------------------------------------------------- payouts
router.get('/admin/payouts', (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;
  const rows = q.all(
    `SELECT p.*, ap.display_name AS author_name FROM payouts p LEFT JOIN author_profiles ap ON ap.user_id = p.author_user_id
     ${status ? 'WHERE p.status = ?' : ''} ORDER BY p.status = 'pending' DESC, p.id DESC LIMIT 300`,
    ...(status ? [status] : [])
  );
  // Money waiting for the next payout run, per author.
  const accrued = q.all(
    `SELECT e.author_user_id, ap.display_name AS author_name, ap.card_verified, SUM(e.author_amount) AS amount
     FROM earnings e LEFT JOIN author_profiles ap ON ap.user_id = e.author_user_id
     WHERE e.payout_id IS NULL GROUP BY e.author_user_id HAVING amount > 0 ORDER BY amount DESC`
  );
  res.json({ payouts: rows.map(S.payout), accrued, payout_min: settings().payout_min, last_month: lastMonth() });
});

function lastMonth() {
  const d = new Date();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() - 1);
  return d.toISOString().slice(0, 7);
}

/** Monthly run: create payouts for everything earned up to `period` (default last month). */
router.post('/admin/payouts/generate', (req, res) => {
  const upTo = /^\d{4}-\d{2}$/.test(req.body.period || '') ? req.body.period : lastMonth();
  const result = generatePayouts(upTo);
  res.json({ period: upTo, ...result });
});

router.post('/admin/payouts/:id/mark-paid', (req, res) => {
  const p = q.get('SELECT * FROM payouts WHERE id = ?', toInt(req.params.id));
  if (!p) throw new HttpError(404, "To'lov topilmadi");
  if (p.status === 'paid') throw new HttpError(400, "Allaqachon to'langan");
  const reference = String(req.body.reference || '').slice(0, 200);
  q.run("UPDATE payouts SET status = 'paid', reference = ?, paid_at = datetime('now') WHERE id = ?", reference, p.id);
  notify(p.author_user_id, 'payout', "Daromad o'tkazildi 💸", `${som(p.amount)} kartangizga o'tkazildi (${p.period}).`, { payout_id: p.id });
  res.json({ message: "To'langan deb belgilandi" });
});

// ---------------------------------------------------------------- settings
router.get('/admin/settings', (_req, res) => res.json(settings()));
router.put('/admin/settings', (req, res) => {
  const patch = {};
  for (const k of ['commission_percent', 'payout_min', 'support_phone', 'support_telegram']) if (req.body[k] !== undefined) patch[k] = req.body[k];
  res.json(saveSettings(patch));
});

// ---------------------------------------------------------------- categories
function categoryFields(body) {
  const uz = String(body.name_uz ?? body.name1 ?? '').trim().slice(0, 200);
  if (!uz) throw new HttpError(400, 'Kategoriya nomini kiriting');
  return [uz, String(body.name_ru ?? body.name2 ?? '').trim().slice(0, 200), String(body.name_en ?? body.name3 ?? '').trim().slice(0, 200)];
}
router.post('/admin/categories', (req, res) => {
  const r = q.run('INSERT INTO categories (name_uz, name_ru, name_en) VALUES (?, ?, ?)', ...categoryFields(req.body));
  res.status(201).json(S.category(q.get('SELECT * FROM categories WHERE id = ?', r.lastInsertRowid)));
});
router.put('/admin/categories/:id', (req, res) => {
  const r = q.run('UPDATE categories SET name_uz = ?, name_ru = ?, name_en = ? WHERE id = ?', ...categoryFields(req.body), toInt(req.params.id));
  if (!r.changes) throw new HttpError(404, 'Kategoriya topilmadi');
  res.json(S.category(q.get('SELECT * FROM categories WHERE id = ?', toInt(req.params.id))));
});
router.delete('/admin/categories/:id', (req, res) => {
  q.run('DELETE FROM categories WHERE id = ?', toInt(req.params.id));
  res.json({ ok: true });
});

// ---------------------------------------------------------------- users
router.get('/admin/users', (req, res) => {
  const { limit, offset, page } = paging(req.query, 50, 300);
  const search = String(req.query.q || '').trim();
  const where = search ? 'WHERE u.name LIKE ? OR u.phone_number LIKE ?' : '';
  const params = search ? [`%${search}%`, `%${search.replace(/\D/g, '') || search}%`] : [];
  const rows = q.all(
    `SELECT u.*, (SELECT COUNT(*) FROM purchases p WHERE p.user_id = u.id) AS books_count,
            EXISTS(SELECT 1 FROM author_profiles a WHERE a.user_id = u.id) AS is_author
     FROM users u ${where} ORDER BY u.id DESC LIMIT ? OFFSET ?`,
    ...params, limit, offset
  );
  res.json({ users: rows.map((r) => S.user(r, { books_count: r.books_count, is_author: !!r.is_author })), total: q.get(`SELECT COUNT(*) AS n FROM users u ${where}`, ...params).n, page, limit });
});

router.put('/admin/users/:id', (req, res) => {
  const u = q.get('SELECT * FROM users WHERE id = ?', toInt(req.params.id));
  if (!u) throw new HttpError(404, 'Foydalanuvchi topilmadi');
  const role = req.body.role_id !== undefined ? (toInt(req.body.role_id) === ROLE_ADMIN ? ROLE_ADMIN : ROLE_USER) : u.role_id;
  const blocked = req.body.is_blocked !== undefined ? (toBool(req.body.is_blocked) ? 1 : 0) : u.is_blocked;
  if (u.id === req.user.id && (role !== ROLE_ADMIN || blocked)) throw new HttpError(400, "O'zingizni administratorlikdan chiqara yoki bloklay olmaysiz");
  let hash = u.password_hash;
  if (req.body.password) {
    if (String(req.body.password).length < 8) throw new HttpError(400, 'Parol kamida 8 belgi');
    hash = hashPassword(req.body.password);
  }
  q.run('UPDATE users SET role_id = ?, is_blocked = ?, password_hash = ? WHERE id = ?', role, blocked, hash, u.id);
  if (blocked) q.run('UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?', u.id);
  res.json(S.user(q.get('SELECT * FROM users WHERE id = ?', u.id)));
});

module.exports = router;
