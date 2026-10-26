'use strict';

// End-to-end test of the BookHub platform on a throw-away data folder:
//   npm test
// Author applies -> uploads Word -> moderation (reject, fix, approve) ->
// readers buy with demo / Payme / Click -> commission and payouts.

const test = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');
const os = require('os');
const fs = require('fs');
const path = require('path');
const JSZip = require('jszip');

const DATA = fs.mkdtempSync(path.join(os.tmpdir(), 'bookhub-test-'));
Object.assign(process.env, {
  DATA_DIR: DATA,
  NODE_ENV: 'test',
  DEV_OTP_CODE: '111111',
  SMS_LOGIN: '',
  JWT_SECRET: 'test-secret',
  ADMIN_PHONES: '998900961704',
  PAYMENTS_DEMO: 'true',
  PAYME_MERCHANT_ID: 'merchant-test',
  PAYME_KEY: 'payme-secret-key',
  CLICK_SERVICE_ID: '111',
  CLICK_MERCHANT_ID: '222',
  CLICK_SECRET_KEY: 'click-secret',
  COMMISSION_PERCENT: '30',
  PAYOUT_MIN: '10000',
});

const { createApp } = require('../src/app');

async function makeDocx(title) {
  const p = (text, { bold, size, center, pageBreak } = {}) =>
    `<w:p><w:pPr>${center ? '<w:jc w:val="center"/>' : ''}</w:pPr>${pageBreak ? '<w:r><w:br w:type="page"/></w:r>' : ''}<w:r><w:rPr>${bold ? '<w:b/>' : ''}<w:sz w:val="${size || 28}"/></w:rPr><w:t xml:space="preserve">${text}</w:t></w:r></w:p>`;
  const body = [
    p(title.toUpperCase(), { bold: true, size: 56, center: true }),
    p('Toshkent - 2025', { bold: true, center: true }),
    p('KIRISH', { bold: true, size: 40, center: true, pageBreak: true }),
    ...Array.from({ length: 30 }, (_, i) => p(`Kirish matni ${i}. Bu sinov uchun yozilgan oddiy paragraf bo‘lib, kitob o‘qish dasturini tekshiradi.`)),
    p('BIRINCHI BOB', { bold: true, size: 40, center: true, pageBreak: true }),
    ...Array.from({ length: 40 }, (_, i) => p(`Birinchi bob matni ${i}. Matn yetarlicha uzun bo‘lishi kerak, shunda boblar to‘g‘ri ajratiladi.`)),
    p('IKKINCHI BOB', { bold: true, size: 40, center: true, pageBreak: true }),
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

async function api(method, url, { token, json, form, headers = {}, raw } = {}) {
  const h = { ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  let body;
  if (json) {
    h['Content-Type'] = 'application/json';
    body = JSON.stringify(json);
  } else if (form) body = form;
  else if (raw) {
    h['Content-Type'] = 'application/x-www-form-urlencoded';
    body = raw;
  }
  const res = await fetch(base + url, { method, headers: h, body });
  const type = res.headers.get('content-type') || '';
  return { status: res.status, data: type.includes('json') ? await res.json() : Buffer.from(await res.arrayBuffer()), headers: res.headers };
}

async function login(phone, name) {
  let r = await api('POST', '/api/auth/request-otp', { json: { phone } });
  assert.equal(r.status, 200, JSON.stringify(r.data));
  r = await api('POST', '/api/auth/verify', { json: { phone, code: '111111', name } });
  assert.equal(r.status, 200, JSON.stringify(r.data));
  return r.data;
}

async function waitReady(token, id) {
  for (let i = 0; i < 100; i++) {
    const r = await api('GET', `/api/studio/books/${id}`, { token });
    if (['ready', 'failed'].includes(r.data.conversion_status)) return r.data;
    await new Promise((res) => setTimeout(res, 100));
  }
  throw new Error('conversion timeout');
}

async function uploadBook(token, { title, price, isFree = false }) {
  const fd = new FormData();
  fd.set('title', title);
  fd.set('description', `${title} haqida`);
  fd.set('is_free', String(isFree));
  fd.set('price', String(price || 0));
  fd.set('file', new Blob([await makeDocx(title)]), `${title}.docx`);
  const r = await api('POST', '/api/studio/books', { token, form: fd });
  assert.equal(r.status, 201, JSON.stringify(r.data));
  const ready = await waitReady(token, r.data.book.id);
  assert.equal(ready.conversion_status, 'ready', ready.conversion_error);
  return ready;
}

const payme = (method, params) =>
  api('POST', '/api/payments/payme', {
    json: { method, params, id: Date.now() },
    headers: { Authorization: 'Basic ' + Buffer.from('Paycom:payme-secret-key').toString('base64') },
  });

const md5 = (s) => crypto.createHash('md5').update(s).digest('hex');

test('BookHub: authors, moderation, sales, commission, payouts', async () => {
  // --- admin by phone number
  const admin = await login('+998 90 096 17 04', 'Admin');
  assert.equal(admin.user.role_id, 1);
  assert.equal(admin.user.is_admin, true);

  // categories
  let r = await api('POST', '/api/admin/categories', { token: admin.accessToken, json: { name_uz: 'Ilmiy', name_ru: 'Научные' } });
  assert.equal(r.status, 201);
  const cat = r.data;

  // --- author applies
  const author = await login('+998 91 111 11 11');
  assert.equal(author.user.needs_name, true);
  r = await api('PUT', '/api/me', { token: author.accessToken, form: (() => { const f = new FormData(); f.set('name', 'Baxtiyor Mengliyev'); return f; })() });
  assert.equal(r.data.name, 'Baxtiyor Mengliyev');
  r = await api('POST', '/api/studio/books', { token: author.accessToken, form: new FormData() });
  assert.equal(r.status, 403, 'not an author yet');
  let fd = new FormData();
  fd.set('display_name', 'Baxtiyor Mengliyev');
  fd.set('bio', 'Filologiya fanlari doktori');
  fd.set('card_number', '8600 1234 5678 9012');
  fd.set('card_holder', 'BAXTIYOR MENGLIYEV');
  r = await api('PUT', '/api/studio/profile', { token: author.accessToken, form: fd });
  assert.equal(r.status, 400, 'terms must be accepted');
  fd.set('accept_terms', 'true');
  r = await api('PUT', '/api/studio/profile', { token: author.accessToken, form: fd });
  assert.equal(r.status, 200, JSON.stringify(r.data));
  assert.equal(r.data.profile.card_verified, false);

  // --- upload -> pending; not visible in the shop yet
  const book = await uploadBook(author.accessToken, { title: 'Dissertatsiya yozish', price: 50000 });
  assert.equal(book.status, 'pending');
  r = await api('GET', '/api/books');
  assert.equal(r.data.books.length, 0, 'pending books are hidden');

  // --- moderation: reject, fix, approve
  r = await api('GET', '/api/admin/books?status=pending', { token: admin.accessToken });
  assert.equal(r.data.books.length, 1);
  r = await api('POST', `/api/admin/books/${book.id}/reject`, { token: admin.accessToken, json: {} });
  assert.equal(r.status, 400, 'reason required');
  r = await api('POST', `/api/admin/books/${book.id}/reject`, { token: admin.accessToken, json: { reason: 'Kategoriyani tanlang' } });
  assert.equal(r.data.book.status, 'rejected');
  r = await api('GET', '/api/me/notifications', { token: author.accessToken });
  assert.ok(r.data.notifications.some((n) => n.type === 'moderation' && /Kategoriyani/.test(n.body)));
  fd = new FormData();
  fd.set('category_id', String(cat.id));
  r = await api('PUT', `/api/studio/books/${book.id}`, { token: author.accessToken, form: fd });
  assert.equal(r.data.book.status, 'pending', 'rejected book goes back to moderation');
  r = await api('POST', `/api/admin/books/${book.id}/approve`, { token: admin.accessToken });
  assert.equal(r.data.book.status, 'approved');

  r = await api('GET', '/api/books?q=Dissertatsiya');
  assert.equal(r.data.books.length, 1);
  r = await api('GET', '/api/home');
  assert.ok(r.data.sections.some((s) => s.key === 'new'));
  assert.equal(r.data.authors[0].display_name, 'Baxtiyor Mengliyev');

  // sample chapters for everyone
  r = await api('GET', `/api/books/${book.id}/preview.js`);
  assert.equal(r.status, 200);
  assert.ok(r.data.toString().includes('"preview":true'));

  // --- reader 1 buys with demo payment
  const reader = await login('+998 93 333 33 33', 'Ali');
  r = await api('GET', `/api/books/${book.id}/package.zip`, { token: reader.accessToken });
  assert.equal(r.status, 403, 'locked before payment');
  r = await api('POST', '/api/orders', { token: reader.accessToken, json: { book_id: book.id } });
  assert.equal(r.status, 201);
  assert.ok(r.data.checkout.payme.startsWith('https://checkout.test.paycom.uz/'));
  assert.ok(r.data.checkout.click.includes('transaction_param='));
  r = await api('POST', `/api/orders/${r.data.id}/demo-pay`, { token: reader.accessToken });
  assert.equal(r.data.status, 'paid');
  r = await api('GET', `/api/books/${book.id}/package.zip`, { token: reader.accessToken });
  assert.equal(r.status, 200);
  r = await api('GET', '/api/me/library', { token: reader.accessToken });
  assert.equal(r.data.books.length, 1);

  // review -> rating
  r = await api('POST', `/api/books/${book.id}/reviews`, { token: reader.accessToken, json: { rating: 5, text: 'Ajoyib' } });
  assert.equal(r.status, 200);
  r = await api('GET', `/api/books/${book.id}`, { token: reader.accessToken });
  assert.equal(r.data.rating, 5);
  assert.equal(r.data.has_access, true);
  assert.equal(r.data.my_review.text, 'Ajoyib');

  // favorites
  r = await api('POST', `/api/books/${book.id}/favorite`, { token: reader.accessToken });
  assert.equal(r.data.is_favorite, true);

  // --- reader 2 pays with Payme (full Merchant API cycle)
  const reader2 = await login('+998 94 444 44 44', 'Vali');
  const order2 = (await api('POST', '/api/orders', { token: reader2.accessToken, json: { book_id: book.id } })).data;
  r = await api('POST', '/api/payments/payme', { json: { method: 'CheckPerformTransaction', params: {}, id: 1 } });
  assert.equal(r.data.error.code, -32504, 'auth required');
  r = await payme('CheckPerformTransaction', { amount: 5000000, account: { order_id: String(order2.id) } });
  assert.equal(r.data.result.allow, true);
  r = await payme('CheckPerformTransaction', { amount: 100, account: { order_id: String(order2.id) } });
  assert.equal(r.data.error.code, -31001, 'wrong amount');
  r = await payme('CreateTransaction', { id: 'payme-tx-1', time: Date.now(), amount: 5000000, account: { order_id: String(order2.id) } });
  assert.equal(r.data.result.state, 1);
  r = await payme('PerformTransaction', { id: 'payme-tx-1' });
  assert.equal(r.data.result.state, 2);
  r = await api('GET', `/api/orders/${order2.id}`, { token: reader2.accessToken });
  assert.equal(r.data.status, 'paid');
  r = await payme('CheckTransaction', { id: 'payme-tx-1' });
  assert.equal(r.data.result.state, 2);
  // refund after perform takes the book back
  r = await payme('CancelTransaction', { id: 'payme-tx-1', reason: 5 });
  assert.equal(r.data.result.state, -2);
  r = await api('GET', `/api/books/${book.id}/package.zip`, { token: reader2.accessToken });
  assert.equal(r.status, 403, 'refunded');

  // --- reader 3 pays with Click (prepare + complete with signatures)
  const reader3 = await login('+998 95 555 55 55', 'Gulnoza');
  const order3 = (await api('POST', '/api/orders', { token: reader3.accessToken, json: { book_id: book.id } })).data;
  const t = { click_trans_id: '9001', service_id: '111', click_paydoc_id: '77', merchant_trans_id: String(order3.id), amount: '50000', sign_time: '2026-10-26 12:00:00' };
  const prep = { ...t, action: '0', error: '0', error_note: 'Success' };
  prep.sign_string = md5(prep.click_trans_id + prep.service_id + 'click-secret' + prep.merchant_trans_id + prep.amount + prep.action + prep.sign_time);
  r = await api('POST', '/api/payments/click/prepare', { raw: new URLSearchParams({ ...prep, sign_string: 'bad' }).toString() });
  assert.equal(r.data.error, -1, 'bad signature');
  r = await api('POST', '/api/payments/click/prepare', { raw: new URLSearchParams(prep).toString() });
  assert.equal(r.data.error, 0, JSON.stringify(r.data));
  const comp = { ...t, action: '1', error: '0', error_note: 'Success', merchant_prepare_id: String(r.data.merchant_prepare_id) };
  comp.sign_string = md5(comp.click_trans_id + comp.service_id + 'click-secret' + comp.merchant_trans_id + comp.merchant_prepare_id + comp.amount + comp.action + comp.sign_time);
  r = await api('POST', '/api/payments/click/complete', { raw: new URLSearchParams(comp).toString() });
  assert.equal(r.data.error, 0, JSON.stringify(r.data));
  r = await api('GET', `/api/orders/${order3.id}`, { token: reader3.accessToken });
  assert.equal(r.data.status, 'paid');

  // --- author money: 2 sales kept (demo + click), payme refunded => 2 * 35 000
  r = await api('GET', '/api/studio/dashboard', { token: author.accessToken });
  assert.equal(r.data.balance.available, 70000, JSON.stringify(r.data.balance));
  assert.equal(r.data.commission_percent, 30);
  r = await api('GET', '/api/admin/stats', { token: admin.accessToken });
  assert.equal(r.data.commission_total, 30000);

  // payouts need a verified card
  const month = new Date().toISOString().slice(0, 7);
  r = await api('POST', '/api/admin/payouts/generate', { token: admin.accessToken, json: { period: month } });
  assert.equal(r.data.created.length, 0);
  assert.equal(r.data.skipped[0].reason, 'card_not_verified');
  r = await api('PUT', `/api/admin/authors/${author.user.id}`, { token: admin.accessToken, json: { card_verified: true } });
  assert.equal(r.data.author.card_verified, true);
  r = await api('POST', '/api/admin/payouts/generate', { token: admin.accessToken, json: { period: month } });
  assert.equal(r.data.created.length, 1);
  assert.equal(r.data.created[0].amount, 70000);
  const payoutId = r.data.created[0].id;
  r = await api('POST', `/api/admin/payouts/${payoutId}/mark-paid`, { token: admin.accessToken, json: { reference: 'P2P-123' } });
  assert.equal(r.status, 200);
  r = await api('GET', '/api/studio/payouts', { token: author.accessToken });
  assert.equal(r.data.payouts[0].status, 'paid');
  assert.equal(r.data.balance.available, 0);
  assert.equal(r.data.balance.paid_total, 70000);

  // --- free book -> library without payment
  const free = await uploadBook(author.accessToken, { title: 'Bepul qollanma', isFree: true });
  await api('POST', `/api/admin/books/${free.id}/approve`, { token: admin.accessToken });
  r = await api('POST', `/api/books/${free.id}/get`, { token: reader2.accessToken });
  assert.equal(r.status, 200);
  r = await api('GET', `/api/books/${free.id}/package.zip`, { token: reader2.accessToken });
  assert.equal(r.status, 200);

  // author can hide a book; buyers keep access
  r = await api('POST', `/api/studio/books/${book.id}/unpublish`, { token: author.accessToken });
  assert.equal(r.data.book.status, 'unpublished');
  r = await api('GET', `/api/books/${book.id}/package.zip`, { token: reader.accessToken });
  assert.equal(r.status, 200, 'buyers keep a hidden book');
  r = await api('GET', `/api/books/${book.id}`);
  assert.equal(r.status, 404, 'hidden from the shop');
  await api('POST', `/api/studio/books/${book.id}/publish`, { token: author.accessToken });

  // swagger
  r = await api('GET', '/api/openapi.json');
  assert.ok(Object.keys(r.data.paths).length > 50);
  r = await api('GET', '/api/docs');
  assert.ok(r.data.toString().includes('swagger-ui-bundle.js'));
});
