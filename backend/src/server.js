'use strict';

const config = require('./config');
const { q } = require('./db');
const { hashPassword, verifyPassword } = require('./util');
const { createApp } = require('./app');
const { findSoffice } = require('./converter');
const jobs = require('./jobs');

// ADMIN_PHONE + ADMIN_PASSWORD in .env keep an administrator account in sync.
function ensureAdmin() {
  const { phone, password, name } = config.admin;
  if (!phone || !password) return;
  const user = q.get('SELECT * FROM users WHERE phone_number = ?', phone);
  if (!user) {
    q.run('INSERT INTO users (name, phone_number, role_id, password_hash, is_verified) VALUES (?, ?, 1, ?, 1)', name, phone, hashPassword(password));
    console.log(`[admin] created administrator +${phone}`);
  } else if (user.role_id !== 1 || !verifyPassword(password, user.password_hash)) {
    q.run('UPDATE users SET role_id = 1, password_hash = ?, is_blocked = 0 WHERE id = ?', hashPassword(password), user.id);
    console.log(`[admin] updated administrator +${phone}`);
  }
}

ensureAdmin();
const app = createApp();
app.listen(config.port, () => {
  console.log(`BookHub backend: http://localhost:${config.port}`);
  console.log(`  admin panel  http://localhost:${config.port}/admin/`);
  console.log(`  API docs     http://localhost:${config.port}/api/docs`);
  console.log(`  data         ${config.dataDir}`);
  console.log(`  SMS          ${config.sms.dryRun ? 'DRY RUN (codes are printed here)' : 'GetSMS.uz'}`);
  console.log(`  LibreOffice  ${findSoffice() || 'not found (.doc files: text only)'}`);
  if (config.otp.devCode) console.log(`  DEV_OTP_CODE ${config.otp.devCode} accepted for any phone`);
  jobs.resume();
});
