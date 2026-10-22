'use strict';

const crypto = require('crypto');

class HttpError extends Error {
  constructor(status, message, extra) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}

// Express 4 does not catch rejected promises: wrap every async handler.
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// "+998 (90) 123 45 67" -> "998901234567"
function normalizePhone(input) {
  let d = String(input || '').replace(/\D/g, '');
  if (d.length === 9) d = '998' + d;
  if (!/^998\d{9}$/.test(d)) return null;
  return d;
}

function formatPhone(d) {
  if (!d || d.length !== 12) return d || '';
  return `+${d.slice(0, 3)} (${d.slice(3, 5)}) ${d.slice(5, 8)} ${d.slice(8, 10)} ${d.slice(10)}`;
}

function paging(query, defLimit = 20, maxLimit = 200) {
  const limit = Math.min(Math.max(parseInt(query.limit, 10) || defLimit, 1), maxLimit);
  const page = Math.max(parseInt(query.page, 10) || 1, 1);
  return { limit, page, offset: (page - 1) * limit };
}

const sha256 = (s) => crypto.createHash('sha256').update(String(s)).digest('hex');

function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(String(password), salt, 64);
  return `scrypt$${salt.toString('hex')}$${hash.toString('hex')}`;
}

function verifyPassword(password, stored) {
  if (!stored || !stored.startsWith('scrypt$')) return false;
  const [, saltHex, hashHex] = stored.split('$');
  const hash = crypto.scryptSync(String(password), Buffer.from(saltHex, 'hex'), 64);
  const expected = Buffer.from(hashHex, 'hex');
  return expected.length === hash.length && crypto.timingSafeEqual(expected, hash);
}

const toBool = (v) => v === true || v === 1 || v === '1' || v === 'true' || v === 'on';
const toInt = (v, d = 0) => {
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : d;
};

function parseJson(s, fallback) {
  try {
    return s ? JSON.parse(s) : fallback;
  } catch {
    return fallback;
  }
}

module.exports = { HttpError, wrap, normalizePhone, formatPhone, paging, sha256, hashPassword, verifyPassword, toBool, toInt, parseJson };
