'use strict';

// Turns one long annotated HTML document into reader chapters with a table of
// contents, per-chapter footnotes and stable block ids (used for reading
// position, bookmarks and highlights).

const cheerio = require('cheerio');
const { MARK_OPEN, MARK_CLOSE, labels, countWords } = require('./util');

const ALLOWED_TAGS = new Set([
  'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'strong', 'b', 'em', 'i', 'u', 's', 'sub', 'sup', 'br', 'hr',
  'a', 'img', 'ul', 'ol', 'li', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th', 'caption', 'colgroup', 'col',
  'blockquote', 'pre', 'code', 'span', 'div', 'figure', 'figcaption', 'aside', 'section', 'small', 'mark',
  'dl', 'dt', 'dd', 'abbr', 'cite', 'q', 'big',
]);
const DROP_WITH_CONTENT = new Set(['script', 'style', 'iframe', 'object', 'embed', 'form', 'input', 'button', 'select', 'textarea', 'link', 'meta', 'head', 'title', 'svg', 'math', 'video', 'audio', 'noscript', 'template']);
const ALLOWED_ATTRS = new Set(['href', 'src', 'alt', 'id', 'class', 'colspan', 'rowspan', 'title', 'data-fn', 'data-b', 'data-c', 'data-num', 'data-pb', 'data-split', 'width', 'height', 'start', 'type', 'value']);

function resolveMarkers(html) {
  const re = new RegExp(
    `<(p|h[1-6]|li)((?:\\s[^>]*)?)>((?:<a id="[^"]*"><\\/a>)*)${MARK_OPEN}([^${MARK_CLOSE}]*)${MARK_CLOSE}`,
    'g'
  );
  html = html.replace(re, (_, tag, attrs, anchors, spec) => {
    const extra = [];
    const classes = [];
    for (const part of spec.split(';')) {
      const [k, v] = part.split('=');
      if (k === 'pb') extra.push('data-pb="1"');
      else if (k === 'al') classes.push(v);
      else if (k === 'tp') classes.push(`tp${v}`);
      else if (k === 'num') extra.push(`data-num="${v}"`);
    }
    let a = attrs || '';
    if (classes.length) {
      if (/class="/.test(a)) a = a.replace(/class="([^"]*)"/, (m, c) => `class="${c} ${classes.join(' ')}"`);
      else extra.push(`class="${classes.join(' ')}"`);
    }
    return `<${tag}${a}${extra.length ? ' ' + extra.join(' ') : ''}>${anchors}`;
  });
  return html.replace(new RegExp(`${MARK_OPEN}[^${MARK_CLOSE}]*${MARK_CLOSE}`, 'g'), '');
}

function sanitize($, root) {
  root.find('*').each((_, el) => {
    const name = el.tagName && el.tagName.toLowerCase();
    if (!name) return;
    const $el = $(el);
    if (DROP_WITH_CONTENT.has(name)) {
      $el.remove();
      return;
    }
    if (!ALLOWED_TAGS.has(name)) {
      $el.replaceWith($el.contents());
      return;
    }
    for (const attr of Object.keys(el.attribs || {})) {
      const lower = attr.toLowerCase();
      if (!ALLOWED_ATTRS.has(lower)) $el.removeAttr(attr);
    }
    const href = $el.attr('href');
    if (href && /^\s*(javascript|data|vbscript):/i.test(href)) $el.removeAttr('href');
    if (name === 'a' && href && /^https?:/i.test(href)) $el.attr('class', ((($el.attr('class') || '') + ' ext').trim()));
    const src = $el.attr('src');
    if (name === 'img' && (!src || /^\s*(javascript|https?):/i.test(src))) $el.remove();
  });
}

function textOf($, el) {
  return $(el).text().replace(/\s+/g, ' ').trim();
}

function isAllCaps(s) {
  const letters = s.replace(/[^\p{L}]/gu, '');
  return letters.length > 12 && letters === letters.toUpperCase() && letters !== letters.toLowerCase();
}

function sentenceCase(s) {
  const lower = s.toLocaleLowerCase('uz');
  // Capitalise the first letter of the text and after a quote at the start.
  return lower.replace(/^([^\p{L}]*)(\p{L})/u, (m, pre, ch) => pre + ch.toLocaleUpperCase('uz'))
    .replace(/([“"«]\s*)(\p{L})/gu, (m, q, ch) => q + ch.toLocaleUpperCase('uz'));
}

function displayTitle(raw) {
  const t = raw.replace(/\s+/g, ' ').trim();
  return isAllCaps(t) ? sentenceCase(t) : t;
}

// ---- footnotes -------------------------------------------------------------

function extractNotes($) {
  const notes = new Map();
  $('li[id^="footnote-"], li[id^="endnote-"]').each((_, li) => {
    const $li = $(li);
    const id = $li.attr('id');
    $li.find('a[href^="#footnote-ref-"], a[href^="#endnote-ref-"]').remove();
    notes.set(id, $li.html().trim());
    const $ol = $li.parent();
    $li.remove();
    if ($ol.is('ol') && !$ol.children().length) $ol.remove();
  });
  return notes;
}

// ---- splitting -------------------------------------------------------------

function splitIntoChapters($, lang, opts = {}) {
  const L = labels(lang);
  const blocks = $.root().children().toArray();
  const chapters = [];
  let cur = null;
  const start = (kind, title) => {
    cur = { kind, title, blocks: [] };
    chapters.push(cur);
  };

  // Importers that already know the chapter boundaries (EPUB spine + TOC)
  // mark the first block of each chapter with data-split="Title".
  if (blocks.some((b) => $(b).attr('data-split') !== undefined)) {
    for (const b of blocks) {
      const split = $(b).attr('data-split');
      if (split !== undefined || !cur) start('chapter', (split || '').trim() || null);
      $(b).removeAttr('data-split');
      cur.blocks.push(b);
    }
    return chapters;
  }

  // Split at the highest heading level that gives chapters of a sensible
  // size; badly formatted documents otherwise fall apart into hundreds of
  // two-paragraph "chapters".
  const totalWords = countWords($.root().text());
  let splitTag = null;
  for (const tag of ['h1', 'h2']) {
    const n = blocks.filter((b) => b.tagName === tag).length;
    const avg = totalWords / (n + 1);
    if (n && (avg >= 600 || (n <= 40 && avg >= 150))) {
      splitTag = tag;
      break;
    }
  }
  if (!splitTag) {
    // Demote the headings we are not going to split at, so the TOC stays sane.
    for (const b of blocks) if (b.tagName === 'h1') b.tagName = 'h2';
  }

  for (let i = 0; i < blocks.length; i++) {
    const b = blocks[i];
    const $b = $(b);
    if (!cur) {
      const titleAhead = $b.hasClass('tp') || ($b.hasClass('figure') && blocks.slice(i + 1, i + 3).some((x) => $(x).hasClass('tp')));
      if (titleAhead) start('title', L.titlePage);
      else start('front', L.front);
    }
    if (cur.kind === 'title' && !$b.hasClass('tp') && !$b.is('p:has(img)') && b.tagName !== splitTag) {
      start('front', L.front);
    }
    if (splitTag && b.tagName === splitTag) {
      start('chapter', null);
    } else if (!splitTag && $b.attr('data-pb') && cur.blocks.length && countWords(cur.blocks.map((x) => $(x).text()).join(' ')) > 1500) {
      start('chapter', null);
    }
    cur.blocks.push(b);
  }

  // Merge chapters that are only a heading (e.g. "I QISM" page) into the next.
  for (let i = 0; i < chapters.length - 1; i++) {
    const ch = chapters[i];
    if (ch.kind === 'title') continue;
    const words = countWords(ch.blocks.filter((b) => !/^h[1-6]$/.test(b.tagName)).map((b) => $(b).text()).join(' '));
    if (words < 40 && !ch.blocks.some((b) => $(b).find('img').length || b.tagName === 'img')) {
      chapters[i + 1].blocks = ch.blocks.concat(chapters[i + 1].blocks);
      if (chapters[i + 1].kind !== 'title') chapters[i + 1].kind = ch.kind === 'chapter' ? 'chapter' : chapters[i + 1].kind;
      chapters.splice(i, 1);
      i--;
    }
  }

  // Very long chapters (books without headings, or one giant section) are cut
  // into parts of ~4000-8000 words, preferring a sub-heading as the cut point,
  // so phones never have to lay out a whole book at once.
  const maxWords = opts.maxChapterWords || 12000;
  const out = [];
  for (const ch of chapters) {
    const words = countWords(ch.blocks.map((b) => $(b).text()).join(' '));
    if (words <= maxWords) {
      out.push(ch);
      continue;
    }
    let part = { ...ch, blocks: [] };
    let acc = 0;
    let n = 1;
    const baseTitle = ch.title;
    for (const b of ch.blocks) {
      const isSubHeading = /^h[2-4]$/.test(b.tagName);
      if (part.blocks.length && ((acc >= 4000 && isSubHeading) || acc >= 8000)) {
        out.push(part);
        n++;
        part = { kind: 'chapter', title: isSubHeading ? null : `${baseTitle || L.chapter} (${n})`, blocks: [] };
        acc = 0;
      }
      part.blocks.push(b);
      acc += countWords($(b).text());
    }
    if (part.blocks.length) out.push(part);
  }
  return out;
}

// ---- assembling ------------------------------------------------------------

function buildChapters(html, { lang, title: bookTitle, maxChapterWords } = {}) {
  html = resolveMarkers(html);
  const $ = cheerio.load(html, null, false);
  const notes = extractNotes($);
  sanitize($, $.root());

  // Chapter numbers ("1") go inside the heading they precede.
  // If a short note sits between the number and the title, the title moves up.
  $('p.chapnum').each((_, p) => {
    const $p = $(p);
    const num = textOf($, p).replace(/\.$/, '');
    let $h = $p.next();
    if (!$h.is('h1,h2')) {
      const ahead = $p.nextAll().slice(0, 4).filter('h1,h2').first();
      if (ahead.length) {
        $p.after(ahead);
        $h = ahead;
      }
    }
    if ($h.is('h1,h2')) $h.attr('data-num', num);
    $p.remove();
  });
  // Headings that are empty after cleanup are useless; bold inside a heading
  // is redundant.
  $('h1,h2,h3,h4,h5,h6').each((_, h) => {
    if (!textOf($, h)) $(h).remove();
    else $(h).find('strong,b').each((__, s) => $(s).replaceWith($(s).contents()));
  });
  $('h1[data-num],h2[data-num]').each((_, h) => {
    const $h = $(h);
    const num = $h.attr('data-num');
    // "6" + "6. YAKUNIY NUSXA" -> number shown once.
    const first = $h.contents().filter((__, n) => n.type !== 'text' || n.data.trim()).first();
    const escaped = num.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const dup = new RegExp(`^\\s*${escaped}\\s*[.:)–-]?\\s+`);
    if (first.length && first[0].type === 'text' && dup.test(first[0].data)) first[0].data = first[0].data.replace(dup, '');
    $h.prepend(`<span class="hnum">${num}</span>`);
  });
  // Image-only paragraphs become figures; tables get a scroll wrapper.
  $('p').each((_, p) => {
    const $p = $(p);
    if ($p.find('img').length && !textOf($, p)) $p.addClass('figure');
  });
  $('table').each((_, t) => {
    $(t).wrap('<div class="table-wrap"></div>');
  });

  const L = labels(lang);
  const raw = splitIntoChapters($, lang, { maxChapterWords });
  const chapters = [];
  const toc = [];
  const anchors = {};
  let hCounter = 0;

  raw.forEach((ch, ci) => {
    const $c = cheerio.load('<section></section>', null, false);
    const $sec = $c('section');
    for (const b of ch.blocks) $sec.append($.html(b));

    // Sub-headings repeated inside one chapter ("A-daraja", "B-daraja" in each
    // exercise block) are labels, not sections: keep them out of the TOC.
    const seen = new Map();
    $sec.find('h2,h3').each((_, h) => {
      const key = textOf($c, h).toLowerCase();
      seen.set(key, (seen.get(key) || 0) + 1);
    });
    $sec.find('h2,h3').each((_, h) => {
      if (seen.get(textOf($c, h).toLowerCase()) > 1) h.tagName = 'h4';
    });

    // Headings -> ids + toc.
    let chTitle = ch.title;
    $sec.find('h1,h2,h3').each((_, h) => {
      const $h = $c(h);
      const id = $h.attr('id') || `h${++hCounter}`;
      $h.attr('id', id);
      const num = $h.attr('data-num');
      const text = displayTitle($h.clone().find('.hnum').remove().end().text());
      const full = num ? `${num}. ${text}` : text;
      const level = +h.tagName[1];
      if (!chTitle && (level === 1 || ch.kind === 'chapter')) chTitle = full;
      toc.push({ title: full, level, chapter: ci, anchor: id });
    });
    if (!chTitle) chTitle = ch.kind === 'title' ? L.titlePage : ch.kind === 'front' ? L.front : `${L.chapter} ${ci + 1}`;
    if (ch.kind !== 'chapter' || !toc.some((t) => t.chapter === ci)) {
      const firstForChapter = toc.findIndex((t) => t.chapter === ci);
      const entry = { title: chTitle, level: 1, chapter: ci, anchor: null };
      if (firstForChapter === -1) toc.push(entry);
      else if (toc[firstForChapter].level !== 1) toc.splice(firstForChapter, 0, entry);
    }

    // Footnotes used in this chapter.
    const used = [];
    $sec.find('a[href^="#footnote-"], a[href^="#endnote-"]').each((_, a) => {
      const $a = $c(a);
      const id = $a.attr('href').slice(1);
      if (!notes.has(id)) return;
      const n = id.replace(/^(foot|end)note-/, '');
      const fnId = `${id.startsWith('end') ? 'en' : 'fn'}-${n}`;
      $a.attr('href', `#${fnId}`).attr('class', 'fnref').attr('data-fn', fnId).removeAttr('id').text(n);
      const $sup = $a.parent('sup');
      if ($sup.length) $sup.replaceWith($a);
      if (!used.some((u) => u.fnId === fnId)) used.push({ id, fnId, n });
    });
    if (used.length) {
      const items = used.map((u) => `<li id="${u.fnId}" value="${u.n}">${notes.get(u.id)}</li>`).join('');
      $sec.append(`<aside class="footnotes"><ol>${items}</ol></aside>`);
    }

    // Remove Word bookmark anchors nobody links to; keep a map of the rest.
    $sec.find('[id]').each((_, el) => {
      anchors[$c(el).attr('id')] = ci;
    });
    $sec.find('[data-pb]').removeAttr('data-pb');
    $sec.children().each((bi, el) => {
      $c(el).attr('data-b', String(bi));
    });

    const text = $sec.text();
    chapters.push({
      id: `c${ci + 1}`,
      title: chTitle,
      kind: ch.kind,
      html: $sec.html(),
      words: countWords(text),
      chars: text.replace(/\s+/g, ' ').length,
    });
  });

  // Internal links: point to the chapter that holds the target.
  const usedIds = new Set();
  for (const ch of chapters) {
    const $c = cheerio.load(ch.html, null, false);
    let changed = false;
    $c('a[href^="#"]').each((_, a) => {
      const $a = $c(a);
      const id = $a.attr('href').slice(1);
      usedIds.add(id);
      if (anchors[id] !== undefined && !$a.hasClass('fnref')) {
        $a.attr('data-c', String(anchors[id]));
        changed = true;
      }
    });
    if (changed) ch.html = $c.html();
  }
  for (const ch of chapters) {
    const $c = cheerio.load(ch.html, null, false);
    let changed = false;
    $c('a[id]:not([href])').each((_, a) => {
      if (!usedIds.has($c(a).attr('id'))) {
        $c(a).replaceWith($c(a).contents());
        changed = true;
      }
    });
    if (changed) ch.html = $c.html();
  }
  for (const id of Object.keys(anchors)) if (!usedIds.has(id) && !toc.some((t) => t.anchor === id)) delete anchors[id];

  return { chapters, toc, notesCount: notes.size, bookTitle };
}

module.exports = { buildChapters, sanitize, displayTitle };
