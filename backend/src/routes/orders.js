'use strict';

// Buying books: orders + Payme (Merchant API, JSON-RPC) + Click (SHOP API).
//
// Flow: app POST /api/orders {book_id} -> gets checkout links -> user pays in
// Payme/Click -> the provider calls our callback -> fulfillOrder() unlocks the
// book and books the author's share -> app sees status "paid".
//
// Merchant cabinet settings:
//   Payme endpoint: <PUBLIC_URL>/api/payments/payme   (account field: order_id)
//   Click prepare:  <PUBLIC_URL>/api/payments/click/prepare
//   Click complete: <PUBLIC_URL>/api/payments/click/complete

const crypto = require('crypto');
const express = require('express');
const config = require('../config');
const { q } = require('../db');
const { HttpError, wrap, toInt } = require('../util');
const { requireAuth } = require('../auth');
const { fulfillOrder, refundOrder, cancelOrder } = require('../services/platform');
const S = require('../serializers');

const router = express.Router();
const P = config.payments;

const paymeEnabled = () => !!(P.payme.merchantId && P.payme.key);
const clickEnabled = () => !!(P.click.serviceId && P.click.merchantId && P.click.secretKey);

function returnUrl(orderId) {
  return P.returnUrl ? P.returnUrl.replace('{order}', orderId) : `${config.publicUrl}/api/pay/return?order=${orderId}`;
}

function checkoutLinks(order) {
  const links = {};
  if (paymeEnabled()) {
    const base = P.payme.test ? 'https://checkout.test.paycom.uz/' : 'https://checkout.paycom.uz/';
    const params = `m=${P.payme.merchantId};ac.order_id=${order.id};a=${order.amount * 100};c=${returnUrl(order.id)}`;
    links.payme = base + Buffer.from(params).toString('base64');
  }
  if (clickEnabled()) {
    const u = new URL('https://my.click.uz/services/pay');
    u.searchParams.set('service_id', P.click.serviceId);
    u.searchParams.set('merchant_id', P.click.merchantId);
    u.searchParams.set('amount', String(order.amount));
    u.searchParams.set('transaction_param', String(order.id));
    u.searchParams.set('return_url', returnUrl(order.id));
    links.click = u.toString();
  }
  return links;
}

function orderOut(order) {
  return { ...S.order(order), checkout: order.status === 'created' ? checkoutLinks(order) : {}, demo: P.demo && order.status === 'created' };
}

router.get('/payments/methods', (_req, res) => {
  res.json({ payme: paymeEnabled(), click: clickEnabled(), demo: P.demo });
});

/** Create (or reuse) an order for a paid book. */
router.post('/orders', requireAuth, (req, res) => {
  const book = q.get('SELECT * FROM books WHERE id = ?', toInt(req.body.book_id));
  if (!book || book.status !== 'approved' || book.conversion_status !== 'ready') throw new HttpError(404, 'Kitob topilmadi');
  if (book.is_free) throw new HttpError(400, "Bu kitob bepul — «Kutubxonaga qo'shish» tugmasini bosing");
  if (book.owner_user_id === req.user.id) throw new HttpError(400, "O'z kitobingizni sotib olish shart emas");
  if (q.get('SELECT 1 FROM purchases WHERE user_id = ? AND book_id = ?', req.user.id, book.id)) throw new HttpError(400, 'Bu kitob allaqachon kutubxonangizda');
  // Reuse a fresh unpaid order with the same price.
  let order = q.get("SELECT * FROM orders WHERE user_id = ? AND book_id = ? AND status = 'created' AND amount = ? AND created_at > datetime('now', '-1 day') ORDER BY id DESC", req.user.id, book.id, book.price);
  if (!order) {
    const r = q.run('INSERT INTO orders (user_id, book_id, amount) VALUES (?, ?, ?)', req.user.id, book.id, book.price);
    order = q.get('SELECT * FROM orders WHERE id = ?', r.lastInsertRowid);
  }
  if (!paymeEnabled() && !clickEnabled() && !P.demo) throw new HttpError(503, "To'lov tizimi hali ulanmagan");
  res.status(201).json(orderOut({ ...order, book_title: book.title }));
});

router.get('/orders/:id', requireAuth, (req, res) => {
  const order = q.get('SELECT o.*, b.title AS book_title FROM orders o JOIN books b ON b.id = o.book_id WHERE o.id = ? AND o.user_id = ?', toInt(req.params.id), req.user.id);
  if (!order) throw new HttpError(404, 'Buyurtma topilmadi');
  res.json(orderOut(order));
});

router.get('/me/orders', requireAuth, (req, res) => {
  const rows = q.all("SELECT o.*, b.title AS book_title FROM orders o JOIN books b ON b.id = o.book_id WHERE o.user_id = ? AND o.status <> 'created' ORDER BY o.id DESC LIMIT 100", req.user.id);
  res.json({ orders: rows.map(S.order) });
});

/** Development / until merchant keys exist: pay without a provider. */
router.post('/orders/:id/demo-pay', requireAuth, (req, res) => {
  if (!P.demo) throw new HttpError(403, "Demo to'lov o'chirilgan");
  const order = q.get("SELECT * FROM orders WHERE id = ? AND user_id = ?", toInt(req.params.id), req.user.id);
  if (!order) throw new HttpError(404, 'Buyurtma topilmadi');
  if (order.status !== 'created' && order.status !== 'paid') throw new HttpError(400, 'Buyurtma bekor qilingan');
  fulfillOrder(order.id, 'demo');
  res.json(orderOut(q.get('SELECT o.*, b.title AS book_title FROM orders o JOIN books b ON b.id = o.book_id WHERE o.id = ?', order.id)));
});

// Page the provider sends the user back to.
router.get('/pay/return', (req, res) => {
  const order = q.get('SELECT status FROM orders WHERE id = ?', toInt(req.query.order));
  const ok = order && order.status === 'paid';
  res.type('html').send(`<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>BookHub</title>
<body style="font-family:system-ui;background:#f5f6fa;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0">
<div style="text-align:center;padding:32px;max-width:340px"><div style="font-size:56px">${ok ? '✅' : '⏳'}</div>
<h2 style="color:#0a2f73">${ok ? "To'lov qabul qilindi" : "To'lov tekshirilmoqda"}</h2>
<p style="color:#555">BookHub ilovasiga qayting — kitob kutubxonangizda.</p></div></body>`);
});

// ====================================================================== Payme
// https://developer.help.paycom.uz/protokol-merchant-api
const PAYME_TIMEOUT = 12 * 60 * 60 * 1000;
const PaymeError = {
  Auth: { code: -32504, message: { uz: "Ruxsat yo'q", ru: 'Недостаточно привилегий', en: 'Insufficient privileges' } },
  Method: { code: -32601, message: { uz: 'Metod topilmadi', ru: 'Метод не найден', en: 'Method not found' } },
  Amount: { code: -31001, message: { uz: "Noto'g'ri summa", ru: 'Неверная сумма', en: 'Incorrect amount' } },
  TxNotFound: { code: -31003, message: { uz: 'Tranzaksiya topilmadi', ru: 'Транзакция не найдена', en: 'Transaction not found' } },
  CantCancel: { code: -31007, message: { uz: 'Bekor qilib bo‘lmaydi', ru: 'Невозможно отменить транзакцию', en: 'Unable to cancel transaction' } },
  CantPerform: { code: -31008, message: { uz: 'Amalni bajarib bo‘lmaydi', ru: 'Невозможно выполнить операцию', en: 'Unable to perform operation' } },
  Order: { code: -31050, message: { uz: 'Buyurtma topilmadi', ru: 'Заказ не найден', en: 'Order not found' }, data: 'order_id' },
  OrderBusy: { code: -31051, message: { uz: "Buyurtma uchun to'lov kutilmoqda", ru: 'Заказ ожидает оплаты', en: 'Order is busy' }, data: 'order_id' },
};

class PaymeFail extends Error {
  constructor(e) {
    super(e.message.en);
    this.e = e;
  }
}

function paymeAuthorized(req) {
  const h = req.headers.authorization || '';
  if (!h.startsWith('Basic ')) return false;
  const [login, key] = Buffer.from(h.slice(6), 'base64').toString().split(':');
  return login === 'Paycom' && key && P.payme.key && crypto.timingSafeEqual(Buffer.from(key.padEnd(64)), Buffer.from(P.payme.key.padEnd(64)));
}

function paymeOrder(params) {
  const order = q.get('SELECT * FROM orders WHERE id = ?', toInt(params.account && params.account.order_id));
  if (!order || order.status !== 'created') throw new PaymeFail(PaymeError.Order);
  if (toInt(params.amount) !== order.amount * 100) throw new PaymeFail(PaymeError.Amount);
  return order;
}

const txOut = (t) => ({ create_time: t.create_time, perform_time: t.perform_time, cancel_time: t.cancel_time, transaction: String(t.id), state: t.state, reason: t.reason ?? null });
const getTx = (id) => q.get("SELECT * FROM payment_transactions WHERE provider = 'payme' AND provider_tx_id = ?", String(id));

const payme = {
  CheckPerformTransaction(p) {
    paymeOrder(p);
    return { allow: true };
  },
  CreateTransaction(p) {
    const existing = getTx(p.id);
    if (existing) {
      if (existing.state !== 1) throw new PaymeFail(PaymeError.CantPerform);
      if (Date.now() - existing.create_time > PAYME_TIMEOUT) {
        q.run('UPDATE payment_transactions SET state = -1, reason = 4, cancel_time = ? WHERE id = ?', Date.now(), existing.id);
        cancelOrder(existing.order_id);
        throw new PaymeFail(PaymeError.CantPerform);
      }
      return { create_time: existing.create_time, transaction: String(existing.id), state: existing.state };
    }
    const order = paymeOrder(p);
    const busy = q.get("SELECT 1 FROM payment_transactions WHERE provider = 'payme' AND order_id = ? AND state = 1", order.id);
    if (busy) throw new PaymeFail(PaymeError.OrderBusy);
    const r = q.run("INSERT INTO payment_transactions (order_id, provider, provider_tx_id, state, amount, create_time) VALUES (?, 'payme', ?, 1, ?, ?)", order.id, String(p.id), toInt(p.amount), toInt(p.time) || Date.now());
    const t = q.get('SELECT * FROM payment_transactions WHERE id = ?', r.lastInsertRowid);
    return { create_time: t.create_time, transaction: String(t.id), state: 1 };
  },
  PerformTransaction(p) {
    const t = getTx(p.id);
    if (!t) throw new PaymeFail(PaymeError.TxNotFound);
    if (t.state === 2) return { transaction: String(t.id), perform_time: t.perform_time, state: 2 };
    if (t.state !== 1) throw new PaymeFail(PaymeError.CantPerform);
    if (Date.now() - t.create_time > PAYME_TIMEOUT) {
      q.run('UPDATE payment_transactions SET state = -1, reason = 4, cancel_time = ? WHERE id = ?', Date.now(), t.id);
      cancelOrder(t.order_id);
      throw new PaymeFail(PaymeError.CantPerform);
    }
    const now = Date.now();
    fulfillOrder(t.order_id, 'payme');
    q.run('UPDATE payment_transactions SET state = 2, perform_time = ? WHERE id = ?', now, t.id);
    return { transaction: String(t.id), perform_time: now, state: 2 };
  },
  CancelTransaction(p) {
    const t = getTx(p.id);
    if (!t) throw new PaymeFail(PaymeError.TxNotFound);
    if (t.state < 0) return { transaction: String(t.id), cancel_time: t.cancel_time, state: t.state };
    const now = Date.now();
    if (t.state === 1) {
      q.run('UPDATE payment_transactions SET state = -1, reason = ?, cancel_time = ? WHERE id = ?', toInt(p.reason), now, t.id);
      cancelOrder(t.order_id);
      return { transaction: String(t.id), cancel_time: now, state: -1 };
    }
    // Performed -> refund: the book is taken back from the buyer.
    refundOrder(t.order_id);
    q.run('UPDATE payment_transactions SET state = -2, reason = ?, cancel_time = ? WHERE id = ?', toInt(p.reason), now, t.id);
    return { transaction: String(t.id), cancel_time: now, state: -2 };
  },
  CheckTransaction(p) {
    const t = getTx(p.id);
    if (!t) throw new PaymeFail(PaymeError.TxNotFound);
    return txOut(t);
  },
  GetStatement(p) {
    const rows = q.all("SELECT * FROM payment_transactions WHERE provider = 'payme' AND create_time BETWEEN ? AND ? ORDER BY create_time", toInt(p.from), toInt(p.to));
    return {
      transactions: rows.map((t) => ({ id: t.provider_tx_id, time: t.create_time, amount: t.amount, account: { order_id: String(t.order_id) }, ...txOut(t) })),
    };
  },
};

router.post('/payments/payme', express.json(), (req, res) => {
  const { method, params = {}, id } = req.body || {};
  const fail = (e) => res.json({ error: { code: e.code, message: e.message, data: e.data }, id });
  if (!paymeAuthorized(req)) return fail(PaymeError.Auth);
  const fn = payme[method];
  if (!fn) return fail(PaymeError.Method);
  try {
    res.json({ result: fn(params), id });
  } catch (e) {
    if (e instanceof PaymeFail) return fail(e.e);
    console.error('[payme]', e);
    fail({ code: -32400, message: { uz: 'Tizim xatosi', ru: 'Системная ошибка', en: 'System error' } });
  }
});

// ====================================================================== Click
// https://docs.click.uz/click-api-request/
const md5 = (s) => crypto.createHash('md5').update(s).digest('hex');

function clickSignOk(b, withPrepare) {
  const parts = [b.click_trans_id, b.service_id, P.click.secretKey, b.merchant_trans_id];
  if (withPrepare) parts.push(b.merchant_prepare_id);
  parts.push(b.amount, b.action, b.sign_time);
  return String(b.sign_string || '').toLowerCase() === md5(parts.join(''));
}

const clickReply = (res, b, error, note, extra = {}) =>
  res.json({ click_trans_id: b.click_trans_id, merchant_trans_id: b.merchant_trans_id, error, error_note: note, ...extra });

router.post('/payments/click/prepare', express.urlencoded({ extended: false }), (req, res) => {
  const b = req.body || {};
  if (!clickEnabled() || !clickSignOk(b, false)) return clickReply(res, b, -1, 'SIGN CHECK FAILED!');
  if (toInt(b.action) !== 0) return clickReply(res, b, -3, 'Action not found');
  const order = q.get('SELECT * FROM orders WHERE id = ?', toInt(b.merchant_trans_id));
  if (!order) return clickReply(res, b, -5, 'User does not exist');
  if (order.status === 'paid') return clickReply(res, b, -4, 'Already paid');
  if (order.status !== 'created') return clickReply(res, b, -9, 'Transaction cancelled');
  if (Math.round(Number(b.amount)) !== order.amount) return clickReply(res, b, -2, 'Incorrect parameter amount');
  const existing = q.get("SELECT * FROM payment_transactions WHERE provider = 'click' AND provider_tx_id = ?", String(b.click_trans_id));
  const prepareId = existing
    ? existing.id
    : q.run("INSERT INTO payment_transactions (order_id, provider, provider_tx_id, state, amount, create_time, extra) VALUES (?, 'click', ?, 1, ?, ?, ?)", order.id, String(b.click_trans_id), order.amount, Date.now(), JSON.stringify({ paydoc: b.click_paydoc_id })).lastInsertRowid;
  clickReply(res, b, 0, 'Success', { merchant_prepare_id: Number(prepareId) });
});

router.post('/payments/click/complete', express.urlencoded({ extended: false }), (req, res) => {
  const b = req.body || {};
  if (!clickEnabled() || !clickSignOk(b, true)) return clickReply(res, b, -1, 'SIGN CHECK FAILED!');
  if (toInt(b.action) !== 1) return clickReply(res, b, -3, 'Action not found');
  const t = q.get("SELECT * FROM payment_transactions WHERE provider = 'click' AND id = ?", toInt(b.merchant_prepare_id));
  if (!t || t.provider_tx_id !== String(b.click_trans_id)) return clickReply(res, b, -6, 'Transaction does not exist');
  const order = q.get('SELECT * FROM orders WHERE id = ?', t.order_id);
  if (!order || String(order.id) !== String(b.merchant_trans_id)) return clickReply(res, b, -5, 'User does not exist');
  if (t.state === 2 || order.status === 'paid') return clickReply(res, b, -4, 'Already paid', { merchant_confirm_id: t.id });
  if (Math.round(Number(b.amount)) !== order.amount) return clickReply(res, b, -2, 'Incorrect parameter amount');
  // Click reports a failed payment with error < 0.
  if (toInt(b.error) < 0) {
    q.run('UPDATE payment_transactions SET state = -1, cancel_time = ? WHERE id = ?', Date.now(), t.id);
    cancelOrder(order.id);
    return clickReply(res, b, -9, 'Transaction cancelled');
  }
  fulfillOrder(order.id, 'click');
  q.run('UPDATE payment_transactions SET state = 2, perform_time = ? WHERE id = ?', Date.now(), t.id);
  clickReply(res, b, 0, 'Success', { merchant_confirm_id: t.id });
});

module.exports = router;
