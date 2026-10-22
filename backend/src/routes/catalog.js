'use strict';

// Users (self), categories, authors and the payment contact card.

const express = require('express');
const { q, getSetting, setSetting } = require('../db');
const { HttpError, wrap, paging, toInt } = require('../util');
const { requireAuth, requireAdmin, ROLE_ADMIN } = require('../auth');
const { upload, moveUpload, removePublic, cleanupTmp } = require('../storage');
const S = require('../serializers');

const router = express.Router();

// ---------------------------------------------------------------- users
router.get('/users/me', requireAuth, (req, res) => res.json(S.user(req.user)));

router.put('/users/me', requireAuth, wrap(async (req, res) => {
  const name = String(req.body.name || '').trim().slice(0, 100);
  if (!name) throw new HttpError(400, 'Ismingizni kiriting');
  q.run('UPDATE users SET name = ? WHERE id = ?', name, req.user.id);
  res.json(S.user(q.get('SELECT * FROM users WHERE id = ?', req.user.id)));
}));

// The app calls /api/users/<id> on start to decide admin vs user screens.
router.get('/users/:id', requireAuth, (req, res) => {
  const id = toInt(req.params.id);
  if (id !== req.user.id && req.user.role_id !== ROLE_ADMIN) throw new HttpError(403, "Ruxsat yo'q");
  const u = q.get('SELECT * FROM users WHERE id = ?', id);
  if (!u) throw new HttpError(404, 'Foydalanuvchi topilmadi');
  res.json(S.user(u));
});

// ---------------------------------------------------------------- categories
function categoryFields(body) {
  const uz = String(body.name1 ?? body.name_uz ?? '').trim();
  const ru = String(body.name2 ?? body.name_ru ?? '').trim();
  const en = String(body.name3 ?? body.name_en ?? '').trim();
  if (!uz) throw new HttpError(400, 'Kategoriya nomini (uz) kiriting');
  return [uz.slice(0, 200), ru.slice(0, 200), en.slice(0, 200)];
}

function listCategories(_req, res) {
  const rows = q.all(`SELECT c.*, (SELECT COUNT(*) FROM books b WHERE b.category_id = c.id) AS books_count FROM categories c ORDER BY c.name_uz`);
  res.json(rows.map(S.category));
}
router.get('/categories/categories', listCategories); // path used by the current app
router.get('/categories', listCategories);

router.post('/categories/create-category', requireAdmin, (req, res) => {
  const r = q.run('INSERT INTO categories (name_uz, name_ru, name_en) VALUES (?, ?, ?)', ...categoryFields(req.body));
  res.status(201).json({ message: "Kategoriya qo'shildi", category: S.category(q.get('SELECT * FROM categories WHERE id = ?', r.lastInsertRowid)) });
});

router.put('/categories/update-category/:id', requireAdmin, (req, res) => {
  const r = q.run('UPDATE categories SET name_uz = ?, name_ru = ?, name_en = ? WHERE id = ?', ...categoryFields(req.body), toInt(req.params.id));
  if (!r.changes) throw new HttpError(404, 'Kategoriya topilmadi');
  res.json({ message: 'Kategoriya yangilandi', category: S.category(q.get('SELECT * FROM categories WHERE id = ?', toInt(req.params.id))) });
});

router.delete('/categories/delete-category/:id', requireAdmin, (req, res) => {
  const r = q.run('DELETE FROM categories WHERE id = ?', toInt(req.params.id));
  if (!r.changes) throw new HttpError(404, 'Kategoriya topilmadi');
  res.json({ message: "Kategoriya o'chirildi" });
});

// ---------------------------------------------------------------- authors
function authorFields(body) {
  const f = (a, b) => String(body[a] ?? body[b] ?? '').trim();
  const name = [f('name1', 'name_uz'), f('name2', 'name_ru'), f('name3', 'name_en')].map((s) => s.slice(0, 200));
  const about = [f('about1', 'about_uz'), f('about2', 'about_ru'), f('about3', 'about_en')].map((s) => s.slice(0, 5000));
  if (!name[0]) throw new HttpError(400, 'Muallif ismini (uz) kiriting');
  return [...name, ...about];
}

router.get('/authors/get-authors', (req, res) => {
  const { limit, offset, page } = paging(req.query, 50, 500);
  const search = String(req.query.q || '').trim();
  const where = search ? 'WHERE a.name_uz LIKE ? OR a.name_ru LIKE ? OR a.name_en LIKE ?' : '';
  const params = search ? Array(3).fill(`%${search}%`) : [];
  const rows = q.all(`SELECT a.*, (SELECT COUNT(*) FROM books b WHERE b.author_id = a.id) AS books_count FROM authors a ${where} ORDER BY a.name_uz LIMIT ? OFFSET ?`, ...params, limit, offset);
  const total = q.get(`SELECT COUNT(*) AS n FROM authors a ${where}`, ...params).n;
  res.json({ authors: rows.map(S.author), total, page, limit });
});

router.get('/authors/:id', (req, res) => {
  const row = q.get('SELECT * FROM authors WHERE id = ?', toInt(req.params.id));
  if (!row) throw new HttpError(404, 'Muallif topilmadi');
  res.json(S.author(row));
});

router.post('/authors/create-author', requireAdmin, upload.fields([{ name: 'image', maxCount: 1 }]), wrap(async (req, res) => {
  try {
    const fields = authorFields(req.body);
    const photo = await moveUpload(req.files && req.files.image && req.files.image[0], 'authors');
    const r = q.run('INSERT INTO authors (name_uz, name_ru, name_en, about_uz, about_ru, about_en, photo) VALUES (?, ?, ?, ?, ?, ?, ?)', ...fields, photo);
    res.status(201).json({ message: "Muallif qo'shildi", author: S.author(q.get('SELECT * FROM authors WHERE id = ?', r.lastInsertRowid)) });
  } finally {
    await cleanupTmp(req.files);
  }
}));

router.put('/authors/update-author/:id', requireAdmin, upload.fields([{ name: 'image', maxCount: 1 }]), wrap(async (req, res) => {
  try {
    const id = toInt(req.params.id);
    const row = q.get('SELECT * FROM authors WHERE id = ?', id);
    if (!row) throw new HttpError(404, 'Muallif topilmadi');
    const fields = authorFields(req.body);
    let photo = row.photo;
    const file = req.files && req.files.image && req.files.image[0];
    if (file) {
      photo = await moveUpload(file, 'authors');
      await removePublic(row.photo);
    }
    q.run('UPDATE authors SET name_uz = ?, name_ru = ?, name_en = ?, about_uz = ?, about_ru = ?, about_en = ?, photo = ? WHERE id = ?', ...fields, photo, id);
    res.json({ message: 'Muallif yangilandi', author: S.author(q.get('SELECT * FROM authors WHERE id = ?', id)) });
  } finally {
    await cleanupTmp(req.files);
  }
}));

router.delete('/authors/delete-author/:id', requireAdmin, wrap(async (req, res) => {
  const row = q.get('SELECT * FROM authors WHERE id = ?', toInt(req.params.id));
  if (!row) throw new HttpError(404, 'Muallif topilmadi');
  q.run('DELETE FROM authors WHERE id = ?', row.id);
  await removePublic(row.photo);
  res.json({ message: "Muallif o'chirildi" });
}));

// ---------------------------------------------------------------- payment contact
const DEFAULT_CONTACT = { card_number: '', name: '', phone: '', note: '' };

router.get('/references/contact/:id', requireAuth, (_req, res) => {
  res.json({ id: 1, ...DEFAULT_CONTACT, ...getSetting('contact', {}) });
});

router.put('/references/contact/:id', requireAdmin, (req, res) => {
  const pick = (k) => String(req.body[k] ?? '').trim().slice(0, 300);
  const value = { card_number: pick('card_number'), name: pick('name'), phone: pick('phone'), note: pick('note') };
  setSetting('contact', value);
  res.json({ message: 'Saqlandi', id: 1, ...value });
});

module.exports = router;
