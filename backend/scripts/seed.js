#!/usr/bin/env node
'use strict';

// Fills an empty server with demo content so the app is not empty:
// categories, two demo authors and the books from backend/seed-books/.
//
//   npm run seed            (stop the server first, or run it on a fresh DATA_DIR)
//
// Each seed book is "<slug>.docx" (+ optional "<slug>.jpg" cover). Unknown files
// in the folder are added as free books of the first author.

const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const { q } = require('../src/db');
const jobs = require('../src/jobs');
const { bookDir, moveUpload } = require('../src/storage');

const DIR = path.join(__dirname, '..', 'seed-books');

const CATEGORIES = [
  ['Ilmiy', 'Научные', 'Science'],
  ["O'quv qo'llanmalar", 'Учебные пособия', 'Textbooks'],
  ['Tilshunoslik', 'Лингвистика', 'Linguistics'],
  ['Tarjima', 'Переводные', 'Translated'],
  ['Badiiy adabiyot', 'Художественная', 'Fiction'],
  ['Biznes', 'Бизнес', 'Business'],
  ['Psixologiya', 'Психология', 'Psychology'],
  ['Bolalar uchun', 'Детские', 'Kids'],
];

const AUTHORS = [
  { phone: '998901234567', name: 'Baxtiyor Mengliyev', bio: "Filologiya fanlari doktori, professor. Tilshunoslik va ilmiy tadqiqot metodologiyasi bo'yicha 20 dan ortiq kitob muallifi.", card: '8600 1234 5678 9012', holder: 'BAXTIYOR MENGLIYEV' },
  { phone: '998907654321', name: 'Tarjima markazi', bio: "Jahon ilmiy adabiyotining eng yaxshi namunalarini o'zbek tiliga tarjima qiluvchi jamoa.", card: '9860 1111 2222 3333', holder: 'TARJIMA MARKAZI' },
];

const BOOKS = [
  { slug: 'dissertatsiya-yozish-metodikasi', author: 0, category: 1, price: 45000, author_name: 'Baxtiyor Mengliyev, Shahnoza Gulyamova', description: "Magistrantlar va tadqiqotchilar uchun dissertatsiya yozishning to'liq yo'riqnomasi: mavzu tanlashdan himoyagacha. Har bir bobda tayanch tushunchalar, savollar, testlar va glossariy." },
  { slug: 'ilmiy-tadqiqot-metodologiyasi', author: 0, category: 0, price: 0, author_name: 'Baxtiyor Mengliyev', description: "16 mavzuda ilmiy tadqiqotning asoslari: tadqiqot turlari, metodlar, ilmiy uslub, natijalarni rasmiylashtirish. O'zbek tili va adabiyoti magistrantlari uchun." },
  { slug: 'formal-uzbek-language', author: 0, category: 2, price: 30000, author_name: 'Bakhtiyor Mengliyev, Bobir Makhammadov', description: "O'zbek tilining fonetikasi, morfologiyasi va imlosi bo'yicha qo'llanma. Xorijiy talabalar va til o'rganuvchilar uchun." },
  { slug: 'how-to-write-a-thesis', author: 1, category: 3, price: 35000, author_name: 'Umberto Eco', description: "Umberto Ekoning mashhur «How to Write a Thesis» kitobining o'zbekcha tarjimasi. Mavzu tanlash, manbalar bilan ishlash, kartochkalar va yakuniy nusxa." },
];

async function main() {
  if (!fs.existsSync(DIR)) throw new Error(`Papka topilmadi: ${DIR}`);
  for (const [uz, ru, en] of CATEGORIES) {
    if (!q.get('SELECT id FROM categories WHERE name_uz = ?', uz)) q.run('INSERT INTO categories (name_uz, name_ru, name_en) VALUES (?, ?, ?)', uz, ru, en);
  }
  const cats = q.all('SELECT * FROM categories').reduce((m, c) => ((m[c.name_uz] = c.id), m), {});

  const authorIds = AUTHORS.map((a) => {
    let u = q.get('SELECT * FROM users WHERE phone_number = ?', a.phone);
    if (!u) u = q.get('SELECT * FROM users WHERE id = ?', q.run('INSERT INTO users (name, phone_number, is_verified) VALUES (?, ?, 1)', a.name, a.phone).lastInsertRowid);
    if (!q.get('SELECT 1 FROM author_profiles WHERE user_id = ?', u.id)) {
      q.run('INSERT INTO author_profiles (user_id, display_name, bio, card_number, card_holder, card_verified) VALUES (?, ?, ?, ?, ?, 1)', u.id, a.name, a.bio, a.card, a.holder);
    }
    return u.id;
  });

  const known = new Set(BOOKS.map((b) => b.slug));
  const extra = fs.readdirSync(DIR).filter((f) => /\.(docx|doc|epub|txt)$/i.test(f) && !known.has(f.replace(/\.[^.]+$/, '')));
  const list = [...BOOKS, ...extra.map((f) => ({ slug: f.replace(/\.[^.]+$/, ''), file: f, author: 0, category: 0, price: 0, author_name: '', description: '' }))];

  const created = [];
  for (const b of list) {
    const file = b.file || fs.readdirSync(DIR).find((f) => f.startsWith(b.slug + '.') && !/\.(jpe?g|png|webp)$/i.test(f));
    if (!file) {
      console.log(`- ${b.slug}: fayl yo'q, o'tkazildi`);
      continue;
    }
    if (q.get('SELECT id FROM books WHERE slug = ?', b.slug)) {
      console.log(`= ${b.slug}: allaqachon bor`);
      continue;
    }
    let photo = null;
    const cover = ['jpg', 'jpeg', 'png'].map((e) => path.join(DIR, `${b.slug}.${e}`)).find((p) => fs.existsSync(p));
    if (cover) {
      const tmp = path.join(require('../src/config').tmpDir, `seed-${Date.now()}${path.extname(cover)}`);
      await fsp.copyFile(cover, tmp);
      photo = await moveUpload({ path: tmp, originalname: path.basename(cover), fieldname: 'cover', size: fs.statSync(tmp).size }, 'covers');
    }
    const catName = CATEGORIES[b.category][0];
    const r = q.run(
      `INSERT INTO books (title, slug, description, author_name, category_id, is_free, price, photo, owner_user_id, status, submitted_at, auto_title, source_file, source_name)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', datetime('now'), 1, ?, ?)`,
      b.slug, b.slug, b.description, b.author_name, cats[catName], b.price ? 0 : 1, b.price, photo, authorIds[b.author], `source${path.extname(file)}`, file
    );
    const id = Number(r.lastInsertRowid);
    await fsp.mkdir(bookDir(id), { recursive: true });
    await fsp.copyFile(path.join(DIR, file), path.join(bookDir(id), `source${path.extname(file)}`));
    jobs.enqueue(id);
    created.push(id);
  }

  // Wait for conversions, then publish.
  for (let i = 0; i < 600 && created.length; i++) {
    const left = q.get(`SELECT COUNT(*) AS n FROM books WHERE id IN (${created.join(',')}) AND conversion_status IN ('pending', 'processing')`).n;
    if (!left) break;
    await new Promise((r) => setTimeout(r, 250));
  }
  for (const id of created) {
    const b = q.get('SELECT * FROM books WHERE id = ?', id);
    if (b.conversion_status === 'ready') {
      q.run("UPDATE books SET status = 'approved', reviewed_at = datetime('now'), published_at = datetime('now') WHERE id = ?", id);
      console.log(`+ ${b.title} — ${b.is_free ? 'bepul' : b.price + " so'm"} (${b.chapters} bob)`);
    } else console.log(`! ${b.slug}: ${b.conversion_error}`);
  }
  console.log(`\nTayyor. Demo mualliflar: ${AUTHORS.map((a) => '+' + a.phone).join(', ')} (kod 111111)`);
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
