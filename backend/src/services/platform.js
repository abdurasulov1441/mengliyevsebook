'use strict';

// Platform rules shared by routes and payment callbacks: settings,
// notifications, fulfilling and refunding orders (purchase + author earnings).

const config = require('../config');
const { q, getSetting, setSetting } = require('../db');

function settings() {
  const s = getSetting('platform', {});
  return {
    commission_percent: s.commission_percent ?? config.platform.commissionPercent,
    payout_min: s.payout_min ?? config.platform.payoutMin,
    support_phone: s.support_phone ?? '+998 90 096 17 04',
    support_telegram: s.support_telegram ?? '',
  };
}

function saveSettings(patch) {
  const next = { ...settings(), ...patch };
  next.commission_percent = Math.min(90, Math.max(0, Number(next.commission_percent) || 0));
  next.payout_min = Math.max(0, Math.round(Number(next.payout_min) || 0));
  setSetting('platform', next);
  return next;
}

const isAdminPhone = (phone) => config.admin.phones.includes(String(phone || '').replace(/\D/g, ''));

function notify(userId, type, title, body = '', data = null) {
  if (!userId) return;
  q.run('INSERT INTO notifications (user_id, type, title, body, data) VALUES (?, ?, ?, ?, ?)', userId, type, title, body, data ? JSON.stringify(data) : null);
}

const period = (d = new Date()) => d.toISOString().slice(0, 7);
const som = (n) => `${Math.round(n).toLocaleString('ru-RU').replace(/,/g, ' ')} so'm`;

/**
 * Marks an order paid: unlocks the book for the buyer and books the author's
 * share (price minus platform commission). Idempotent.
 */
function fulfillOrder(orderId, provider) {
  return q.tx(() => {
    const order = q.get('SELECT * FROM orders WHERE id = ?', orderId);
    if (!order) throw new Error(`order ${orderId} not found`);
    if (order.status === 'paid') return order;
    const book = q.get('SELECT * FROM books WHERE id = ?', order.book_id);
    q.run("UPDATE orders SET status = 'paid', provider = COALESCE(?, provider), paid_at = datetime('now') WHERE id = ?", provider, order.id);
    q.run("INSERT INTO purchases (user_id, book_id, source, payment_id) VALUES (?, ?, 'payment', ?) ON CONFLICT DO NOTHING", order.user_id, order.book_id, order.id);
    q.run('UPDATE books SET sales_count = sales_count + 1 WHERE id = ?', order.book_id);
    const ownerId = book && book.owner_user_id;
    if (ownerId && ownerId !== order.user_id && order.amount > 0) {
      const pct = settings().commission_percent;
      const platformAmount = Math.round((order.amount * pct) / 100);
      const authorAmount = order.amount - platformAmount;
      q.run(
        'INSERT INTO earnings (author_user_id, order_id, book_id, gross, commission_percent, platform_amount, author_amount, period) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        ownerId, order.id, order.book_id, order.amount, pct, platformAmount, authorAmount, period()
      );
      notify(ownerId, 'sale', 'Kitobingiz sotildi', `«${book.title}» — +${som(authorAmount)} (komissiya ${pct}%)`, { book_id: book.id, order_id: order.id });
    }
    notify(order.user_id, 'purchase', 'Xarid muvaffaqiyatli', `«${book ? book.title : 'Kitob'}» kutubxonangizga qo'shildi`, { book_id: order.book_id });
    return q.get('SELECT * FROM orders WHERE id = ?', order.id);
  });
}

/** Payment reversed by the provider: take the book back and the earnings too. */
function refundOrder(orderId) {
  return q.tx(() => {
    const order = q.get('SELECT * FROM orders WHERE id = ?', orderId);
    if (!order || order.status !== 'paid') return order;
    q.run("UPDATE orders SET status = 'refunded', cancelled_at = datetime('now') WHERE id = ?", order.id);
    q.run("DELETE FROM purchases WHERE user_id = ? AND book_id = ? AND payment_id = ?", order.user_id, order.book_id, order.id);
    q.run('UPDATE books SET sales_count = MAX(0, sales_count - 1) WHERE id = ?', order.book_id);
    const e = q.get('SELECT * FROM earnings WHERE order_id = ? AND author_amount > 0', order.id);
    if (e) {
      q.run(
        'INSERT INTO earnings (author_user_id, order_id, book_id, gross, commission_percent, platform_amount, author_amount, period) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        e.author_user_id, order.id, e.book_id, -e.gross, e.commission_percent, -e.platform_amount, -e.author_amount, period()
      );
    }
    return q.get('SELECT * FROM orders WHERE id = ?', order.id);
  });
}

function cancelOrder(orderId) {
  q.run("UPDATE orders SET status = 'cancelled', cancelled_at = datetime('now') WHERE id = ? AND status = 'created'", orderId);
}

/** Author money: not yet in a payout, waiting in a payout, already paid. */
function authorBalance(userId) {
  const one = (sql, ...p) => q.get(sql, ...p).n;
  return {
    available: one('SELECT COALESCE(SUM(author_amount), 0) AS n FROM earnings WHERE author_user_id = ? AND payout_id IS NULL', userId),
    pending_payout: one("SELECT COALESCE(SUM(amount), 0) AS n FROM payouts WHERE author_user_id = ? AND status = 'pending'", userId),
    paid_total: one("SELECT COALESCE(SUM(amount), 0) AS n FROM payouts WHERE author_user_id = ? AND status = 'paid'", userId),
    earned_total: one('SELECT COALESCE(SUM(author_amount), 0) AS n FROM earnings WHERE author_user_id = ?', userId),
    this_month: one('SELECT COALESCE(SUM(author_amount), 0) AS n FROM earnings WHERE author_user_id = ? AND period = ?', userId, period()),
  };
}

/**
 * Monthly payouts: everything an author earned up to and including `upTo`
 * (YYYY-MM) that is not paid yet becomes one payout — if the card is
 * verified and the sum reaches the minimum; otherwise it carries over.
 */
function generatePayouts(upTo) {
  const min = settings().payout_min;
  const rows = q.all(
    `SELECT e.author_user_id AS uid, SUM(e.author_amount) AS total, a.card_number, a.card_holder, a.card_verified, a.status
     FROM earnings e LEFT JOIN author_profiles a ON a.user_id = e.author_user_id
     WHERE e.payout_id IS NULL AND e.period <= ? GROUP BY e.author_user_id`,
    upTo
  );
  const created = [];
  const skipped = [];
  for (const r of rows) {
    if (r.total <= 0) continue;
    if (!r.card_verified || r.status !== 'active') {
      skipped.push({ author_user_id: r.uid, amount: r.total, reason: 'card_not_verified' });
      continue;
    }
    if (r.total < min) {
      skipped.push({ author_user_id: r.uid, amount: r.total, reason: 'below_minimum' });
      continue;
    }
    q.tx(() => {
      const res = q.run('INSERT INTO payouts (author_user_id, period, amount, card_number, card_holder) VALUES (?, ?, ?, ?, ?)', r.uid, upTo, r.total, r.card_number, r.card_holder);
      q.run('UPDATE earnings SET payout_id = ? WHERE author_user_id = ? AND payout_id IS NULL AND period <= ?', res.lastInsertRowid, r.uid, upTo);
      created.push({ id: Number(res.lastInsertRowid), author_user_id: r.uid, amount: r.total });
    });
  }
  return { created, skipped, payout_min: min };
}

module.exports = { settings, saveSettings, isAdminPhone, notify, period, som, fulfillOrder, refundOrder, cancelOrder, authorBalance, generatePayouts };
