'use strict';

const path = require('path').posix;
const JSZip = require('jszip');
const cheerio = require('cheerio');
const { escapeHtml } = require('./util');

// ---- import ----------------------------------------------------------------

const MEDIA = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', gif: 'image/gif', webp: 'image/webp', svg: 'image/svg+xml' };

async function readText(zip, p) {
  const f = zip.file(p) || zip.file(decodeURIComponent(p));
  return f ? f.async('string') : null;
}

function parseNcx(xml, base) {
  const $ = cheerio.load(xml, { xml: true });
  const out = [];
  const walk = (el, level) => {
    $(el).children('navPoint').each((_, np) => {
      const label = $(np).children('navLabel').first().text().replace(/\s+/g, ' ').trim();
      const src = $(np).children('content').attr('src');
      if (src) out.push({ title: label, level, href: path.join(base, decodeURIComponent(src)) });
      walk(np, level + 1);
    });
  };
  walk($('navMap').first(), 1);
  return out;
}

function parseNav(xml, base) {
  const $ = cheerio.load(xml, { xml: true });
  let nav = $('nav').filter((_, n) => /toc/.test($(n).attr('epub:type') || '')).first();
  if (!nav.length) nav = $('nav').first();
  const out = [];
  const walk = (ol, level) => {
    $(ol).children('li').each((_, li) => {
      const a = $(li).children('a, span').first();
      const href = a.attr('href');
      if (href) out.push({ title: a.text().replace(/\s+/g, ' ').trim(), level, href: path.join(base, decodeURIComponent(href)) });
      $(li).children('ol').each((__, sub) => walk(sub, level + 1));
    });
  };
  nav.children('ol').each((_, ol) => walk(ol, 1));
  return out;
}

function unwrapContainers($, $root) {
  for (let guard = 0; guard < 6; guard++) {
    const kids = $root.children().toArray();
    let changed = false;
    for (const k of kids) {
      if (!/^(div|section|article|main|body|span)$/.test(k.tagName)) continue;
      const $k = $(k);
      const hasBlocks = $k.children('p,div,h1,h2,h3,h4,h5,h6,ul,ol,table,blockquote,section,figure,pre,img').length > 0;
      if (hasBlocks) {
        $k.replaceWith($k.contents());
        changed = true;
      }
    }
    if (!changed) break;
  }
  // Bare text at top level becomes a paragraph.
  $root.contents().each((_, n) => {
    if (n.type === 'text' && n.data.trim()) $(n).wrap('<p></p>');
  });
}

async function importEpub(buffer, ctx) {
  const zip = await JSZip.loadAsync(buffer);
  const container = await readText(zip, 'META-INF/container.xml');
  if (!container) throw new Error('EPUB: META-INF/container.xml topilmadi');
  const opfPath = (container.match(/full-path="([^"]+)"/) || [])[1];
  const opf = await readText(zip, opfPath);
  if (!opf) throw new Error('EPUB: OPF fayl topilmadi');
  const base = path.dirname(opfPath) === '.' ? '' : path.dirname(opfPath);
  const $o = cheerio.load(opf, { xml: true });

  const meta = {
    title: $o('dc\\:title, title').first().text().trim(),
    authors: $o('dc\\:creator, creator').map((_, e) => $o(e).text().trim()).get().filter(Boolean),
    lang: $o('dc\\:language, language').first().text().trim().slice(0, 2),
  };
  if (/^unknown$/i.test(meta.title)) meta.title = '';

  const items = {};
  $o('manifest item').each((_, it) => {
    const $it = $o(it);
    items[$it.attr('id')] = { href: path.join(base, decodeURIComponent($it.attr('href'))), type: $it.attr('media-type'), props: $it.attr('properties') || '' };
  });
  const spine = $o('spine itemref').map((_, r) => items[$o(r).attr('idref')]).get().filter((it) => it && /html/.test(it.type));

  let toc = [];
  const navItem = Object.values(items).find((it) => /\bnav\b/.test(it.props));
  const ncxItem = Object.values(items).find((it) => it.type === 'application/x-dtbncx+xml');
  if (navItem) toc = parseNav(await readText(zip, navItem.href), path.dirname(navItem.href));
  if (!toc.length && ncxItem) toc = parseNcx(await readText(zip, ncxItem.href), path.dirname(ncxItem.href));

  // Cover image.
  const coverItem = Object.values(items).find((it) => /cover-image/.test(it.props)) ||
    items[$o('meta[name="cover"]').attr('content')];
  if (coverItem && /^image\//.test(coverItem.type || '')) {
    const f = zip.file(coverItem.href);
    if (f) ctx.setCover(await f.async('nodebuffer'));
  }

  const docTitles = new Map(); // spine href -> toc title (level 1 or first)
  for (const t of toc) {
    const file = t.href.split('#')[0];
    if (!docTitles.has(file) || t.level < docTitles.get(file).level) docTitles.set(file, t);
  }
  const useToc = toc.length > 0 && spine.length > 2;

  const parts = [];
  let skippedCover = false;
  for (let i = 0; i < spine.length; i++) {
    const it = spine[i];
    const xml = await readText(zip, it.href);
    if (!xml) continue;
    const $ = cheerio.load(xml, { xml: false });
    const $body = $('body');
    const docDir = path.dirname(it.href);

    // Images: copy into the book and rewrite src.
    const imgs = $body.find('img, image').toArray();
    for (const img of imgs) {
      const $img = $(img);
      const src = $img.attr('src') || $img.attr('xlink:href') || $img.attr('href');
      if (!src) continue;
      const full = path.join(docDir, decodeURIComponent(src.split('#')[0]));
      const f = zip.file(full);
      const ext = full.split('.').pop().toLowerCase();
      const name = f ? await ctx.addImage(await f.async('nodebuffer'), MEDIA[ext] || 'image/jpeg') : null;
      if (!name) {
        $img.remove();
        continue;
      }
      if (img.tagName === 'image') $img.replaceWith(`<img src="${name}" alt="">`);
      else $img.attr('src', name);
    }
    // Links between spine documents -> in-book anchors.
    $body.find('a[href]').each((_, a) => {
      const $a = $(a);
      const href = $a.attr('href');
      if (/^[a-z]+:/i.test(href)) return;
      const [file, frag] = href.split('#');
      if (frag) $a.attr('href', `#${frag}`);
      else if (file) $a.attr('href', `#doc-${spine.findIndex((s) => s.href === path.join(docDir, decodeURIComponent(file)))}`);
    });
    unwrapContainers($, $body);

    const text = $body.text().replace(/\s+/g, ' ').trim();
    // A cover page that only holds the cover picture is shown as the cover.
    if (i === 0 && !skippedCover && text.length < 20 && ctx.hasCover()) {
      skippedCover = true;
      continue;
    }
    const first = $body.children().first();
    if (!first.length) continue;
    first.attr('id', first.attr('id') || `doc-${i}`);
    if (!first.attr('id').startsWith('doc-')) first.before(`<a id="doc-${i}"></a>`);

    if (useToc) {
      const t = docTitles.get(it.href);
      if (t && t.level === 1) first.attr('data-split', t.title || ' ');
      else if (i === 0) first.attr('data-split', t ? t.title : ' ');
    } else if (spine.length > 2) {
      first.attr('data-split', ' ');
    }
    parts.push($body.html());
  }

  if (!parts.length) throw new Error('EPUB ichida matn topilmadi');
  return { html: parts.join('\n'), meta, toc: useToc ? toc : null, preSplit: spine.length > 2 };
}

// ---- export ----------------------------------------------------------------

function toXhtml(html) {
  const $ = cheerio.load(html, null, false);
  $('[data-b]').removeAttr('data-b');
  $('[data-c]').removeAttr('data-c');
  $('a.fnref').attr('epub:type', 'noteref');
  $('aside.footnotes').attr('epub:type', 'footnotes');
  return $.xml();
}

function xhtmlDoc(title, body, lang) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="${lang}" xml:lang="${lang}">
<head><meta charset="UTF-8"/><title>${escapeHtml(title)}</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
<body>${body}</body>
</html>`;
}

const EPUB_CSS = `body{font-family:serif;line-height:1.5;margin:0 4%;}
h1,h2,h3{line-height:1.25;page-break-after:avoid;}
h1{font-size:1.5em;text-align:center;margin:1.5em 0 1em;}
h2{font-size:1.25em;margin:1.4em 0 .6em;}
h3{font-size:1.1em;margin:1.2em 0 .5em;}
p{margin:0 0 .6em;text-align:justify;text-indent:1.2em;}
.center,.tp{text-align:center;text-indent:0;}
.right{text-align:right;}
.tp1{font-size:1.8em;font-weight:bold;}.tp2{font-size:1.3em;}
.hnum{display:block;font-size:2em;margin-bottom:.3em;}
.figure{text-align:center;text-indent:0;}
img{max-width:100%;height:auto;}
table{border-collapse:collapse;width:100%;}td,th{border:1px solid #999;padding:.3em;}
aside.footnotes{font-size:.85em;border-top:1px solid #999;margin-top:2em;}
a.fnref{vertical-align:super;font-size:.75em;}`;

async function buildEpub({ id, title, authors, lang, chapters, toc, images, cover }) {
  const zip = new JSZip();
  zip.file('mimetype', 'application/epub+zip', { compression: 'STORE' });
  zip.file('META-INF/container.xml', `<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>`);
  const oebps = zip.folder('OEBPS');
  oebps.file('style.css', EPUB_CSS);
  const manifest = ['<item id="css" href="style.css" media-type="text/css"/>', '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>', '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'];
  const spine = [];
  for (const [name, img] of images) {
    const isCover = cover && name === cover;
    oebps.file(name, img.buffer);
    manifest.push(`<item id="${name.replace(/[^a-z0-9]/gi, '_')}" href="${name}" media-type="${img.type}"${isCover ? ' properties="cover-image"' : ''}/>`);
  }
  if (cover) {
    oebps.file('cover.xhtml', xhtmlDoc(title, `<div style="text-align:center"><img src="${cover}" alt="" style="max-height:100%"/></div>`, lang));
    manifest.push('<item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>');
    spine.push('<itemref idref="cover" linear="no"/>');
  }
  chapters.forEach((ch, i) => {
    const file = `ch${String(i + 1).padStart(3, '0')}.xhtml`;
    oebps.file(file, xhtmlDoc(ch.title, toXhtml(ch.html), lang));
    manifest.push(`<item id="ch${i + 1}" href="${file}" media-type="application/xhtml+xml"/>`);
    spine.push(`<itemref idref="ch${i + 1}"/>`);
  });
  const chFile = (i) => `ch${String(i + 1).padStart(3, '0')}.xhtml`;
  const href = (t) => chFile(t.chapter) + (t.anchor ? `#${t.anchor}` : '');

  // nav.xhtml with nested lists.
  let navHtml = '<ol>';
  let depth = 1;
  toc.forEach((t, i) => {
    const level = Math.min(t.level, depth + 1);
    if (i > 0) {
      if (level > depth) navHtml += '<ol>';
      else {
        navHtml += '</li>';
        for (let d = depth; d > level; d--) navHtml += '</ol></li>';
      }
    }
    depth = level;
    navHtml += `<li><a href="${href(t)}">${escapeHtml(t.title)}</a>`;
  });
  navHtml += '</li>';
  for (let d = depth; d > 1; d--) navHtml += '</ol></li>';
  navHtml += '</ol>';
  oebps.file('nav.xhtml', xhtmlDoc(title, `<nav epub:type="toc" id="toc"><h1>${escapeHtml(title)}</h1>${toc.length ? navHtml : '<ol><li><a href="ch001.xhtml">—</a></li></ol>'}</nav>`, lang));

  // toc.ncx for older readers.
  let ncx = '';
  let open = 0;
  let prev = 0;
  toc.forEach((t, i) => {
    const level = Math.min(t.level, prev + 1);
    if (i > 0) for (let d = prev; d >= level; d--) { ncx += '</navPoint>'; open--; }
    ncx += `<navPoint id="np${i + 1}" playOrder="${i + 1}"><navLabel><text>${escapeHtml(t.title)}</text></navLabel><content src="${href(t)}"/>`;
    open++;
    prev = level;
  });
  ncx += '</navPoint>'.repeat(open);
  oebps.file('toc.ncx', `<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="${id}"/></head>
<docTitle><text>${escapeHtml(title)}</text></docTitle><navMap>${ncx}</navMap></ncx>`);

  const modified = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
  oebps.file('content.opf', `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid" xml:lang="${lang}">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="uid">urn:mbook:${escapeHtml(id)}</dc:identifier>
<dc:title>${escapeHtml(title)}</dc:title>
${authors.map((a) => `<dc:creator>${escapeHtml(a)}</dc:creator>`).join('\n')}
<dc:language>${lang}</dc:language>
<meta property="dcterms:modified">${modified}</meta>
${cover ? `<meta name="cover" content="${cover.replace(/[^a-z0-9]/gi, '_')}"/>` : ''}
</metadata>
<manifest>${manifest.join('\n')}</manifest>
<spine toc="ncx">${spine.join('\n')}</spine>
</package>`);
  return zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE', compressionOptions: { level: 9 }, mimeType: 'application/epub+zip' });
}

module.exports = { importEpub, buildEpub };
