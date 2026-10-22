'use strict';

const path = require('path');

const MARK_OPEN = '';
const MARK_CLOSE = '';

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// Latin transliteration for Uzbek/Russian so slugs are readable.
const CYR = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', е: 'e', ё: 'yo', ж: 'j', з: 'z', и: 'i', й: 'y',
  к: 'k', л: 'l', м: 'm', н: 'n', о: 'o', п: 'p', р: 'r', с: 's', т: 't', у: 'u', ф: 'f',
  х: 'x', ц: 'ts', ч: 'ch', ш: 'sh', щ: 'sh', ъ: '', ы: 'i', ь: '', э: 'e', ю: 'yu', я: 'ya',
  ў: 'o', қ: 'q', ғ: 'g', ҳ: 'h',
};

function slugify(s, fallback = 'book') {
  const out = String(s || '')
    .toLowerCase()
    .split('')
    .map((ch) => (CYR[ch] !== undefined ? CYR[ch] : ch))
    .join('')
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[‘’ʻʼ'`]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
  return out || fallback;
}

function detectLang(text) {
  const sample = text.slice(0, 20000);
  const cyr = (sample.match(/[а-яё]/gi) || []).length;
  const lat = (sample.match(/[a-z]/gi) || []).length;
  if (cyr > lat) return 'ru';
  if (/[oOgG][‘ʻ'’`]/.test(sample) || /\b(va|bilan|uchun|bo['‘ʻ’]lib|haqida)\b/i.test(sample)) return 'uz';
  return 'en';
}

const LABELS = {
  uz: { titlePage: 'Muqova', front: 'Annotatsiya', part: 'Qism', chapter: 'Bob' },
  ru: { titlePage: 'Титульный лист', front: 'Аннотация', part: 'Часть', chapter: 'Глава' },
  en: { titlePage: 'Title page', front: 'Preface', part: 'Part', chapter: 'Chapter' },
};

function labels(lang) {
  return LABELS[lang] || LABELS.uz;
}

function countWords(text) {
  const m = text.match(/[\p{L}\p{N}][\p{L}\p{N}‘’ʻʼ'-]*/gu);
  return m ? m.length : 0;
}

function extOf(file) {
  return path.extname(file).toLowerCase().replace('.', '');
}

function normalizeTitle(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[‘’ʻʼ'`"“”«»]/g, '')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}

module.exports = {
  MARK_OPEN,
  MARK_CLOSE,
  escapeHtml,
  slugify,
  detectLang,
  labels,
  countWords,
  extOf,
  normalizeTitle,
};
