#!/usr/bin/env node
'use strict';

// Static (server-less) mode: convert books and build an offline library.
//
//   npm run convert -- "C:\path\book.docx" "C:\folder\with\books" [--out offline]
//                      [--title "..."] [--author "..."] [--cover cover.jpg]
//
// Then open <out>/index.html in a browser (double-click works, no server).
// Phone-sized preview: Chrome DevTools -> device toolbar, or serve the folder
// on the LAN (npx serve offline) and open it on a phone.

const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const { convertBook, writePackage, SUPPORTED } = require('../src/converter');
const { slugify } = require('../src/converter/util');

const READER_DIR = path.join(__dirname, '..', 'public', 'reader');
const READER_FILES = ['reader.html', 'reader.css', 'reader.js', 'index.html'];

function parseArgs(argv) {
  const args = { files: [], out: path.join(__dirname, '..', 'offline'), title: null, authors: [], cover: null, epub: true };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--out') args.out = path.resolve(argv[++i]);
    else if (a === '--title') args.title = argv[++i];
    else if (a === '--author') args.authors.push(argv[++i]);
    else if (a === '--cover') args.cover = path.resolve(argv[++i]);
    else if (a === '--no-epub') args.epub = false;
    else if (a === '-h' || a === '--help') args.help = true;
    else args.files.push(a);
  }
  return args;
}

async function collect(inputs) {
  const out = [];
  for (const input of inputs) {
    const p = path.resolve(input);
    if (!fs.existsSync(p)) {
      console.warn(`! topilmadi: ${input}`);
      continue;
    }
    const st = await fsp.stat(p);
    if (st.isDirectory()) {
      for (const f of await fsp.readdir(p)) {
        const ext = path.extname(f).slice(1).toLowerCase();
        if (SUPPORTED.includes(ext) && !f.startsWith('~$')) out.push(path.join(p, f));
      }
    } else out.push(p);
  }
  return out;
}

async function rebuildIndex(outDir) {
  const books = [];
  for (const d of await fsp.readdir(outDir, { withFileTypes: true })) {
    if (!d.isDirectory()) continue;
    const mf = path.join(outDir, d.name, 'manifest.json');
    if (!fs.existsSync(mf)) continue;
    const m = JSON.parse(await fsp.readFile(mf, 'utf8'));
    books.push({ id: d.name, title: m.title, authors: m.authors, cover: m.cover, chapters: m.stats.chapters, words: m.stats.words, minutes: m.stats.readingMinutes, createdAt: m.createdAt });
  }
  books.sort((a, b) => a.title.localeCompare(b.title));
  await fsp.writeFile(path.join(outDir, 'books.js'), `window.MBOOKS = ${JSON.stringify(books, null, 1)};\n`);
  return books;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || !args.files.length) {
    console.log(`Foydalanish: npm run convert -- <fayl yoki papka> [...] [--out papka] [--title "Nomi"] [--author "Muallif"] [--cover rasm.jpg]
Qabul qilinadi: ${SUPPORTED.map((e) => '.' + e).join(' ')}`);
    process.exit(args.help ? 0 : 1);
  }
  const files = await collect(args.files);
  await fsp.mkdir(args.out, { recursive: true });
  for (const f of READER_FILES) await fsp.copyFile(path.join(READER_DIR, f), path.join(args.out, f));
  await fsp.cp(path.join(READER_DIR, 'fonts'), path.join(args.out, 'fonts'), { recursive: true });

  let ok = 0;
  const usedIds = new Set();
  for (const file of files) {
    process.stdout.write(`→ ${path.basename(file)} … `);
    try {
      const single = files.length === 1;
      const res = await convertBook({ path: file }, {
        title: single ? args.title : null,
        authors: single ? args.authors : [],
        coverBuffer: single && args.cover ? await fsp.readFile(args.cover) : null,
        epub: args.epub,
        zip: false,
      });
      let id = slugify(res.manifest.title || path.basename(file));
      for (let n = 2; usedIds.has(id); n++) id = `${slugify(res.manifest.title)}-${n}`;
      usedIds.add(id);
      res.manifest.id = id;
      const dir = path.join(args.out, id);
      await writePackage(dir, res.manifest, res.chapters, res.images, { epub: args.epub, zip: false });
      const r = res.report;
      console.log(`OK  "${res.manifest.title}" — ${r.chapters} bob, ${r.tocEntries} mundarija, ${r.words} so'z, ${r.images} rasm, ${r.footnotes} izoh (${r.ms} ms)`);
      for (const w of r.warnings) console.log(`    ! ${w}`);
      ok++;
    } catch (e) {
      console.log('XATO');
      console.error('   ', e.message);
    }
  }
  const books = await rebuildIndex(args.out);
  const index = path.join(args.out, 'index.html');
  console.log(`\n${ok}/${files.length} ta kitob tayyor. Kutubxonada jami ${books.length} ta.`);
  console.log(`Brauzerda oching: file:///${index.replace(/\\/g, '/')}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
