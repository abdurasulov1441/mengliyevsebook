'use strict';

// SQLite through Node's built-in driver (node:sqlite): no native modules to
// compile, one file to back up (data/ebook.sqlite).

const fs = require('fs');
const { DatabaseSync } = require('node:sqlite');
const config = require('./config');

fs.mkdirSync(config.dataDir, { recursive: true });

const db = new DatabaseSync(config.dbFile);
db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;');

const MIGRATIONS = [
  // 1: initial schema
  `
  CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL DEFAULT '',
    phone_number TEXT NOT NULL UNIQUE,
    role_id INTEGER NOT NULL DEFAULT 2,          -- 1 admin, 2 user
    password_hash TEXT,
    fcm_token TEXT,
    is_verified INTEGER NOT NULL DEFAULT 0,
    is_blocked INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_login_at TEXT
  );
  CREATE TABLE otp_codes (
    phone_number TEXT PRIMARY KEY,
    code_hash TEXT NOT NULL,
    expires_at INTEGER NOT NULL,
    sent_at INTEGER NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0
  );
  CREATE TABLE refresh_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    revoked INTEGER NOT NULL DEFAULT 0
  );
  CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name_uz TEXT NOT NULL,
    name_ru TEXT NOT NULL DEFAULT '',
    name_en TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE TABLE authors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name_uz TEXT NOT NULL,
    name_ru TEXT NOT NULL DEFAULT '',
    name_en TEXT NOT NULL DEFAULT '',
    about_uz TEXT NOT NULL DEFAULT '',
    about_ru TEXT NOT NULL DEFAULT '',
    about_en TEXT NOT NULL DEFAULT '',
    photo TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE TABLE books (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    author_id INTEGER REFERENCES authors(id) ON DELETE SET NULL,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    price INTEGER NOT NULL DEFAULT 0,
    is_free INTEGER NOT NULL DEFAULT 1,
    is_published INTEGER NOT NULL DEFAULT 1,
    photo TEXT,
    source_file TEXT,
    source_name TEXT,
    conversion_status TEXT NOT NULL DEFAULT 'none', -- none|pending|processing|ready|failed
    conversion_error TEXT,
    conversion_report TEXT,
    package_version INTEGER NOT NULL DEFAULT 0,
    lang TEXT,
    chapters INTEGER NOT NULL DEFAULT 0,
    words INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL DEFAULT 0,
    comment TEXT NOT NULL DEFAULT '',
    status_id INTEGER NOT NULL DEFAULT 1,          -- 1 pending, 2 approved, 3 rejected
    receipt_image TEXT,
    approved_at TEXT,                              -- payment time entered by the user
    admin_comment TEXT,
    reviewed_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
  CREATE TABLE purchases (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    source TEXT NOT NULL DEFAULT 'payment',       -- payment|admin
    payment_id INTEGER,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, book_id)
  );
  CREATE TABLE reading (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    position TEXT,
    percent REAL NOT NULL DEFAULT 0,
    bookmarks TEXT NOT NULL DEFAULT '[]',
    highlights TEXT NOT NULL DEFAULT '[]',
    updated_at INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, book_id)
  );
  CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );
  CREATE INDEX idx_books_pub ON books(is_published, conversion_status);
  CREATE INDEX idx_payments_status ON payments(status_id, created_at);
  CREATE INDEX idx_payments_user ON payments(user_id);
  `,
  // 2: take the title from the book itself when the admin left it empty
  `ALTER TABLE books ADD COLUMN auto_title INTEGER NOT NULL DEFAULT 0;`,
];

function migrate() {
  db.exec('CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)');
  const row = db.prepare('SELECT version FROM schema_version').get();
  let version = row ? row.version : 0;
  if (!row) db.prepare('INSERT INTO schema_version (version) VALUES (0)').run();
  while (version < MIGRATIONS.length) {
    db.exec('BEGIN');
    try {
      db.exec(MIGRATIONS[version]);
      version++;
      db.prepare('UPDATE schema_version SET version = ?').run(version);
      db.exec('COMMIT');
    } catch (e) {
      db.exec('ROLLBACK');
      throw e;
    }
  }
}

migrate();

// Tiny helpers so route code stays readable.
const q = {
  get: (sql, ...p) => db.prepare(sql).get(...p),
  all: (sql, ...p) => db.prepare(sql).all(...p),
  run: (sql, ...p) => db.prepare(sql).run(...p),
  tx(fn) {
    db.exec('BEGIN');
    try {
      const r = fn();
      db.exec('COMMIT');
      return r;
    } catch (e) {
      db.exec('ROLLBACK');
      throw e;
    }
  },
};

function getSetting(key, fallback) {
  const row = q.get('SELECT value FROM settings WHERE key = ?', key);
  return row ? JSON.parse(row.value) : fallback;
}

function setSetting(key, value) {
  q.run('INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', key, JSON.stringify(value));
}

module.exports = { db, q, getSetting, setSetting };
