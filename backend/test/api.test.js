'use strict';

// End-to-end API test on a throw-away data folder:
//   node --test test/
// Uses a tiny generated .docx so it runs anywhere.

const test = require('node:test');
const assert = require('node:assert');
const os = require('os');
const fs = require('fs');
const path = require('path');
const JSZip = require('jszip');

const DATA = fs.mkdtempSync(path.join(os.tmpdir(), 'mbook-test-'));
process.env.DATA_DIR = DATA;
process.env.NODE_ENV = 'test';
process.env.DEV_OTP_CODE = '111111';
process.env.SMS_LOGIN = '';
process.env.ADMIN_PHONE = '998900000001';
process.env.ADMIN_PASSWORD = 'admin-password-1';
process.env.JWT_SECRET = 'test-secret';

const { createApp } = require('../src/app');

async function makeDocx() {
  // Minimal WordprocessingML: title page, two chapters with bold 16pt titles,
  // a sub-heading and a footnote-free body.
  const p = (text, { bold, size, center, pageBreak } = {}) =>
    `<w:p><w:pPr>${center ? '<w:jc w:val="center"/>' : ''}</w:pPr>${pageBreak ? '<w:r><w:br w:type="page"/></w:r>' : ''}<w:r><w:rPr>${bold ? '<w:b/>' : ''}<w:sz w:val="${size || 28}"/></w:rPr><w:t xml:space="preserve">${text}</w:t></w:r></w:p>`;
  const body = [
    p('TOSHKENT UNIVERSITETI', { bold: true, center: true }),
    p('SINOV KITOBI', { bold: true, size: 56, center: true }),
    p('Toshkent - 2025', { bold: true, center: true }),
    p('KIRISH', { bold: true, size: 40, center: true, pageBreak: true }),
    ...Array.from({ length: 30 }, (_, i) => p(`Kirish matni ${i}. Bu sinov uchun yozilgan oddiy paragraf bo‘lib, kitob o‘qish dasturini tekshiradi va sahifalarni to‘ldiradi.`)),
    p('BIRINCHI BOB', { bold: true, size: 40, center: true, pageBreak: true }),
    p('1.1. Kichik sarlavha', { bold: true, size: 32 }),
    ...Array.from({ length: 40 }, (_, i) => p(`Birinchi bob matni ${i}. Matn yetarlicha uzun bo‘lishi kerak, shunda boblar to‘g‘ri ajratiladi va mundarija yaratiladi.`)),
    p('IKKINCHI BOB', { bold: true, size: 40, center: true, pageBreak: true }),
    p('2.1. Yana bir sarlavha', { bold: true, size: 32 }),
    ...Array.from({ length: 40 }, (_, i) => p(`Ikkinchi bob matni ${i}. Gipoteza so‘zi qidiruv uchun shu yerda turibdi.`)),
  ].join('');
  const zip = new JSZip();
  zip.file('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>');
  zip.file('_rels/.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>');
  zip.file('word/document.xml', `<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${body}</w:body></w:document>`);
  return zip.generateAsync({ type: 'nodebuffer' });
}

let server;
let base;

test.before(async () => {
  // Same bootstrap as server.js (admin from env) without listening on 3000.
  const { q } = require('../src/db');
  const { hashPassword } = require('../src/util');
  q.run("INSERT INTO users (name, phone_number, role_id, password_hash, is_verified) VALUES ('Admin', ?, 1, ?, 1)", process.env.ADMIN_PHONE, hashPassword(process.env.ADMIN_PASSWORD));
  server = createApp().listen(0);
  await new Promise((r) => server.once('listening', r));
  base = `http://127.0.0.1:${server.address().port}`;
});

test.after(async () => {
  server.close();
  require('../src/db').db.close();
  await new Promise((r) => setTimeout(r, 200));
  fs.rmSync(DATA, { recursive: true, force: true, maxRetries: 5 });
});

async function api(method, url, { token, json, form } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  let body;
  if (json) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(json);
  } else if (form) body = form;
  const res = await fetch(base + url, { method, headers, body });
  const type = res.headers.get('content-type') || '';
  const data = type.includes('json') ? await res.json() : Buffer.from(await res.arrayBuffer());
  return { status: res.status, data, headers: res.headers };
}

async function waitReady(token, id) {
  for (let i = 0; i < 100; i++) {
    const r = await api('GET', `/api/books/${id}`, { token });
    if (['ready', 'failed'].includes(r.data.conversion_status)) return r.data;
    await new Promise((res) => setTimeout(res, 100));
  }
  throw new Error('conversion timeout');
}

test('full flow: sign up, admin uploads Word book, user reads, buys, syncs', async () => {
  // --- user signs up with SMS code
  let r = await api('POST', '/api/auth/register', { json: { name: 'Ali', phone_number: '+998 (90) 123 45 67' } });
  assert.equal(r.status, 200);
  assert.equal(r.data.statusCode, 200);
  r = await api('POST', '/api/auth/verify', { json: { phone_number: '+998 (90) 123 45 67', verification_code: '000000' } });
  assert.equal(r.status, 400, 'wrong code rejected');
  assert.ok(r.data.response.message);
  r = await api('POST', '/api/auth/verify', { json: { phone_number: '+998 (90) 123 45 67', verification_code: '111111', fcm_token: 'x' } });
  assert.equal(r.status, 200);
  assert.ok(r.data.accessToken && r.data.refreshToken);
  assert.equal(r.data.role_id, 2);
  const user = r.data;

  r = await api('GET', `/api/users/${user.id}`, { token: user.accessToken });
  assert.equal(r.data.role_id, 2);
  r = await api('POST', '/api/auth/refresh', { json: { refreshToken: user.refreshToken } });
  assert.ok(r.data.accessToken);

  // login for unknown number -> 404 with message
  r = await api('POST', '/api/auth/login', { json: { phone_number: '+998 (99) 999 99 99' } });
  assert.equal(r.status, 404);

  // --- admin
  r = await api('POST', '/api/auth/admin-login', { json: { phone: process.env.ADMIN_PHONE, password: 'nope' } });
  assert.equal(r.status, 401);
  r = await api('POST', '/api/auth/admin-login', { json: { phone: process.env.ADMIN_PHONE, password: process.env.ADMIN_PASSWORD } });
  assert.equal(r.status, 200);
  const admin = r.data.accessToken;

  r = await api('POST', '/api/categories/create-category', { token: user.accessToken, json: { name1: 'X' } });
  assert.equal(r.status, 403, 'users cannot create categories');
  r = await api('POST', '/api/categories/create-category', { token: admin, json: { name1: 'Ilmiy', name2: 'Научные', name3: 'Science' } });
  assert.equal(r.status, 201);
  const cat = r.data.category;
  r = await api('GET', '/api/categories/categories');
  assert.equal(r.data[0].name.uz, 'Ilmiy');

  let fd = new FormData();
  fd.set('name1', 'Baxtiyor Mengliyev');
  fd.set('name2', 'Бахтиёр Менглиев');
  fd.set('name3', 'Bakhtiyor Mengliyev');
  fd.set('about1', 'Olim');
  fd.set('about2', 'Учёный');
  fd.set('about3', 'Scholar');
  r = await api('POST', '/api/authors/create-author', { token: admin, form: fd });
  assert.equal(r.status, 201);
  const author = r.data.author;
  r = await api('GET', '/api/authors/get-authors?page=1&limit=50');
  assert.equal(r.data.authors[0].name.uz, 'Baxtiyor Mengliyev');

  // --- free book from Word
  const docx = await makeDocx();
  fd = new FormData();
  fd.set('title', 'Sinov kitobi');
  fd.set('description', 'Test');
  fd.set('author_id', String(author.id));
  fd.set('category_id', String(cat.id));
  fd.set('is_free', 'true');
  fd.set('price', '0');
  fd.set('file', new Blob([docx]), 'sinov.docx');
  r = await api('POST', '/api/books/create-book', { token: admin, form: fd });
  assert.equal(r.status, 201, JSON.stringify(r.data));
  const free = await waitReady(admin, r.data.book.id);
  assert.equal(free.conversion_status, 'ready', free.conversion_error);
  assert.ok(free.chapters >= 3, `chapters: ${free.chapters}`);
  assert.ok(free.conversion_report.toc.some((t) => /Birinchi bob/i.test(t.title)));

  r = await api('GET', '/api/books/my-books', { token: user.accessToken });
  assert.equal(r.data.books.length, 1);
  assert.equal(r.data.books[0].author.uz, 'Baxtiyor Mengliyev');
  assert.equal(r.data.books[0].has_access, true);

  r = await api('GET', `/api/books/${free.id}/package.zip`, { token: user.accessToken });
  assert.equal(r.status, 200);
  const pkg = await JSZip.loadAsync(r.data);
  assert.ok(pkg.file('book.js') && pkg.file('manifest.json'));
  const manifest = JSON.parse(await pkg.file('manifest.json').async('string'));
  assert.equal(manifest.title, 'Sinov kitobi');
  assert.equal(r.headers.get('x-package-version'), '1');

  r = await api('GET', `/api/books/${free.id}/package.zip`);
  assert.equal(r.status, 401, 'anonymous download refused');

  // web reader token
  r = await api('GET', `/api/books/${free.id}/read-token`, { token: user.accessToken });
  const rt = r.data.token;
  r = await api('GET', `/api/books/${free.id}/package/book.js?rt=${encodeURIComponent(rt)}`);
  assert.equal(r.status, 200);
  assert.ok(r.data.toString().startsWith('/* mbook'));
  r = await api('GET', `/api/books/${free.id}/package/../../../../ebook.sqlite?rt=${encodeURIComponent(rt)}`);
  assert.notEqual(r.status, 200, 'path traversal blocked');

  // reading sync
  r = await api('PUT', `/api/books/${free.id}/reading`, { token: user.accessToken, json: { position: { c: 2, b: 5, o: 10 }, percent: 0.4, bookmarks: [{ id: 'a' }], highlights: [], updatedAt: 1000 } });
  assert.equal(r.data.percent, 0.4);
  r = await api('PUT', `/api/books/${free.id}/reading`, { token: user.accessToken, json: { position: { c: 0, b: 0, o: 0 }, percent: 0.1, updatedAt: 500 } });
  assert.equal(r.data.position.c, 2, 'older update ignored');
  r = await api('GET', `/api/books/${free.id}/reading?rt=${encodeURIComponent(rt)}`);
  assert.equal(r.data.bookmarks.length, 1);

  // --- paid book: locked until payment approved
  fd = new FormData();
  fd.set('title', 'Pullik kitob');
  fd.set('is_free', 'false');
  fd.set('price', '50000');
  fd.set('file', new Blob([docx]), 'pullik.docx');
  r = await api('POST', '/api/books/create-book', { token: admin, form: fd });
  const paid = await waitReady(admin, r.data.book.id);
  r = await api('GET', '/api/books/get-books?page=1&limit=50&is_free=false', { token: user.accessToken });
  assert.equal(r.data.books.length, 1);
  assert.equal(r.data.books[0].has_access, false);
  r = await api('GET', `/api/books/${paid.id}/package.zip`, { token: user.accessToken });
  assert.equal(r.status, 403);

  r = await api('GET', '/api/references/contact/1', { token: user.accessToken });
  assert.equal(r.status, 200);
  r = await api('PUT', '/api/references/contact/1', { token: admin, json: { card_number: '8600 1234 5678 9012', name: 'Mengliyev B.', phone: '+998901234567' } });
  assert.equal(r.data.card_number, '8600 1234 5678 9012');

  fd = new FormData();
  fd.set('book_id', String(paid.id));
  fd.set('comment', 'Click orqali');
  fd.set('approved_at', '2025-10-22 10:00');
  fd.set('image', new Blob([Buffer.from([0xff, 0xd8, 0xff, 0xd9])], { type: 'image/jpeg' }), 'payment.jpg');
  r = await api('POST', '/api/payments/create-payment', { token: user.accessToken, form: fd });
  assert.equal(r.status, 201, JSON.stringify(r.data));
  r = await api('GET', '/api/payments/get-payments?page=1&limit=50', { token: admin });
  assert.equal(r.data.payments.length, 1);
  assert.equal(r.data.payments[0].status_id, 1);
  assert.equal(r.data.payments[0].amount, 50000);
  const payId = r.data.payments[0].id;
  r = await api('PUT', `/api/payments/update-payment/${payId}`, { token: admin, json: { status: 2, comment: 'Tasdiqlandi' } });
  assert.equal(r.data.payment.status_id, 2);

  r = await api('GET', `/api/books/${paid.id}/package.zip`, { token: user.accessToken });
  assert.equal(r.status, 200, 'unlocked after approval');
  r = await api('GET', '/api/books/my-books', { token: user.accessToken });
  assert.equal(r.data.books.length, 2);
  assert.ok(r.data.books.find((b) => b.id === paid.id).purchase_date);

  r = await api('GET', '/api/admin/stats', { token: admin });
  assert.equal(r.data.sales_total, 1);
  assert.equal(r.data.revenue_total, 50000);
  assert.equal(r.data.sales_series.length, 30);

  // reconvert bumps the package version
  r = await api('POST', `/api/books/${free.id}/reconvert`, { token: admin });
  const again = await waitReady(admin, free.id);
  assert.equal(again.package_version, 2);

  r = await api('DELETE', `/api/books/delete-book/${paid.id}`, { token: admin });
  assert.equal(r.status, 200);
});
