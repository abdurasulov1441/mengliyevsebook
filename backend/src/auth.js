'use strict';

const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const config = require('./config');
const { q } = require('./db');
const { HttpError, sha256 } = require('./util');

const ROLE_ADMIN = 1;
const ROLE_USER = 2;

function signAccess(user) {
  return jwt.sign({ sub: user.id, role: user.role_id, typ: 'access' }, config.jwtSecret, { expiresIn: config.accessTtl });
}

function issueRefresh(userId) {
  const token = crypto.randomBytes(48).toString('base64url');
  const expires = Date.now() + config.refreshTtlDays * 86400000;
  q.run('INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES (?, ?, ?)', userId, sha256(token), expires);
  return token;
}

function useRefresh(token) {
  const row = q.get('SELECT * FROM refresh_tokens WHERE token_hash = ?', sha256(token || ''));
  if (!row || row.revoked || row.expires_at < Date.now()) return null;
  const user = q.get('SELECT * FROM users WHERE id = ?', row.user_id);
  if (!user || user.is_blocked) return null;
  return user;
}

function revokeRefresh(token) {
  q.run('UPDATE refresh_tokens SET revoked = 1 WHERE token_hash = ?', sha256(token || ''));
}

// Short-lived token that lets the web reader fetch one book's files with
// <script>/<img> tags (which cannot send an Authorization header).
function signReadToken(userId, bookId) {
  return jwt.sign({ sub: userId, book: bookId, typ: 'read' }, config.jwtSecret, { expiresIn: config.readTokenTtl });
}

function decode(token, typ) {
  try {
    const p = jwt.verify(token, config.jwtSecret);
    return p.typ === typ ? p : null;
  } catch {
    return null;
  }
}

function loadUser(id) {
  const u = q.get('SELECT * FROM users WHERE id = ?', id);
  return u && !u.is_blocked ? u : null;
}

function bearer(req) {
  const h = req.headers.authorization || '';
  return h.startsWith('Bearer ') ? h.slice(7).trim() : null;
}

// Attaches req.user when a valid access token is present.
function optionalAuth(req, _res, next) {
  const token = bearer(req);
  if (token) {
    const p = decode(token, 'access');
    if (p) req.user = loadUser(p.sub) || undefined;
  }
  next();
}

function requireAuth(req, _res, next) {
  const token = bearer(req);
  if (!token) return next(new HttpError(401, 'Avtorizatsiya talab qilinadi'));
  const p = decode(token, 'access');
  if (!p) return next(new HttpError(401, 'Token eskirgan yoki noto‘g‘ri'));
  const user = loadUser(p.sub);
  if (!user) return next(new HttpError(401, 'Foydalanuvchi topilmadi yoki bloklangan'));
  req.user = user;
  next();
}

function requireAdmin(req, res, next) {
  requireAuth(req, res, (err) => {
    if (err) return next(err);
    if (req.user.role_id !== ROLE_ADMIN) return next(new HttpError(403, 'Faqat administrator uchun'));
    next();
  });
}

// Book content: Bearer token, or ?rt= read token scoped to this book.
function bookReader(req, _res, next) {
  const token = bearer(req);
  if (token) {
    const p = decode(token, 'access');
    if (p) req.user = loadUser(p.sub) || undefined;
  } else if (req.query.rt) {
    const p = decode(String(req.query.rt), 'read');
    if (p && String(p.book) === String(req.params.id)) req.user = loadUser(p.sub) || undefined;
  }
  if (!req.user) return next(new HttpError(401, 'Avtorizatsiya talab qilinadi'));
  next();
}

module.exports = { ROLE_ADMIN, ROLE_USER, signAccess, issueRefresh, useRefresh, revokeRefresh, signReadToken, optionalAuth, requireAuth, requireAdmin, bookReader };
