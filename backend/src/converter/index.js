'use strict';

// Book conversion pipeline: Word/EPUB/TXT -> "mbook" reader package.
//
// Package layout (one folder per book):
//   manifest.json  metadata, chapter list, table of contents, stats
//   book.js        manifest + chapter HTML, loadable with a <script> tag so the
//                  reader also works from file:// (offline and inside the app)
//   images/        optimised pictures referenced by the chapters
//   book.epub      standard EPUB3 for other readers (optional)
//   package.zip    manifest.json + book.js + images/ for the mobile app download

const fs = require('fs');
const fsp = require('fs/promises');
const os = require('os');
const path = require('path');
const { execFile } = require('child_process');
const JSZip = require('jszip');
const cheerio = require('cheerio');

const { importDocx } = require('./docx');
const { importEpub, buildEpub } = require('./epub');
const { decodeText, textToHtml } = require('./plain');
const { buildChapters, displayTitle } = require('./structure');
const { ImageStore, makeCover } = require('./images');
const { detectLang, slugify, extOf } = require('./util');

const SUPPORTED = ['docx', 'doc', 'rtf', 'odt', 'epub', 'txt', 'htm', 'html'];
const FORMAT_VERSION = 1;

function findSoffice() {
  const candidates = [
    process.env.SOFFICE_PATH,
    'C:\\Program Files\\LibreOffice\\program\\soffice.exe',
    'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe',
    '/usr/bin/soffice',
    '/usr/bin/libreoffice',
    '/usr/lib/libreoffice/program/soffice',
    '/Applications/LibreOffice.app/Contents/MacOS/soffice',
  ].filter(Boolean);
  return candidates.find((c) => fs.existsSync(c)) || null;
}

function run(cmd, args, timeout) {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { timeout, windowsHide: true }, (err, stdout, stderr) => {
      if (err) reject(new Error(`${path.basename(cmd)}: ${err.message} ${stderr || ''}`.trim()));
      else resolve(stdout);
    });
  });
}

// .doc/.rtf/.odt -> .docx through LibreOffice when it is installed.
async function toDocxWithSoffice(buffer, ext) {
  const soffice = findSoffice();
  if (!soffice) return null;
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), 'mbook-'));
  try {
    const src = path.join(dir, `source.${ext}`);
    await fsp.writeFile(src, buffer);
    const profile = 'file:///' + path.join(dir, 'profile').replace(/\\/g, '/').replace(/^\//, '');
    await run(soffice, [`-env:UserInstallation=${profile}`, '--headless', '--convert-to', 'docx:"MS Word 2007 XML"', '--outdir', dir, src], 180000);
    return await fsp.readFile(path.join(dir, 'source.docx'));
  } finally {
    fsp.rm(dir, { recursive: true, force: true }).catch(() => {});
  }
}

async function legacyDocToHtml(buffer) {
  const WordExtractor = require('word-extractor');
  const doc = await new WordExtractor().extract(buffer);
  let body = doc.getBody();
  const notes = doc.getFootnotes ? doc.getFootnotes().trim() : '';
  if (notes) body += '\n\n\f\n' + notes;
  return textToHtml(body);
}

const NOT_A_NAME = /vazirlig|universitet|respublika|ministry|university|institut|qo[‘ʻ'’]?llanma|toshkent|tashkent|press|nashriyot|darslik|o[‘ʻ'’]?quv|monografiya|akademiya|fakultet|kafedra|министерств|университет|учебн|пособие|ташкент|издательств|massachusetts|london|cambridge|\d/i;

const GENRE_RE = /qo[‘ʻ'’]?llanma|darslik|monografiya|uslubiy|ma[‘ʻ'’]?ruzalar|lug[‘ʻ'’]?at|to[‘ʻ'’]?plam|пособие|учебник|монография|словарь|textbook|handbook|monograph|dictionary/i;

function guessFromTitlePage(chapter) {
  if (!chapter || chapter.kind !== 'title') return {};
  const $ = cheerio.load(chapter.html, null, false);
  const lines = $('p.tp').toArray().map((p) => ({ text: $(p).text().replace(/\s+/g, ' ').trim(), rank: $(p).hasClass('tp1') ? 1 : $(p).hasClass('tp2') ? 2 : 3 })).filter((l) => l.text);
  const top = lines.filter((l) => l.rank === 1);
  let title = '';
  let titleLines = [];
  const distinctTop = top.length < lines.length;
  if (distinctTop && top.length <= 4 && top.map((l) => l.text).join(' ').length <= 140) titleLines = top;
  if (!titleLines.length) {
    // Same font everywhere: the title is the lines just above "O'quv qo'llanma".
    const g = lines.findIndex((l) => GENRE_RE.test(l.text));
    if (g > 0) {
      for (let k = g - 1; k >= 0 && titleLines.length < 3; k--) {
        if (NOT_A_NAME.test(lines[k].text) || lines[k].text.length > 80) break;
        titleLines.unshift(lines[k]);
      }
    }
  }
  if (titleLines.length) title = displayTitle(titleLines.map((l) => l.text).join(' '));
  if (titleLines.length && !distinctTop) {
    // Make the detected title stand out on a page typed in one font size.
    for (const l of titleLines) $(l.el).removeClass('tp2 tp3').addClass('tp1');
    chapter.html = $.html();
  }
  const authors = [];
  for (const l of lines) {
    if (titleLines.includes(l)) continue;
    if (NOT_A_NAME.test(l.text) || l.text.length > 70) continue;
    for (const part of l.text.split(/\s*[,;]\s*|\s+va\s+|\s+и\s+|\s+and\s+/)) {
      const words = part.trim().split(/\s+/);
      if (words.length < 2 || words.length > 4) continue;
      if (!words.every((w) => /^\p{Lu}[\p{L}‘ʻ'’.-]*$/u.test(w))) continue;
      authors.push(words.map((w) => w[0] + w.slice(1).toLocaleLowerCase('uz')).join(' '));
    }
  }
  return { title, authors: authors.slice(0, 4) };
}

/**
 * Convert a book file into a reader package.
 * @param {object} input  { path } or { buffer, filename }
 * @param {object} opts   { outDir, id, title, authors, lang, coverBuffer, epub, zip }
 */
async function convertBook(input, opts = {}) {
  const started = Date.now();
  const filename = input.filename || path.basename(input.path || 'book');
  const ext = extOf(filename);
  if (!SUPPORTED.includes(ext)) {
    throw new Error(`Bu format qo'llab-quvvatlanmaydi: .${ext}. Qabul qilinadi: ${SUPPORTED.map((e) => '.' + e).join(', ')}`);
  }
  let buffer = input.buffer || (await fsp.readFile(input.path));

  const warnings = [];
  const images = new ImageStore();
  let externalCover = null;
  const ctx = {
    warn: (m) => warnings.length < 50 && warnings.push(m),
    addImage: (buf, type) => images.add(buf, type),
    setCover: (buf) => { externalCover = buf; },
    hasCover: () => !!(externalCover || opts.coverBuffer),
  };

  let imported;
  let sourceKind = ext;
  if (ext === 'doc' || ext === 'rtf' || ext === 'odt') {
    const docx = await toDocxWithSoffice(buffer, ext).catch((e) => {
      ctx.warn(`LibreOffice konvertatsiyasi xato: ${e.message}`);
      return null;
    });
    if (docx) {
      buffer = docx;
      sourceKind = `${ext}->docx`;
    } else if (ext === 'doc') {
      ctx.warn("LibreOffice topilmadi: eski .doc fayldan faqat matn olindi (rasmlar, jadvallar va formatlash yo'qoladi). Eng yaxshi natija uchun faylni Word'da .docx qilib saqlang.");
      imported = { html: await legacyDocToHtml(buffer), meta: {} };
      sourceKind = 'doc-text';
    } else {
      throw new Error(`.${ext} uchun LibreOffice kerak. Faylni .docx formatida yuklang.`);
    }
  }
  if (!imported) {
    if (sourceKind === 'docx' || sourceKind.endsWith('->docx')) {
      const r = await importDocx(buffer, ctx);
      imported = { html: r.html, meta: {}, report: r.report };
    } else if (ext === 'epub') {
      imported = await importEpub(buffer, ctx);
    } else if (ext === 'txt') {
      imported = { html: textToHtml(decodeText(buffer)), meta: {} };
    } else if (ext === 'htm' || ext === 'html') {
      const $ = cheerio.load(decodeText(buffer));
      imported = { html: $('body').html() || '', meta: { title: $('title').text().trim() } };
    }
  }

  const plain = cheerio.load(imported.html, null, false).root().text();
  // Text decides the language: EPUB tools often stamp every book as "en".
  const lang = opts.lang || detectLang(plain);
  const built = buildChapters(imported.html, { lang, maxChapterWords: opts.maxChapterWords });
  if (!built.chapters.length) throw new Error("Faylda o'qiladigan matn topilmadi");

  const guessed = guessFromTitlePage(built.chapters[0]);
  const fileTitle = path.basename(filename, path.extname(filename)).replace(/[_]+/g, ' ').trim();
  const title = (opts.title || imported.meta.title || guessed.title || fileTitle).trim();
  const authors = (opts.authors && opts.authors.length ? opts.authors : imported.meta.authors && imported.meta.authors.length ? imported.meta.authors : guessed.authors) || [];
  const id = String(opts.id || slugify(title));

  let cover = null;
  const coverSrc = opts.coverBuffer || externalCover;
  if (coverSrc) {
    try {
      const c = await makeCover(coverSrc);
      cover = await images.addNamed('images/cover', c.buffer, c.type);
    } catch (e) {
      ctx.warn(`Muqova rasmi o'qilmadi: ${e.message}`);
    }
  }
  if (images.skipped) ctx.warn(`${images.skipped} ta rasm telefon ko'rsata olmaydigan formatda (WMF/EMF) — tashlab ketildi.`);

  // Intrinsic sizes let the reader lay out pages before pictures arrive.
  for (const ch of built.chapters) {
    ch.html = ch.html.replace(/<img src="(images\/[^"]+)"/g, (m, src) => {
      const img = images.files.get(src);
      return img && img.width ? `<img src="${src}" width="${img.width}" height="${img.height}"` : m;
    });
  }

  const words = built.chapters.reduce((a, c) => a + c.words, 0);
  const chars = built.chapters.reduce((a, c) => a + c.chars, 0);
  const manifest = {
    format: 'mbook',
    version: FORMAT_VERSION,
    id,
    title,
    authors,
    lang,
    cover,
    createdAt: new Date().toISOString(),
    source: { filename, kind: sourceKind },
    stats: {
      chapters: built.chapters.length,
      words,
      chars,
      images: images.files.size - (cover ? 1 : 0),
      footnotes: built.notesCount,
      readingMinutes: Math.max(1, Math.round(words / 180)),
    },
    chapters: built.chapters.map(({ id: cid, title: t, kind, words: w, chars: c }) => ({ id: cid, title: t, kind, words: w, chars: c })),
    toc: built.toc,
  };

  const report = {
    ...(imported.report || {}),
    sourceKind,
    chapters: built.chapters.length,
    tocEntries: built.toc.length,
    words,
    images: manifest.stats.images,
    footnotes: built.notesCount,
    warnings,
    ms: 0,
  };

  if (opts.outDir) {
    await writePackage(opts.outDir, manifest, built.chapters, images, opts);
  }
  report.ms = Date.now() - started;
  return { manifest, chapters: built.chapters, images, report };
}

function bookJs(manifest, chapters) {
  const data = { ...manifest, chapters: manifest.chapters.map((c, i) => ({ ...c, html: chapters[i].html })) };
  const json = JSON.stringify(data).replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029').replace(/<\/script/gi, '<\\/script');
  return `/* mbook v${FORMAT_VERSION} */\n(window.MBookLoad||function(b){window.MBOOK=b})(${json});\n`;
}

async function writePackage(outDir, manifest, chapters, images, opts = {}) {
  await fsp.rm(outDir, { recursive: true, force: true });
  await fsp.mkdir(path.join(outDir, 'images'), { recursive: true });
  const js = bookJs(manifest, chapters);
  await fsp.writeFile(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 1));
  await fsp.writeFile(path.join(outDir, 'book.js'), js);
  for (const [name, img] of images.files) await fsp.writeFile(path.join(outDir, name), img.buffer);

  if (opts.epub !== false) {
    const epub = await buildEpub({ ...manifest, chapters, images: images.files });
    await fsp.writeFile(path.join(outDir, 'book.epub'), epub);
  }
  if (opts.zip !== false) {
    const zip = new JSZip();
    zip.file('manifest.json', JSON.stringify(manifest));
    zip.file('book.js', js);
    for (const [name, img] of images.files) zip.file(name, img.buffer, { compression: 'STORE' });
    const buf = await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE', compressionOptions: { level: 6 } });
    await fsp.writeFile(path.join(outDir, 'package.zip'), buf);
  }
}

module.exports = { convertBook, writePackage, SUPPORTED, FORMAT_VERSION, findSoffice };
