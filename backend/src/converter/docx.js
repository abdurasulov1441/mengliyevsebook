'use strict';

// DOCX -> annotated HTML.
//
// Most books we receive are typed in Word without real heading styles: chapter
// titles are just bold, centred and/or larger text. Stock converters (pandoc,
// Calibre, Word "Save as") therefore produce one endless chapter or hundreds of
// arbitrary fragments. Here we look at every paragraph's formatting, work out
// the body font size and promote paragraphs that stand out to h1..h4. The
// decisions travel through mammoth as style names (which pick the HTML tag) and
// invisible marker runs (which carry extra attributes) and are resolved later
// in structure.js.

const JSZip = require('jszip');
const mammoth = require('mammoth');
const documents = require('mammoth/lib/documents');
const { MARK_OPEN, MARK_CLOSE, normalizeTitle } = require('./util');

const HEADING_STYLE_RE = /^(heading|заголовок|título|titre|überschrift|sarlavha)\s*(\d)/i;
const CHAPTER_RE = new RegExp(
  [
    '^(\\d+|[ivxlc]+)\\s*[-–—.]?\\s*(mavzu|bob|qism|ma[‘ʻ\'’]?ruza|bo[‘ʻ\'’]?lim|dars|глава|тема|часть|раздел|лекция|chapter|part|lesson|section)\\b',
    '^(mavzu|bob|qism|глава|тема|часть|раздел|chapter|part)\\s*(\\d+|[ivxlc]+)\\b',
    '^(kirish|xulosa|muqaddima|so[‘ʻ\'’]?z\\s*boshi|so[‘ʻ\'’]?ngso[‘ʻ\'’]?z|glossariy|ilova(lar)?|\\d+[-–]\\s*ilova|foydalanilgan\\s+adabiyotlar|adabiyotlar(\\s+ro[‘ʻ\'’]?yxati)?|mundarija|annotatsiya|tarjimonlarning|введение|заключение|предисловие|послесловие|литература|список\\s+литературы|приложение|содержание|оглавление|аннотация|глоссарий|introduction|conclusion|preface|foreword|afterword|contents|references|bibliography|appendix|glossary|abstract)\\b',
  ].join('|'),
  'i'
);
// A line holding only a chapter label: "1-mavzu", "II BOB", "Глава 3", "Part 2".
const CHAPTER_LABEL_RE = /^((\d{1,3}|[IVXLC]{1,6})\s*[-–—.]?\s*(mavzu|bob|qism|ma[‘ʻ'’]?ruza|bo[‘ʻ'’]?lim|dars|глава|тема|часть|раздел|лекция|chapter|part|lesson)|(mavzu|bob|qism|глава|тема|часть|раздел|chapter|part|lesson)\s*(\d{1,3}|[IVXLC]{1,6}))\.?$/i;
const TOC_TITLE_RE =/^(mundarija|содержание|оглавление|contents|table of contents)$/i;

async function readStyleInfo(zip) {
  const info = { defaultSize: 12, styles: {} };
  const file = zip.file('word/styles.xml');
  if (!file) return info;
  const xml = await file.async('string');
  const defaults = xml.match(/<w:rPrDefault>[\s\S]*?<\/w:rPrDefault>/);
  if (defaults) {
    const sz = defaults[0].match(/<w:sz w:val="(\d+)"/);
    if (sz) info.defaultSize = +sz[1] / 2;
  }
  const raw = {};
  for (const m of xml.matchAll(/<w:style\b([^>]*)>([\s\S]*?)<\/w:style>/g)) {
    const attrs = m[1];
    const body = m[2];
    const id = (attrs.match(/w:styleId="([^"]+)"/) || [])[1];
    if (!id) continue;
    const rPr = (body.match(/<w:rPr>[\s\S]*?<\/w:rPr>/) || [''])[0];
    const sz = rPr.match(/<w:sz w:val="(\d+)"/);
    raw[id] = {
      basedOn: (body.match(/<w:basedOn w:val="([^"]+)"/) || [])[1],
      size: sz ? +sz[1] / 2 : null,
      bold: /<w:b\/>|<w:b w:val="(1|true|on)"\/>/.test(rPr) ? true : /<w:b w:val="(0|false|off)"\/>/.test(rPr) ? false : null,
      isDefault: /w:default="1"/.test(attrs) && /w:type="paragraph"/.test(attrs),
    };
  }
  const resolve = (id, key, depth = 0) => {
    const s = raw[id];
    if (!s || depth > 10) return null;
    if (s[key] !== null && s[key] !== undefined) return s[key];
    return s.basedOn ? resolve(s.basedOn, key, depth + 1) : null;
  };
  for (const id of Object.keys(raw)) {
    info.styles[id] = { size: resolve(id, 'size'), bold: resolve(id, 'bold') };
    if (raw[id].isDefault && info.styles[id].size) info.defaultSize = info.styles[id].size;
  }
  return info;
}

// ---- feature extraction ----------------------------------------------------

function collectRuns(node, out) {
  if (!node || !node.children) return out;
  for (const child of node.children) {
    if (child.type === 'run') out.push(child);
    else if (child.children) collectRuns(child, out);
  }
  return out;
}

function runText(run) {
  let s = '';
  for (const c of run.children || []) {
    if (c.type === 'text') s += c.value;
    else if (c.type === 'tab') s += ' ';
  }
  return s;
}

function paragraphFeatures(p, styleInfo) {
  const styleSize = (p.styleId && styleInfo.styles[p.styleId] && styleInfo.styles[p.styleId].size) || styleInfo.defaultSize;
  const styleBold = !!(p.styleId && styleInfo.styles[p.styleId] && styleInfo.styles[p.styleId].bold);
  const runs = collectRuns(p, []);
  let text = '';
  let textLen = 0;
  let boldLen = 0;
  let capsLen = 0;
  let sizeWeighted = 0;
  let maxSize = 0;
  let startsPage = false;
  let breakAfter = false;
  let hasImage = false;
  for (const run of runs) {
    for (const c of run.children || []) {
      if (c.type === 'break' && c.breakType === 'page') {
        if (text.trim()) breakAfter = true;
        else startsPage = true;
      }
      if (c.type === 'image') hasImage = true;
    }
    const t = runText(run);
    text += t;
    const len = t.replace(/\s/g, '').length;
    if (!len) continue;
    const size = run.fontSize || styleSize;
    textLen += len;
    if (run.isBold || styleBold) boldLen += len;
    if (run.isAllCaps) capsLen += len;
    sizeWeighted += size * len;
    maxSize = Math.max(maxSize, size);
  }
  text = text.replace(/\s+/g, ' ').trim();
  const headingMatch = p.styleName && p.styleName.match(HEADING_STYLE_RE);
  let styleLevel = headingMatch ? Math.max(1, Math.min(4, +headingMatch[2])) : 0;
  if (!styleLevel && p.styleName && /^title$/i.test(p.styleName)) styleLevel = 1;
  const upper = text.replace(/[^\p{L}]/gu, '');
  return {
    p,
    text,
    textLen,
    size: textLen ? Math.round((sizeWeighted / textLen) * 2) / 2 : styleSize,
    maxSize,
    bold: textLen > 0 && boldLen / textLen > 0.9,
    caps: textLen > 0 && (capsLen / textLen > 0.9 || (upper.length > 3 && upper === upper.toUpperCase() && upper !== upper.toLowerCase())),
    alignment: p.alignment || '',
    isList: !!p.numbering,
    styleLevel,
    startsPage,
    breakAfter,
    hasImage,
    inTable: false,
  };
}

function walkBody(children, styleInfo, out, inTable) {
  for (const node of children || []) {
    if (node.type === 'paragraph') {
      const f = paragraphFeatures(node, styleInfo);
      f.inTable = inTable;
      out.push(f);
    } else if (node.type === 'table') {
      // Page breaks around tables are rare; nested paragraphs are never headings.
      walkBody(node.children, styleInfo, out, true);
    } else if (node.children) {
      walkBody(node.children, styleInfo, out, inTable);
    }
  }
}

// ---- classification --------------------------------------------------------

function bodySizeOf(feats) {
  const hist = new Map();
  for (const f of feats) {
    if (f.inTable || !f.textLen) continue;
    hist.set(f.size, (hist.get(f.size) || 0) + f.textLen);
  }
  let best = 12;
  let bestLen = -1;
  for (const [size, len] of hist) if (len > bestLen) [best, bestLen] = [size, len];
  return best;
}

function findTitlePage(feats) {
  // Title page = everything before the first page break, when it is short and
  // mostly centred (typical university textbook cover page).
  let end = -1;
  let count = 0;
  for (let i = 0; i < feats.length; i++) {
    const f = feats[i];
    if (f.startsPage && count > 0) {
      end = i;
      break;
    }
    if (f.textLen) count++;
    if (f.breakAfter) {
      end = i + 1;
      break;
    }
    if (count > 25) return 0;
  }
  if (end <= 0) return 0;
  const lines = feats.slice(0, end).filter((f) => f.textLen);
  if (!lines.length) return 0;
  const centred = lines.filter((f) => f.alignment === 'center' || f.bold).length;
  const chars = lines.reduce((a, f) => a + f.text.length, 0);
  return centred / lines.length >= 0.6 && chars < 1500 ? end : 0;
}

function collectManualToc(feats) {
  // "Mundarija" pages typed by hand: remember entries to recognise chapter
  // titles later, and mark the lines so they are not treated as headings.
  const entries = [];
  const tocLines = new Set();
  for (let i = 0; i < feats.length; i++) {
    if (!TOC_TITLE_RE.test(feats[i].text)) continue;
    for (let j = i + 1; j < feats.length && j < i + 150; j++) {
      const f = feats[j];
      if (!f.textLen) continue;
      if (f.startsPage && j > i + 1) break;
      if (TOC_TITLE_RE.test(f.text) || f.text.length > 220) break;
      tocLines.add(j);
      const clean = normalizeTitle(f.text.replace(/[.\s…_]*\d+\s*$/, ''));
      if (clean.length > 2) entries.push(clean);
      if (f.breakAfter) break;
    }
  }
  return { entries, tocLines };
}

function classify(feats) {
  const body = bodySizeOf(feats);
  const titleEnd = findTitlePage(feats);
  const { entries: tocEntries, tocLines } = collectManualToc(feats);
  const matchesToc = (text) => {
    const t = normalizeTitle(text);
    if (t.length < 3) return false;
    return tocEntries.some((e) => e === t || (e.length > 8 && (t.startsWith(e) || e.startsWith(t))));
  };

  // Page-break flag for each paragraph: true when it is the first text on a page.
  let pendingPage = false;
  for (let i = 0; i < feats.length; i++) {
    const f = feats[i];
    if (f.startsPage) pendingPage = true;
    if (f.textLen || f.hasImage) {
      f.newPage = pendingPage;
      pendingPage = false;
    }
    if (f.breakAfter) pendingPage = true;
  }

  const cands = [];
  for (let i = 0; i < feats.length; i++) {
    const f = feats[i];
    f.index = i;
    if (i < titleEnd) {
      if (f.textLen) f.role = 'title';
      continue;
    }
    if (!f.textLen || f.inTable || tocLines.has(i)) continue;
    const words = f.text.split(' ').length;
    const enumeration = /^([a-zа-яё]|\d{1,2})\)\s*|^[–—•·-]\s|^[a-zа-яё]/.test(f.text);
    // "Term. Long explanation..." typed in bold is a run-in heading of a
    // paragraph, not a section title.
    const runIn = f.text.length > 60 && /\p{L}[.!?]\s*\p{L}/u.test(f.text.replace(/^\d+(\.\d+)*\.?\s*/, ''));
    if (f.styleLevel && f.text.length <= 150 && !enumeration && !runIn && !/[:;]$/.test(f.text)) {
      f.role = 'heading';
      cands.push(f);
      continue;
    }
    if (enumeration || runIn) continue;
    if ((/^(\d{1,3}|[IVXLC]{1,6})\.?$/.test(f.text) && (f.bold || f.size >= body * 1.5)) ||
        (CHAPTER_LABEL_RE.test(f.text) && (f.bold || f.size >= body + 1.5))) {
      f.role = 'chapnum';
      continue;
    }
    const tooLong = f.text.length > 200 || words > 30;
    const endsLikeSentencePart = /[,;]$/.test(f.text);
    if (tooLong || endsLikeSentencePart) continue;
    const bigger = f.size >= body + 1.5;
    const numbered = /^\d+(\.\d+)*\.?\s/.test(f.text);
    if ((f.bold && (bigger || f.text.length <= 150)) || (bigger && f.size >= body * 1.25 && f.text.length <= 80)) {
      // Bold list items like "1. Karluk dialect: ..." stay paragraphs unless big.
      if (f.isList && !bigger) continue;
      if (!bigger && !numbered) {
        // A bold line with a colon in the middle is usually a run-in term,
        // one ending with a colon introduces a list, and a right-aligned one
        // is a signature under a preface.
        const signature = f.alignment === 'right' && !f.newPage && !CHAPTER_RE.test(f.text);
        if (/^[^:]{1,60}:\s+\S/.test(f.text) || /:$/.test(f.text) || signature) continue;
      }
      f.role = 'heading';
      cands.push(f);
    }
  }

  // Level assignment.
  const sizes = [...new Set(cands.filter((f) => !f.styleLevel && f.size >= body + 1.5).map((f) => f.size))].sort((a, b) => b - a);
  // Ignore sizes that are used only once and are above the dominant heading
  // size (decorative one-offs).
  const sizeCount = new Map();
  for (const f of cands) sizeCount.set(f.size, (sizeCount.get(f.size) || 0) + 1);
  const levelSizes = sizes.filter((s, i) => sizeCount.get(s) > 1 || i === sizes.length - 1 || sizes.length < 3);
  const bodyBoldLevel = Math.min(levelSizes.length + 1, 4);

  for (const f of cands) {
    if (f.styleLevel) {
      f.level = f.styleLevel;
      continue;
    }
    if (f.size >= body + 1.5) {
      let lvl = levelSizes.findIndex((s) => f.size >= s);
      if (lvl < 0) lvl = levelSizes.length - 1;
      f.level = Math.min(lvl + 1, 3);
    } else {
      f.level = bodyBoldLevel;
    }
  }

  // When nothing is larger than body text (everything 14pt bold), split the
  // bold lines into chapter titles and sub-headings using page breaks, known
  // chapter words and the hand-typed table of contents.
  if (!levelSizes.length && cands.filter((f) => f.styleLevel && f.styleLevel <= 2).length < 2) {
    for (const f of cands) {
      const strong = CHAPTER_RE.test(f.text) || matchesToc(f.text);
      f.level = strong || (f.newPage && (f.alignment === 'center' || f.caps)) ? 1 : 2;
    }
  } else {
    // Promote obvious chapter titles that were typed at body size.
    for (const f of cands) {
      if (f.level > 1 && f.newPage && (CHAPTER_RE.test(f.text) || matchesToc(f.text))) f.level = 1;
    }
  }

  // Numbered sub-headings: "4." is one level above "4.1." whatever font size
  // the author happened to use. Unnumbered bold lines after "2.1." sit below it.
  let lastNumbered = 0;
  for (const f of cands) {
    if (f.level === 1) {
      lastNumbered = 0;
      continue;
    }
    if (f.styleLevel) continue;
    const m = f.text.match(/^(\d{1,2}(?:\.\d{1,2}){0,3})\.?\s*\S/);
    if (m && m[1].length < f.text.length) {
      f.level = Math.min(1 + m[1].split('.').length, 4);
      lastNumbered = f.level;
    } else if (lastNumbered >= 3 && f.level <= lastNumbered && f.size < body + 1.5) {
      f.level = Math.min(lastNumbered + 1, 4);
    }
  }

  // A chapter number paragraph ("1") belongs to the heading that follows.
  for (let i = 0; i < feats.length; i++) {
    const f = feats[i];
    if (f.role !== 'chapnum') continue;
    // The title is usually right after the number, sometimes after a short
    // editorial note ("6" / "Attention! ..." / "6. FINAL COPY").
    const following = feats.slice(i + 1).filter((n) => n.textLen).slice(0, 4);
    const next = following.find((n) => n.role === 'heading');
    if (next && (next === following[0] || next.text.startsWith(f.text.replace(/\.$/, '')))) {
      next.level = 1;
      next.chapterNumber = f.text.replace(/\.$/, '');
    } else if (CHAPTER_LABEL_RE.test(f.text)) {
      // "3-bob" alone with no title after it is the title itself.
      f.role = 'heading';
      f.level = 1;
      cands.push(f);
    } else {
      f.role = undefined;
    }
  }

  // Title page levels by size rank.
  const titleSizes = [...new Set(feats.filter((f) => f.role === 'title').map((f) => f.size))].sort((a, b) => b - a);
  for (const f of feats) if (f.role === 'title') f.titleRank = titleSizes.length === 1 ? 2 : Math.min(titleSizes.indexOf(f.size) + 1, 3);

  return { body, titleEnd, headings: cands.length };
}

function marker(attrs) {
  const parts = Object.entries(attrs)
    .filter(([, v]) => v !== undefined && v !== null && v !== false && v !== '')
    .map(([k, v]) => (v === true ? k : `${k}=${String(v).replace(/[;=]/g, '')}`));
  if (!parts.length) return null;
  return new documents.Run([new documents.Text(MARK_OPEN + parts.join(';') + MARK_CLOSE)]);
}

function annotate(doc, styleInfo, report) {
  const feats = [];
  walkBody(doc.children, styleInfo, feats, false);
  const stats = classify(feats);
  Object.assign(report, { bodyFontSize: stats.body, headingsDetected: stats.headings, hasTitlePage: stats.titleEnd > 0 });
  for (const f of feats) {
    const p = f.p;
    if (!f.textLen && !f.hasImage) continue;
    const attrs = {};
    if (f.newPage) attrs.pb = true;
    if (f.role === 'heading') {
      p.styleName = `MB-H${f.level}`;
      if (f.chapterNumber) attrs.num = f.chapterNumber;
    } else if (f.role === 'chapnum') {
      p.styleName = 'MB-CHAPNUM';
    } else if (f.role === 'title') {
      p.styleName = 'MB-TITLE';
      attrs.tp = f.titleRank || 1;
    } else if (!f.inTable) {
      if (f.alignment === 'center') attrs.al = 'center';
      else if (f.alignment === 'right') attrs.al = 'right';
    }
    const run = marker(attrs);
    if (run) p.children.unshift(run);
  }
  return doc;
}

const STYLE_MAP = [
  "p[style-name='MB-H1'] => h1:fresh",
  "p[style-name='MB-H2'] => h2:fresh",
  "p[style-name='MB-H3'] => h3:fresh",
  "p[style-name='MB-H4'] => h4:fresh",
  "p[style-name='MB-CHAPNUM'] => p.chapnum:fresh",
  "p[style-name='MB-TITLE'] => p.tp:fresh",
  // Run-level emphasis that mammoth drops by default.
  'u => u',
  'strike => s',
];

async function importDocx(buffer, ctx) {
  const zip = await JSZip.loadAsync(buffer);
  const styleInfo = await readStyleInfo(zip);
  const report = {};
  const result = await mammoth.convertToHtml(
    { buffer },
    {
      styleMap: STYLE_MAP,
      includeDefaultStyleMap: true,
      ignoreEmptyParagraphs: true,
      transformDocument: (doc) => annotate(doc, styleInfo, report),
      convertImage: mammoth.images.imgElement(async (image) => {
        const buf = await image.readAsBuffer();
        const src = await ctx.addImage(buf, image.contentType, image.altText);
        return src ? { src, alt: image.altText || '' } : { src: '', alt: '' };
      }),
    }
  );
  for (const m of result.messages) {
    if (m.type === 'warning' && !/Unrecognised (paragraph|run) style|was ignored/.test(m.message)) ctx.warn(m.message);
  }
  return { html: result.value, report };
}

module.exports = { importDocx, CHAPTER_RE, _debug: { walkBody, classify, readStyleInfo } };
