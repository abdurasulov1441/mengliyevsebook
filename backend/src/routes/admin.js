'use strict';

const express = require('express');
const { q } = require('../db');
const { HttpError, paging, toInt, toBool, normalizePhone, hashPassword } = require('../util');
const { requireAdmin, ROLE_ADMIN, ROLE_USER } = require('../auth');
const jobs = require('../jobs');
const S = require('../serializers');

const router = express.Router();
router.use('/admin', requireAdmin);

router.get('/admin/stats', (_req, res) => {
  const one = (sql, ...p) => q.get(sql, ...p).n;
  const days = q.all(`
    SELECT date(reviewed_at) AS day, COUNT(*) AS sales, COALESCE(SUM(amount), 0) AS revenue
    FROM payments WHERE status_id = 2 AND reviewed_at >= date('now', '-29 days')
    GROUP BY date(reviewed_at) ORDER BY day`);
  const byDay = new Map(days.map((d) => [d.day, d]));
  const series = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date(Date.now() - i * 86400000).toISOString().slice(0, 10);
    const row = byDay.get(d);
    series.push({ day: d, sales: row ? row.sales : 0, revenue: row ? row.revenue : 0 });
  }
  res.json({
    users: one('SELECT COUNT(*) AS n FROM users WHERE role_id = 2'),
    users_today: one("SELECT COUNT(*) AS n FROM users WHERE role_id = 2 AND date(created_at) = date('now')"),
    books: one('SELECT COUNT(*) AS n FROM books'),
    books_ready: one("SELECT COUNT(*) AS n FROM books WHERE conversion_status = 'ready' AND is_published = 1"),
    books_failed: one("SELECT COUNT(*) AS n FROM books WHERE conversion_status = 'failed'"),
    payments_pending: one('SELECT COUNT(*) AS n FROM payments WHERE status_id = 1'),
    sales_today: one("SELECT COUNT(*) AS n FROM payments WHERE status_id = 2 AND date(reviewed_at) = date('now')"),
    sales_total: one('SELECT COUNT(*) AS n FROM payments WHERE status_id = 2'),
    revenue_total: one('SELECT COALESCE(SUM(amount), 0) AS n FROM payments WHERE status_id = 2'),
    revenue_month: one("SELECT COALESCE(SUM(amount), 0) AS n FROM payments WHERE status_id = 2 AND reviewed_at >= date('now', 'start of month')"),
    active_readers_week: one('SELECT COUNT(DISTINCT user_id) AS n FROM reading WHERE updated_at > ?', Date.now() - 7 * 86400000),
    top_books: q.all(`
      SELECT b.id, b.title, COUNT(p.user_id) AS sold, b.price
      FROM books b JOIN purchases p ON p.book_id = b.id
      GROUP BY b.id ORDER BY sold DESC LIMIT 5`),
    most_read: q.all(`
      SELECT b.id, b.title, COUNT(r.user_id) AS readers, ROUND(AVG(r.percent) * 100) AS avg_percent
      FROM books b JOIN reading r ON r.book_id = b.id
      GROUP BY b.id ORDER BY readers DESC LIMIT 5`),
    sales_series: series,
    queue: jobs.status(),
  });
});

router.get('/admin/users', (req, res) => {
  const { limit, offset, page } = paging(req.query, 50, 500);
  const search = String(req.query.q || '').trim();
  const where = [];
  const params = [];
  if (search) {
    where.push('(u.name LIKE ? OR u.phone_number LIKE ?)');
    params.push(`%${search}%`, `%${search.replace(/\D/g, '') || search}%`);
  }
  if (req.query.role) {
    where.push('u.role_id = ?');
    params.push(toInt(req.query.role));
  }
  const w = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const rows = q.all(
    `SELECT u.*, (SELECT COUNT(*) FROM purchases p WHERE p.user_id = u.id) AS books_count,
            (SELECT MAX(updated_at) FROM reading r WHERE r.user_id = u.id) AS last_read
     FROM users u ${w} ORDER BY u.id DESC LIMIT ? OFFSET ?`,
    ...params, limit, offset
  );
  const total = q.get(`SELECT COUNT(*) AS n FROM users u ${w}`, ...params).n;
  res.json({
    users: rows.map((r) => ({ ...S.user(r), books_count: r.books_count, last_read_at: r.last_read ? new Date(r.last_read).toISOString() : null })),
    total, page, limit,
  });
});

router.get('/admin/users/:id', (req, res) => {
  const u = q.get('SELECT * FROM users WHERE id = ?', toInt(req.params.id));
  if (!u) throw new HttpError(404, 'Foydalanuvchi topilmadi');
  const books = q.all(
    `SELECT b.id, b.title, p.source, p.created_at, r.percent FROM purchases p JOIN books b ON b.id = p.book_id
     LEFT JOIN reading r ON r.book_id = p.book_id AND r.user_id = p.user_id WHERE p.user_id = ? ORDER BY p.created_at DESC`,
    u.id
  );
  res.json({ ...S.user(u), books });
});

router.post('/admin/users', (req, res) => {
  const phone = normalizePhone(req.body.phone || req.body.phone_number);
  if (!phone) throw new HttpError(400, "Telefon raqam noto'g'ri");
  if (q.get('SELECT id FROM users WHERE phone_number = ?', phone)) throw new HttpError(409, 'Bu raqam allaqachon mavjud');
  const role = toInt(req.body.role_id, ROLE_USER) === ROLE_ADMIN ? ROLE_ADMIN : ROLE_USER;
  const pass = String(req.body.password || '');
  if (role === ROLE_ADMIN && pass.length < 8) throw new HttpError(400, "Administrator uchun kamida 8 belgili parol kiriting");
  const r = q.run('INSERT INTO users (name, phone_number, role_id, password_hash, is_verified) VALUES (?, ?, ?, ?, 1)', String(req.body.name || '').trim(), phone, role, pass ? hashPassword(pass) : null);
  res.status(201).json(S.user(q.get('SELECT * FROM users WHERE id = ?', r.lastInsertRowid)));
});

router.put('/admin/users/:id', (req, res) => {
  const u = q.get('SELECT * FROM users WHERE id = ?', toInt(req.params.id));
  if (!u) throw new HttpError(404, 'Foydalanuvchi topilmadi');
  const role = req.body.role_id !== undefined ? (toInt(req.body.role_id) === ROLE_ADMIN ? ROLE_ADMIN : ROLE_USER) : u.role_id;
  const blocked = req.body.is_blocked !== undefined ? (toBool(req.body.is_blocked) ? 1 : 0) : u.is_blocked;
  if (u.id === req.user.id && (role !== ROLE_ADMIN || blocked)) throw new HttpError(400, "O'zingizni administratorlikdan chiqara yoki bloklay olmaysiz");
  const name = req.body.name !== undefined ? String(req.body.name).trim().slice(0, 100) : u.name;
  let hash = u.password_hash;
  if (req.body.password) {
    if (String(req.body.password).length < 8) throw new HttpError(400, 'Parol kamida 8 belgi');
    hash = hashPassword(req.body.password);
  }
  q.run('UPDATE users SET name = ?, role_id = ?, is_blocked = ?, password_hash = ? WHERE id = ?', name, role, blocked, hash, u.id);
  if (blocked) q.run('UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?', u.id);
  res.json(S.user(q.get('SELECT * FROM users WHERE id = ?', u.id)));
});

module.exports = router;
