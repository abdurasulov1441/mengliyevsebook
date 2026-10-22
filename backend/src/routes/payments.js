'use strict';

// Manual card payments: the user transfers money to the card shown in the
// app, uploads a screenshot, an admin approves -> the book is unlocked.

const express = require('express');
const { q } = require('../db');
const { HttpError, wrap, paging, toInt } = require('../util');
const { requireAuth, requireAdmin } = require('../auth');
const { upload, moveUpload, cleanupTmp } = require('../storage');
const S = require('../serializers');

const router = express.Router();

const PAY_SELECT = `
  SELECT p.*, u.name AS user_name, u.phone_number, b.title AS book_title
  FROM payments p JOIN users u ON u.id = p.user_id JOIN books b ON b.id = p.book_id`;

router.post('/payments/create-payment', requireAuth, upload.fields([{ name: 'image', maxCount: 1 }]), wrap(async (req, res) => {
  try {
    const book = q.get('SELECT * FROM books WHERE id = ?', toInt(req.body.book_id));
    if (!book || !book.is_published) throw new HttpError(404, 'Kitob topilmadi');
    if (book.is_free) throw new HttpError(400, 'Bu kitob bepul');
    if (q.get('SELECT 1 FROM purchases WHERE user_id = ? AND book_id = ?', req.user.id, book.id)) throw new HttpError(400, 'Bu kitob allaqachon sizda bor');
    if (q.get('SELECT 1 FROM payments WHERE user_id = ? AND book_id = ? AND status_id = 1', req.user.id, book.id)) {
      throw new HttpError(400, "Bu kitob uchun to'lovingiz tekshirilmoqda. Iltimos, kuting");
    }
    const image = req.files && req.files.image && req.files.image[0];
    if (!image) throw new HttpError(400, "To'lov skrinshotini yuklang");
    const receipt = await moveUpload(image, 'receipts');
    const r = q.run(
      'INSERT INTO payments (user_id, book_id, amount, comment, receipt_image, approved_at) VALUES (?, ?, ?, ?, ?, ?)',
      req.user.id, book.id, book.price, String(req.body.comment || '').slice(0, 1000), receipt, String(req.body.approved_at || '').slice(0, 40) || null
    );
    res.status(201).json({ message: "To'lov yuborildi. Tasdiqlash kutilmoqda", payment: S.payment(q.get(`${PAY_SELECT} WHERE p.id = ?`, r.lastInsertRowid)) });
  } finally {
    await cleanupTmp(req.files);
  }
}));

router.get('/payments/my', requireAuth, (req, res) => {
  res.json({ payments: q.all(`${PAY_SELECT} WHERE p.user_id = ? ORDER BY p.id DESC`, req.user.id).map(S.payment) });
});

router.get('/payments/get-payments', requireAdmin, (req, res) => {
  const { limit, offset, page } = paging(req.query, 50, 500);
  const where = [];
  const params = [];
  if (req.query.status) {
    where.push('p.status_id = ?');
    params.push(toInt(req.query.status));
  }
  const search = String(req.query.q || '').trim();
  if (search) {
    where.push('(u.name LIKE ? OR u.phone_number LIKE ? OR b.title LIKE ?)');
    params.push(`%${search}%`, `%${search.replace(/\D/g, '') || search}%`, `%${search}%`);
  }
  const w = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const rows = q.all(`${PAY_SELECT} ${w} ORDER BY (p.status_id = 1) DESC, p.id DESC LIMIT ? OFFSET ?`, ...params, limit, offset);
  const total = q.get(`SELECT COUNT(*) AS n FROM payments p JOIN users u ON u.id = p.user_id JOIN books b ON b.id = p.book_id ${w}`, ...params).n;
  const pending = q.get('SELECT COUNT(*) AS n FROM payments WHERE status_id = 1').n;
  res.json({ payments: rows.map(S.payment), total, pending, page, limit });
});

// status: 2 = approve (unlocks the book), 3 = reject
router.put('/payments/update-payment/:id', requireAdmin, (req, res) => {
  const p = q.get('SELECT * FROM payments WHERE id = ?', toInt(req.params.id));
  if (!p) throw new HttpError(404, "To'lov topilmadi");
  const status = toInt(req.body.status ?? req.body.status_id);
  if (![1, 2, 3].includes(status)) throw new HttpError(400, "Status noto'g'ri (2 — tasdiqlash, 3 — rad etish)");
  q.tx(() => {
    q.run("UPDATE payments SET status_id = ?, admin_comment = ?, reviewed_by = ?, reviewed_at = datetime('now') WHERE id = ?", status, String(req.body.comment || '').slice(0, 1000), req.user.id, p.id);
    if (status === 2) {
      q.run("INSERT INTO purchases (user_id, book_id, source, payment_id) VALUES (?, ?, 'payment', ?) ON CONFLICT DO NOTHING", p.user_id, p.book_id, p.id);
    } else {
      q.run("DELETE FROM purchases WHERE user_id = ? AND book_id = ? AND source = 'payment' AND payment_id = ?", p.user_id, p.book_id, p.id);
    }
  });
  res.json({ message: status === 2 ? "To'lov tasdiqlandi" : status === 3 ? "To'lov rad etildi" : 'Saqlandi', payment: S.payment(q.get(`${PAY_SELECT} WHERE p.id = ?`, p.id)) });
});

module.exports = router;
