'use strict';

// Plain text (.txt and legacy .doc without LibreOffice) -> annotated HTML.
// Without formatting we only have line shapes to go on: short lines that look
// like chapter titles become headings, everything else paragraphs.

const { escapeHtml, MARK_OPEN, MARK_CLOSE } = require('./util');
const { CHAPTER_RE } = require('./docx');

function decodeText(buffer) {
  if (buffer[0] === 0xff && buffer[1] === 0xfe) return buffer.slice(2).toString('utf16le');
  if (buffer[0] === 0xef && buffer[1] === 0xbb && buffer[2] === 0xbf) return buffer.slice(3).toString('utf8');
  const utf8 = buffer.toString('utf8');
  // Lots of replacement chars => it was a Windows-1251/1252 file.
  const bad = (utf8.match(/�/g) || []).length;
  if (bad > utf8.length / 200) {
    const cyrillic = new TextDecoder('windows-1251').decode(buffer);
    if (/[а-яё]{4}/i.test(cyrillic)) return cyrillic;
    return new TextDecoder('windows-1252').decode(buffer);
  }
  return utf8;
}

const TOC_TITLE_RE = /^(mundarija|содержание|оглавление|contents|table of contents)$/i;
const LABEL_RE = /^(\d{1,3}|[IVXLC]{1,6})\s*[-–—.]?\s*(mavzu|bob|qism|глава|тема|часть|chapter|part)\.?$/i;

function textToHtml(text) {
  const lines = text.replace(/\r\n?/g, '\n').replace(/\f/g, '\n\f\n').split('\n');
  const out = [];
  let pendingPage = false;
  let para = [];
  let inToc = 0; // lines left in a hand-typed table of contents
  let pendingLabel = null; // "1-mavzu" waiting for its title on the next line
  const flush = () => {
    if (!para.length) return;
    const t = para.join(' ').replace(/\s+/g, ' ').trim();
    para = [];
    if (!t) return;
    const pb = pendingPage ? `${MARK_OPEN}pb${MARK_CLOSE}` : '';
    if (pendingPage) inToc = 0;
    pendingPage = false;
    if (inToc > 0) {
      inToc--;
      out.push(`<p>${pb}${escapeHtml(t)}</p>`);
      return;
    }
    if (TOC_TITLE_RE.test(t)) {
      inToc = 60;
      out.push(`<h1>${pb}${escapeHtml(t)}</h1>`);
      return;
    }
    if (pendingLabel) {
      const label = pendingLabel;
      pendingLabel = null;
      if (t.length <= 160 && !/[.;,]$/.test(t)) {
        out.push(`<h1>${label.pb}${escapeHtml(label.text)}. ${escapeHtml(t)}</h1>`);
        return;
      }
      out.push(`<h1>${label.pb}${escapeHtml(label.text)}</h1>`);
    }
    if (LABEL_RE.test(t)) {
      pendingLabel = { text: t.replace(/\.$/, ''), pb };
      return;
    }
    const letters = t.replace(/[^\p{L}]/gu, '');
    const caps = letters.length > 3 && letters === letters.toUpperCase() && letters !== letters.toLowerCase();
    if (t.length <= 120 && (CHAPTER_RE.test(t) || (caps && t.length <= 90))) {
      out.push(`<h1>${pb}${escapeHtml(t)}</h1>`);
    } else {
      out.push(`<p>${pb}${escapeHtml(t)}</p>`);
    }
  };
  let blankRun = 0;
  for (const raw of lines) {
    if (raw === '\f') {
      flush();
      pendingPage = true;
      continue;
    }
    const line = raw.trim();
    if (!line) {
      blankRun++;
      flush();
      if (blankRun >= 4) pendingPage = true;
      continue;
    }
    blankRun = 0;
    // Indented first line or a short line both start a new paragraph in most
    // text exports, so treat each source line as its own paragraph.
    para.push(line);
    flush();
  }
  flush();
  return out.join('\n');
}

module.exports = { decodeText, textToHtml };
