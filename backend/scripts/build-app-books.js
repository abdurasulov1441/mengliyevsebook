#!/usr/bin/env node
'use strict';

// Local (server-less) mode for the Flutter app: puts converted books into
// assets/local_books/ together with catalog.json, so the app shows the
// library, shop and reader without any backend.
//
//   npm run convert -- "kitob.docx" ...          (fills backend/offline/)
//   npm run app-books -- [--paid id=45000 ...] [--skip id ...]
//
// By default every book in backend/offline/ is copied and free; mark some as
// paid to see the purchase flow in the app.

const fs = require('fs');
const path = require('path');

const SRC = path.join(__dirname, '..', 'offline');
const DST = path.join(__dirname, '..', '..', 'assets', 'local_books');

function parseArgs(argv) {
  const paid = {};
  const skip = new Set();
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--paid') {
      const [id, price] = argv[++i].split('=');
      paid[id] = parseInt(price, 10) || 0;
    } else if (argv[i] === '--skip') skip.add(argv[++i]);
  }
  return { paid, skip };
}

function walk(dir, base = '') {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? `${base}/${e.name}` : e.name;
    if (e.isDirectory()) out.push(...walk(path.join(dir, e.name), rel));
    else out.push(rel);
  }
  return out;
}

function main() {
  const { paid, skip } = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(SRC)) {
    console.error('backend/offline topilmadi. Avval: npm run convert -- "kitob.docx"');
    process.exit(1);
  }
  fs.rmSync(DST, { recursive: true, force: true });
  fs.mkdirSync(DST, { recursive: true });
  const catalog = [];
  for (const d of fs.readdirSync(SRC, { withFileTypes: true })) {
    if (!d.isDirectory() || skip.has(d.name)) continue;
    const dir = path.join(SRC, d.name);
    const mf = path.join(dir, 'manifest.json');
    if (!fs.existsSync(mf)) continue;
    const m = JSON.parse(fs.readFileSync(mf, 'utf8'));
    const out = path.join(DST, d.name);
    // book.epub is not needed by the reader: keep the app small.
    const files = walk(dir).filter((f) => f === 'book.js' || f === 'manifest.json' || f.startsWith('images/'));
    for (const f of files) {
      fs.mkdirSync(path.dirname(path.join(out, f)), { recursive: true });
      fs.copyFileSync(path.join(dir, f), path.join(out, f));
    }
    // Cover: the explicit one, otherwise the picture on the title page.
    let cover = m.cover;
    if (!cover) {
      const js = fs.readFileSync(path.join(dir, 'book.js'), 'utf8');
      const json = js.slice(js.indexOf('})(') + 3, js.lastIndexOf(');'));
      const first = JSON.parse(json).chapters[0];
      const img = first && first.kind === 'title' && first.html.match(/<img src="(images\/[^"]+)"/);
      if (img) cover = img[1];
    }
    const price = paid[d.name] || 0;
    catalog.push({
      id: d.name,
      title: m.title,
      description: `${m.stats.chapters} bob · ${m.stats.words.toLocaleString('ru-RU')} so'z · ~${Math.max(1, Math.round(m.stats.readingMinutes / 60))} soat o'qish`,
      author: { uz: (m.authors || []).join(', '), ru: '', en: '', oz: '' },
      category: { uz: '', ru: '', en: '', oz: '' },
      photo: cover ? `asset:assets/local_books/${d.name}/${cover}` : null,
      is_free: price === 0,
      price,
      package_version: 1,
      chapters: m.stats.chapters,
      words: m.stats.words,
      reading_minutes: m.stats.readingMinutes,
      files,
    });
    console.log(`+ ${d.name}  "${m.title}"  ${price ? price + " so'm" : 'bepul'}  (${files.length} fayl)`);
  }
  catalog.sort((a, b) => a.title.localeCompare(b.title));
  fs.writeFileSync(path.join(DST, 'catalog.json'), JSON.stringify(catalog, null, 1));
  console.log(`\n${catalog.length} ta kitob -> assets/local_books/ (catalog.json)`);
  updatePubspec(catalog);
}

// Flutter asset folders are not recursive: list every book and images folder.
function updatePubspec(catalog) {
  const file = path.join(__dirname, '..', '..', 'pubspec.yaml');
  const src = fs.readFileSync(file, 'utf8');
  const eol = src.includes('\r\n') ? '\r\n' : '\n';
  const lines = src.split(/\r?\n/);
  const start = lines.findIndex((l) => l.includes('# local_books:start'));
  const end = lines.findIndex((l) => l.includes('# local_books:end'));
  if (start < 0 || end < start) {
    console.warn("! pubspec.yaml: '# local_books:start/end' belgilari topilmadi — assetlarni qo'lda qo'shing");
    return;
  }
  const dirs = ['    - assets/local_books/'];
  for (const b of catalog) {
    dirs.push(`    - assets/local_books/${b.id}/`);
    if (b.files.some((f) => f.startsWith('images/'))) dirs.push(`    - assets/local_books/${b.id}/images/`);
  }
  lines.splice(start + 1, end - start - 1, ...dirs);
  fs.writeFileSync(file, lines.join(eol));
  console.log('pubspec.yaml yangilandi (assets/local_books)');
}

main();
