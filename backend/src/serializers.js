'use strict';

// Response shapes match what the Flutter app already reads
// (lib/pages/**): e.g. category.name.uz, author.about.ru, book.author.uz,
// payment.status.uz. Photo paths are relative: the app prefixes "<host>/_files".

const config = require('./config');
const { formatPhone, parseJson } = require('./util');

const i18n = (row, prefix) => ({ uz: row[`${prefix}_uz`] || '', ru: row[`${prefix}_ru`] || '', en: row[`${prefix}_en`] || '', oz: row[`${prefix}_uz`] || '' });
const fileUrl = (rel) => (rel ? `${config.publicUrl}/_files${rel}` : null);

function category(row) {
  return {
    id: row.id,
    name: i18n(row, 'name'),
    name1: row.name_uz,
    name2: row.name_ru,
    name3: row.name_en,
    books_count: row.books_count ?? undefined,
    created_at: row.created_at,
  };
}

function author(row) {
  return {
    id: row.id,
    name: i18n(row, 'name'),
    about: i18n(row, 'about'),
    name1: row.name_uz,
    name2: row.name_ru,
    name3: row.name_en,
    about1: row.about_uz,
    about2: row.about_ru,
    about3: row.about_en,
    photo: row.photo || null,
    photo_url: fileUrl(row.photo),
    books_count: row.books_count ?? undefined,
    created_at: row.created_at,
  };
}

const BOOK_SELECT = `
  SELECT b.*, a.name_uz AS a_uz, a.name_ru AS a_ru, a.name_en AS a_en,
         c.name_uz AS c_uz, c.name_ru AS c_ru, c.name_en AS c_en
  FROM books b
  LEFT JOIN authors a ON a.id = b.author_id
  LEFT JOIN categories c ON c.id = b.category_id`;

function book(row, extra = {}) {
  const ready = row.conversion_status === 'ready';
  const report = extra.withReport ? parseJson(row.conversion_report, null) : null;
  const out = {
    id: row.id,
    title: row.title,
    slug: row.slug,
    description: row.description,
    author_id: row.author_id,
    category_id: row.category_id,
    author: { uz: row.a_uz || '', ru: row.a_ru || '', en: row.a_en || '', oz: row.a_uz || '' },
    category: { uz: row.c_uz || '', ru: row.c_ru || '', en: row.c_en || '', oz: row.c_uz || '' },
    price: row.price,
    is_free: !!row.is_free,
    is_published: !!row.is_published,
    photo: row.photo || null,
    photo_url: fileUrl(row.photo),
    lang: row.lang,
    chapters: row.chapters,
    words: row.words,
    reading_minutes: row.words ? Math.max(1, Math.round(row.words / 180)) : 0,
    conversion_status: row.conversion_status,
    is_ready: ready,
    package_version: row.package_version,
    // Content endpoints (need a Bearer token; access is checked per user).
    package_url: ready ? `/api/books/${row.id}/package.zip` : null,
    epub_url: ready ? `/api/books/${row.id}/epub` : null,
    epub_file: null, // legacy field: files are no longer public
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
  if (extra.withReport) {
    out.source_name = row.source_name;
    out.conversion_error = row.conversion_error;
    out.conversion_report = report;
  }
  return Object.assign(out, extra.fields || {});
}

const PAYMENT_STATUS = {
  1: { uz: 'Kutilmoqda', ru: 'Ожидает', en: 'Pending', oz: 'Кутилмоқда' },
  2: { uz: 'Tasdiqlangan', ru: 'Подтверждён', en: 'Approved', oz: 'Тасдиқланган' },
  3: { uz: 'Rad etilgan', ru: 'Отклонён', en: 'Rejected', oz: 'Рад этилган' },
};

function payment(row) {
  return {
    id: row.id,
    user_id: row.user_id,
    user_name: row.user_name,
    phone_number: formatPhone(row.phone_number),
    book_id: row.book_id,
    book_title: row.book_title,
    amount: row.amount,
    comment: row.comment,
    status_id: row.status_id,
    status: PAYMENT_STATUS[row.status_id] || PAYMENT_STATUS[1],
    receipt_image: row.receipt_image,
    receipt_url: fileUrl(row.receipt_image),
    approved_at: row.approved_at,
    admin_comment: row.admin_comment,
    reviewed_at: row.reviewed_at,
    created_at: row.created_at,
  };
}

function user(row) {
  return {
    id: row.id,
    name: row.name,
    phone_number: formatPhone(row.phone_number),
    phone: row.phone_number,
    role_id: row.role_id,
    is_verified: !!row.is_verified,
    is_blocked: !!row.is_blocked,
    has_password: !!row.password_hash,
    created_at: row.created_at,
    last_login_at: row.last_login_at,
  };
}

module.exports = { category, author, book, payment, user, BOOK_SELECT, fileUrl };
