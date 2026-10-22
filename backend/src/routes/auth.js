'use strict';

const crypto = require('crypto');
const express = require('express');
const config = require('../config');
const { q } = require('../db');
const { HttpError, wrap, normalizePhone, sha256, verifyPassword } = require('../util');
const { signAccess, issueRefresh, useRefresh, revokeRefresh, requireAuth, ROLE_ADMIN } = require('../auth');
const { sendSms } = require('../sms');
const { user: serializeUser } = require('../serializers');

const router = express.Router();

// --- small in-memory rate limiter (per IP) for SMS endpoints ---
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
  if (!phone) throw new HttpError(400, "Telefon raqam noto'g'ri. Format: +998 (90) 123 45 67");
  return phone;
}

async function sendOtp(phone, req) {
  limit(`ip:${req.ip}`, 15, 3600000);
  limit(`ph:${phone}`, 6, 3600000);
  const existing = q.get('SELECT * FROM otp_codes WHERE phone_number = ?', phone);
  const now = Date.now();
  if (existing && now - existing.sent_at < config.otp.resendSec * 1000) {
    const wait = Math.ceil((config.otp.resendSec * 1000 - (now - existing.sent_at)) / 1000);
    throw new HttpError(429, `Kod yuborilgan. Qayta yuborish uchun ${wait} soniya kuting`);
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
  if (row.attempts >= config.otp.maxAttempts) throw new HttpError(429, "Urinishlar soni tugadi. Yangi kod oling");
  if (row.code_hash !== codeHash(phone, code)) {
    q.run('UPDATE otp_codes SET attempts = attempts + 1 WHERE phone_number = ?', phone);
    throw new HttpError(400, "Kod noto'g'ri");
  }
  q.run('DELETE FROM otp_codes WHERE phone_number = ?', phone);
}

function tokensFor(user) {
  q.run("UPDATE users SET last_login_at = datetime('now') WHERE id = ?", user.id);
  return {
    accessToken: signAccess(user),
    refreshToken: issueRefresh(user.id),
    id: user.id,
    role_id: user.role_id,
    user: serializeUser(user),
  };
}

const ok = (message, extra) => ({ status: 200, statusCode: 200, message, ...extra });

// Sign up: name + phone -> SMS code. An existing number simply gets a code.
router.post('/auth/register', wrap(async (req, res) => {
  const phone = phoneOr400(req.body.phone_number);
  const name = String(req.body.name || '').trim().slice(0, 100);
  if (!name) throw new HttpError(400, 'Ismingizni kiriting');
  const existing = q.get('SELECT * FROM users WHERE phone_number = ?', phone);
  if (existing && existing.is_blocked) throw new HttpError(403, 'Hisob bloklangan');
  if (!existing) q.run('INSERT INTO users (name, phone_number) VALUES (?, ?)', name, phone);
  else if (!existing.is_verified) q.run('UPDATE users SET name = ? WHERE id = ?', name, existing.id);
  await sendOtp(phone, req);
  res.json(ok('Tasdiqlash kodi SMS orqali yuborildi'));
}));

// Login: phone -> SMS code (account must exist).
router.post('/auth/login', wrap(async (req, res) => {
  const phone = phoneOr400(req.body.phone_number);
  const user = q.get('SELECT * FROM users WHERE phone_number = ?', phone);
  if (!user) throw new HttpError(404, "Bu raqam ro'yxatdan o'tmagan. Avval ro'yxatdan o'ting");
  if (user.is_blocked) throw new HttpError(403, 'Hisob bloklangan');
  await sendOtp(phone, req);
  res.json(ok('Tasdiqlash kodi SMS orqali yuborildi'));
}));

const resend = wrap(async (req, res) => {
  const phone = phoneOr400(req.body.phone_number);
  if (!q.get('SELECT id FROM users WHERE phone_number = ?', phone)) throw new HttpError(404, "Bu raqam ro'yxatdan o'tmagan");
  await sendOtp(phone, req);
  res.json(ok('Kod qayta yuborildi'));
});
router.post('/services/zyber/auth/resend', resend); // path used by the current app
router.post('/auth/resend', resend);

router.post('/auth/verify', wrap(async (req, res) => {
  const phone = phoneOr400(req.body.phone_number);
  limit(`verify:${req.ip}`, 30, 600000);
  checkOtp(phone, req.body.verification_code);
  let user = q.get('SELECT * FROM users WHERE phone_number = ?', phone);
  if (!user) throw new HttpError(404, 'Foydalanuvchi topilmadi');
  if (user.is_blocked) throw new HttpError(403, 'Hisob bloklangan');
  q.run('UPDATE users SET is_verified = 1, fcm_token = COALESCE(NULLIF(?, \'\'), fcm_token) WHERE id = ?', String(req.body.fcm_token || ''), user.id);
  user = q.get('SELECT * FROM users WHERE id = ?', user.id);
  res.json(tokensFor(user));
}));

router.post('/auth/refresh', wrap(async (req, res) => {
  const user = useRefresh(req.body.refreshToken || req.body.refresh_token);
  if (!user) throw new HttpError(401, 'Sessiya tugagan. Qaytadan kiring');
  res.json({ accessToken: signAccess(user), id: user.id, role_id: user.role_id });
}));

router.post('/auth/logout', wrap(async (req, res) => {
  if (req.body.refreshToken) revokeRefresh(req.body.refreshToken);
  res.json(ok('Chiqildi'));
}));

// Web admin panel: phone + password (set with ADMIN_PASSWORD or npm run create-admin).
router.post('/auth/admin-login', wrap(async (req, res) => {
  limit(`admin:${req.ip}`, 20, 900000);
  const phone = normalizePhone(req.body.phone || req.body.phone_number);
  const user = phone && q.get('SELECT * FROM users WHERE phone_number = ?', phone);
  if (!user || user.role_id !== ROLE_ADMIN || !verifyPassword(req.body.password || '', user.password_hash) || user.is_blocked) {
    throw new HttpError(401, "Telefon yoki parol noto'g'ri");
  }
  res.json(tokensFor(user));
}));

router.post('/auth/fcm-token', requireAuth, wrap(async (req, res) => {
  q.run('UPDATE users SET fcm_token = ? WHERE id = ?', String(req.body.fcm_token || ''), req.user.id);
  res.json(ok('OK'));
}));

module.exports = router;
