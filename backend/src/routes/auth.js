'use strict';

const crypto = require('crypto');
const express = require('express');
const config = require('../config');
const { q } = require('../db');
const { HttpError, wrap, normalizePhone, sha256, verifyPassword } = require('../util');
const { signAccess, issueRefresh, useRefresh, revokeRefresh, requireAuth, ROLE_ADMIN, ROLE_USER } = require('../auth');
const { sendSms } = require('../sms');
const { upload, moveUpload, removePublic, cleanupTmp } = require('../storage');
const { isAdminPhone } = require('../services/platform');
const S = require('../serializers');

const router = express.Router();

// --- small in-memory rate limiter for SMS endpoints ---
const hits = new Map();
function limit(key, max, windowMs) {
  const now = Date.now();
  const arr = (hits.get(key) || []).filter((t) => now - t < windowMs);
  if (arr.length >= max) throw new HttpError(429, "Juda ko'p urinish. Birozdan keyin qayta urinib ko'ring");
  arr.push(now);
  hits.set(key, arr);
}
setInterval(() => {
  const now = Date.now();
  for (const [k, arr] of hits) if (!arr.some((t) => now - t < 3600000)) hits.delete(k);
}, 600000).unref();

const codeHash = (phone, code) => sha256(`${phone}:${code}:${config.jwtSecret}`);

function phoneOr400(raw) {
  const phone = normalizePhone(raw);
  if (!phone) throw new HttpError(400, "Telefon raqam noto'g'ri. Format: +998 90 123 45 67");
  return phone;
}

async function sendOtp(phone, req) {
  limit(`ip:${req.ip}`, 20, 3600000);
  limit(`ph:${phone}`, 8, 3600000);
  const existing = q.get('SELECT * FROM otp_codes WHERE phone_number = ?', phone);
  const now = Date.now();
  if (existing && now - existing.sent_at < config.otp.resendSec * 1000) {
    const wait = Math.ceil((config.otp.resendSec * 1000 - (now - existing.sent_at)) / 1000);
    throw new HttpError(429, `Kod yuborilgan. Qayta yuborish uchun ${wait} soniya kuting`, { retry_after: wait });
  }
  const isTest = config.otp.testPhone && phone === config.otp.testPhone && config.otp.testCode;
  const code = isTest ? config.otp.testCode : String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  q.run(
    `INSERT INTO otp_codes (phone_number, code_hash, expires_at, sent_at, attempts) VALUES (?, ?, ?, ?, 0)
     ON CONFLICT(phone_number) DO UPDATE SET code_hash = excluded.code_hash, expires_at = excluded.expires_at, sent_at = excluded.sent_at, attempts = 0`,
    phone, codeHash(phone, code), now + config.otp.ttlSec * 1000, now
  );
  if (isTest) return;
  const res = await sendSms(phone, config.sms.template.replace('{code}', code));
  if (!res.ok) {
    q.run('DELETE FROM otp_codes WHERE phone_number = ?', phone);
    throw new HttpError(502, "SMS yuborib bo'lmadi. Birozdan keyin qayta urinib ko'ring");
  }
}

function checkOtp(phone, code) {
  code = String(code || '').trim();
  if (config.otp.devCode && code === config.otp.devCode) return;
  const row = q.get('SELECT * FROM otp_codes WHERE phone_number = ?', phone);
  if (!row) throw new HttpError(400, 'Avval tasdiqlash kodini oling');
  if (row.expires_at < Date.now()) throw new HttpError(400, 'Kodning amal qilish muddati tugagan. Yangi kod oling');
  if (row.attempts >= config.otp.maxAttempts) throw new HttpError(429, 'Urinishlar soni tugadi. Yangi kod oling');
  if (row.code_hash !== codeHash(phone, code)) {
    q.run('UPDATE otp_codes SET attempts = attempts + 1 WHERE phone_number = ?', phone);
    throw new HttpError(400, "Kod noto'g'ri");
  }
  q.run('DELETE FROM otp_codes WHERE phone_number = ?', phone);
}

function meOut(u) {
  const author = q.get('SELECT * FROM author_profiles WHERE user_id = ?', u.id);
  const unread = q.get('SELECT COUNT(*) AS n FROM notifications WHERE user_id = ? AND read_at IS NULL', u.id).n;
  return S.user(u, { is_author: !!author, author: S.authorProfile(author, { full: true }), unread_notifications: unread, needs_name: !u.name });
}

function session(user) {
  q.run("UPDATE users SET last_login_at = datetime('now') WHERE id = ?", user.id);
  return { accessToken: signAccess(user), refreshToken: issueRefresh(user.id), user: meOut(user) };
}

/**
 * Step 1 of sign-in / sign-up: send an SMS code to any number.
 * @openapi POST /api/auth/request-otp
 */
router.post('/auth/request-otp', wrap(async (req, res) => {
  const phone = phoneOr400(req.body.phone || req.body.phone_number);
  const user = q.get('SELECT * FROM users WHERE phone_number = ?', phone);
  if (user && user.is_blocked) throw new HttpError(403, 'Hisob bloklangan. Yordam: ' + (config.admin.phones[0] ? '+' + config.admin.phones[0] : ''));
  await sendOtp(phone, req);
  res.json({ ok: true, message: 'Tasdiqlash kodi SMS orqali yuborildi', is_new: !user, resend_after: config.otp.resendSec, dev_code_hint: config.otp.devCode ? true : undefined });
}));

/** Step 2: code -> session. New numbers get an account; the name can come now or later. */
router.post('/auth/verify', wrap(async (req, res) => {
  const phone = phoneOr400(req.body.phone || req.body.phone_number);
  limit(`verify:${req.ip}`, 40, 600000);
  checkOtp(phone, req.body.code ?? req.body.verification_code);
  let user = q.get('SELECT * FROM users WHERE phone_number = ?', phone);
  const name = String(req.body.name || '').trim().slice(0, 100);
  if (!user) {
    const r = q.run('INSERT INTO users (name, phone_number, role_id, is_verified) VALUES (?, ?, ?, 1)', name, phone, isAdminPhone(phone) ? ROLE_ADMIN : ROLE_USER);
    user = q.get('SELECT * FROM users WHERE id = ?', r.lastInsertRowid);
  } else {
    if (user.is_blocked) throw new HttpError(403, 'Hisob bloklangan');
    if (name && !user.name) q.run('UPDATE users SET name = ? WHERE id = ?', name, user.id);
  }
  // Admin numbers are always admins (configured with ADMIN_PHONES).
  if (isAdminPhone(phone) && user.role_id !== ROLE_ADMIN) q.run('UPDATE users SET role_id = ? WHERE id = ?', ROLE_ADMIN, user.id);
  if (req.body.fcm_token) q.run('UPDATE users SET fcm_token = ? WHERE id = ?', String(req.body.fcm_token), user.id);
  q.run('UPDATE users SET is_verified = 1 WHERE id = ?', user.id);
  user = q.get('SELECT * FROM users WHERE id = ?', user.id);
  res.json(session(user));
}));

router.post('/auth/refresh', wrap(async (req, res) => {
  const user = useRefresh(req.body.refreshToken || req.body.refresh_token);
  if (!user) throw new HttpError(401, 'Sessiya tugagan. Qaytadan kiring');
  res.json({ accessToken: signAccess(user) });
}));

router.post('/auth/logout', wrap(async (req, res) => {
  if (req.body.refreshToken) revokeRefresh(req.body.refreshToken);
  res.json({ ok: true });
}));

// Web admin panel: phone + password (ADMIN_PHONE/ADMIN_PASSWORD or npm run create-admin).
router.post('/auth/admin-login', wrap(async (req, res) => {
  limit(`admin:${req.ip}`, 20, 900000);
  const phone = normalizePhone(req.body.phone || req.body.phone_number);
  const user = phone && q.get('SELECT * FROM users WHERE phone_number = ?', phone);
  if (!user || user.role_id !== ROLE_ADMIN || !verifyPassword(req.body.password || '', user.password_hash) || user.is_blocked) {
    throw new HttpError(401, "Telefon yoki parol noto'g'ri");
  }
  res.json(session(user));
}));

// ---------------------------------------------------------------- me
router.get('/me', requireAuth, (req, res) => res.json(meOut(req.user)));

router.put('/me', requireAuth, upload.fields([{ name: 'avatar', maxCount: 1 }]), wrap(async (req, res) => {
  try {
    const name = req.body.name !== undefined ? String(req.body.name).trim().slice(0, 100) : req.user.name;
    if (!name) throw new HttpError(400, 'Ismingizni kiriting');
    let avatar = req.user.avatar;
    const file = req.files && req.files.avatar && req.files.avatar[0];
    if (file) {
      avatar = await moveUpload(file, 'avatars');
      await removePublic(req.user.avatar);
    }
    q.run('UPDATE users SET name = ?, avatar = ? WHERE id = ?', name, avatar, req.user.id);
    res.json(meOut(q.get('SELECT * FROM users WHERE id = ?', req.user.id)));
  } finally {
    await cleanupTmp(req.files);
  }
}));

router.post('/me/fcm-token', requireAuth, (req, res) => {
  q.run('UPDATE users SET fcm_token = ? WHERE id = ?', String(req.body.fcm_token || ''), req.user.id);
  res.json({ ok: true });
});

router.get('/me/notifications', requireAuth, (req, res) => {
  const rows = q.all('SELECT * FROM notifications WHERE user_id = ? ORDER BY id DESC LIMIT 100', req.user.id);
  const unread = q.get('SELECT COUNT(*) AS n FROM notifications WHERE user_id = ? AND read_at IS NULL', req.user.id).n;
  res.json({ notifications: rows.map(S.notification), unread });
});

router.post('/me/notifications/read', requireAuth, (req, res) => {
  q.run("UPDATE notifications SET read_at = datetime('now') WHERE user_id = ? AND read_at IS NULL", req.user.id);
  res.json({ ok: true });
});

module.exports = router;
