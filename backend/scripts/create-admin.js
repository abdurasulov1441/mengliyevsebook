#!/usr/bin/env node
'use strict';

// Create or reset an administrator for the web panel:
//   npm run create-admin -- 998901234567 "strong-password" "Ism"

const { q } = require('../src/db');
const { normalizePhone, hashPassword } = require('../src/util');

const [phoneArg, password, name = 'Administrator'] = process.argv.slice(2);
const phone = normalizePhone(phoneArg);
if (!phone || !password || password.length < 8) {
  console.log('Foydalanish: npm run create-admin -- 998901234567 "parol-kamida-8-belgi" "Ism"');
  process.exit(1);
}
const user = q.get('SELECT id FROM users WHERE phone_number = ?', phone);
if (user) {
  q.run('UPDATE users SET role_id = 1, password_hash = ?, is_blocked = 0, is_verified = 1 WHERE id = ?', hashPassword(password), user.id);
  console.log(`Administrator yangilandi: +${phone}`);
} else {
  q.run('INSERT INTO users (name, phone_number, role_id, password_hash, is_verified) VALUES (?, ?, 1, ?, 1)', name, phone, hashPassword(password));
  console.log(`Administrator yaratildi: +${phone}`);
}
