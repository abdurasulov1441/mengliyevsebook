'use strict';

// JSON shapes returned by the API. File paths are relative ("/covers/x.jpg");
// clients prefix "<host>/_files". *_url fields carry the absolute address.

const config = require('./config');
const { formatPhone, parseJson } = require('./util');

const fileUrl = (rel) => (rel ? `${config.publicUrl}/_files${rel}` : null);

function category(row) {
  return {
    id: row.id,
    name: { uz: row.name_uz || '', ru: row.name_ru || '', en: row.name_en || '' },
    books_count: row.books_count ?? undefined,
  };
}

// Books with category and the uploader's author profile.
const BOOK_SELECT = `
  SELECT b.*, c.name_uz AS c_uz, c.name_ru AS c_ru, c.name_en AS c_en,
         ap.display_name AS owner_name, ap.photo AS owner_photo
  FROM books b
  LEFT JOIN categories c ON c.id = b.category_id
  LEFT JOIN author_profiles ap ON ap.user_id = b.owner_user_id`;

function book(row, extra = {}) {
  const ready = row.conversion_status === 'ready';
  const out = {
    id: row.id,
    title: row.title,
    description: row.description,
    author_name: row.author_name || row.owner_name || '',
    // `author` keeps the shape older clients read (author.uz)
    author: { uz: row.author_name || row.owner_name || '' },
    owner: row.owner_user_id ? { user_id: row.owner_user_id, name: row.owner_name || '', photo: row.owner_photo || null } : null,
    category_id: row.category_id,
    category: row.category_id ? { uz: row.c_uz || '', ru: row.c_ru || '', en: row.c_en || '' } : null,
    price: row.price,
    is_free: !!row.is_free,
    photo: row.photo || null,
    photo_url: fileUrl(row.photo),
    lang: row.lang,
    chapters: row.chapters,
    words: row.words,
    reading_minutes: row.words ? Math.max(1, Math.round(row.words / 180)) : 0,
    rating: Math.round((row.rating_avg || 0) * 10) / 10,
    rating_count: row.rating_count || 0,
    sales_count: row.sales_count || 0,
    status: row.status,
    is_ready: ready,
    package_version: row.package_version,
    published_at: row.published_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
  if (extra.owner || extra.admin) {
    Object.assign(out, {
      conversion_status: row.conversion_status,
      conversion_error: row.conversion_error,
      conversion_report: parseJson(row.conversion_report, null),
      rejection_reason: row.rejection_reason,
      submitted_at: row.submitted_at,
      reviewed_at: row.reviewed_at,
      source_name: row.source_name,
    });
  }
  return Object.assign(out, extra.fields || {});
}

function authorProfile(row, { full } = {}) {
  if (!row) return null;
  const out = {
    user_id: row.user_id,
    display_name: row.display_name,
    bio: row.bio,
    photo: row.photo || null,
    photo_url: fileUrl(row.photo),
    status: row.status,
    books_count: row.books_count ?? undefined,
    created_at: row.created_at,
  };
  if (full) {
    // Card number is shown masked except to admins.
    out.card_number = row.card_number;
    out.card_holder = row.card_holder;
    out.card_verified = !!row.card_verified;
    out.admin_note = row.admin_note;
    out.phone = row.phone_number ? formatPhone(row.phone_number) : undefined;
  }
  return out;
}

const maskCard = (c) => (c && c.replace(/\D/g, '').length >= 8 ? c.replace(/\D/g, '').replace(/^(\d{4})\d+(\d{4})$/, '$1 •••• •••• $2') : c || '');

function user(row, extra = {}) {
  return {
    id: row.id,
    name: row.name,
    phone_number: formatPhone(row.phone_number),
    phone: row.phone_number,
    role_id: row.role_id,
    is_admin: row.role_id === 1,
    avatar: row.avatar || null,
    is_blocked: !!row.is_blocked,
    created_at: row.created_at,
    last_login_at: row.last_login_at,
    ...extra,
  };
}

function order(row) {
  return {
    id: row.id,
    book_id: row.book_id,
    book_title: row.book_title,
    user_id: row.user_id,
    user_name: row.user_name,
    phone_number: row.phone_number ? formatPhone(row.phone_number) : undefined,
    amount: row.amount,
    status: row.status,
    provider: row.provider,
    created_at: row.created_at,
    paid_at: row.paid_at,
  };
}

function payout(row) {
  return {
    id: row.id,
    author_user_id: row.author_user_id,
    author_name: row.author_name,
    period: row.period,
    amount: row.amount,
    status: row.status,
    card_number: row.card_number,
    card_holder: row.card_holder,
    reference: row.reference,
    created_at: row.created_at,
    paid_at: row.paid_at,
  };
}

function review(row) {
  return { id: row.id, user_id: row.user_id, user_name: row.user_name || 'Kitobxon', rating: row.rating, text: row.text, created_at: row.created_at, updated_at: row.updated_at };
}

function notification(row) {
  return { id: row.id, type: row.type, title: row.title, body: row.body, data: parseJson(row.data, null), read: !!row.read_at, created_at: row.created_at };
}

module.exports = { category, book, authorProfile, user, order, payout, review, notification, maskCard, BOOK_SELECT, fileUrl };
