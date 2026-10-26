'use strict';

const path = require('path');
const crypto = require('crypto');
require('dotenv').config({ path: path.join(__dirname, '..', '.env'), quiet: true });

const root = path.join(__dirname, '..');
const env = process.env;
const bool = (v, d = false) => (v === undefined || v === '' ? d : /^(1|true|yes|on)$/i.test(v));

const isProd = env.NODE_ENV === 'production';

const config = {
  isProd,
  port: +(env.PORT || 3000),
  publicUrl: (env.PUBLIC_URL || '').replace(/\/$/, ''),
  dataDir: path.resolve(root, env.DATA_DIR || 'data'),
  jwtSecret: env.JWT_SECRET || '',
  accessTtl: env.ACCESS_TOKEN_TTL || '2h',
  refreshTtlDays: +(env.REFRESH_TOKEN_DAYS || 90),
  readTokenTtl: env.READ_TOKEN_TTL || '12h',
  corsOrigins: (env.CORS_ORIGINS || '*').split(',').map((s) => s.trim()).filter(Boolean),
  trustProxy: bool(env.TRUST_PROXY, true),

  sms: {
    url: env.SMS_URL || 'http://185.8.212.184/smsgateway/',
    login: env.SMS_LOGIN || '',
    password: env.SMS_PASSWORD || '',
    nickname: env.SMS_NICKNAME || '',
    dryRun: bool(env.SMS_DRY_RUN, !env.SMS_LOGIN),
    template: env.SMS_TEMPLATE || "BookHub: tasdiqlash kodi {code}. Kodni hech kimga bermang.",
  },
  otp: {
    ttlSec: +(env.OTP_TTL_SEC || 300),
    resendSec: +(env.OTP_RESEND_SEC || 60),
    maxAttempts: +(env.OTP_MAX_ATTEMPTS || 5),
    // Fixed code accepted for every phone in development (never in production).
    devCode: !isProd ? env.DEV_OTP_CODE || '' : '',
    // Store-review account: this phone always accepts this code.
    testPhone: (env.TEST_PHONE || '').replace(/\D/g, ''),
    testCode: env.TEST_CODE || '',
  },
  admin: {
    phone: (env.ADMIN_PHONE || '').replace(/\D/g, ''),
    password: env.ADMIN_PASSWORD || '',
    name: env.ADMIN_NAME || 'Administrator',
    // Numbers that become administrators when they log in with an SMS code.
    phones: (env.ADMIN_PHONES || '998900961704').split(',').map((p) => p.replace(/\D/g, '')).filter(Boolean),
  },
  platform: {
    name: env.PLATFORM_NAME || 'BookHub',
    // Defaults; the admin can change both in Settings (stored in the DB).
    commissionPercent: +(env.COMMISSION_PERCENT || 30),
    payoutMin: +(env.PAYOUT_MIN || 50000),
  },
  payments: {
    // Demo payments (a button instead of Payme/Click) — for development and
    // until the merchant contracts are signed. Never enable in production.
    demo: bool(env.PAYMENTS_DEMO, !isProd),
    returnUrl: env.PAYMENT_RETURN_URL || '',
    payme: {
      merchantId: env.PAYME_MERCHANT_ID || '',
      key: env.PAYME_KEY || '',
      test: bool(env.PAYME_TEST, true),
    },
    click: {
      serviceId: env.CLICK_SERVICE_ID || '',
      merchantId: env.CLICK_MERCHANT_ID || '',
      secretKey: env.CLICK_SECRET_KEY || '',
    },
  },
  uploads: {
    maxBookMb: +(env.MAX_BOOK_MB || 100),
    maxImageMb: +(env.MAX_IMAGE_MB || 10),
  },
};

config.dbFile = path.join(config.dataDir, 'ebook.sqlite');
config.publicDir = path.join(config.dataDir, 'public'); // served at /_files
config.privateDir = path.join(config.dataDir, 'private'); // book sources & packages
config.tmpDir = path.join(config.dataDir, 'tmp');

if (!config.jwtSecret) {
  if (isProd) throw new Error('JWT_SECRET must be set in production (.env)');
  // Development: stable per data folder so tokens survive restarts.
  const fs = require('fs');
  const f = path.join(config.dataDir, '.dev-secret');
  fs.mkdirSync(config.dataDir, { recursive: true });
  if (!fs.existsSync(f)) fs.writeFileSync(f, crypto.randomBytes(32).toString('hex'));
  config.jwtSecret = fs.readFileSync(f, 'utf8').trim();
}

module.exports = config;
