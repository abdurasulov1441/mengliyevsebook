/* Mengliyev's eBook reader engine.
 *
 * One reader for every place a book is opened:
 *   - offline:  reader.html?book=<folder>          (folder holds book.js + images/)
 *   - server:   reader.html?remote=<id>&rt=<token> (book served by the API)
 *   - app:      loaded in a WebView, the host calls Reader.open({...}) and
 *               listens on the "ReaderBridge" JavaScript channel.
 */
(function () {
  'use strict';

  // ---------------------------------------------------------------- helpers
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const debounce = (fn, ms) => {
    let t;
    return (...a) => {
      clearTimeout(t);
      t = setTimeout(() => fn(...a), ms);
    };
  };
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
  const storage = {
    get(k, d) {
      try {
        const v = localStorage.getItem(k);
        return v ? JSON.parse(v) : d;
      } catch (e) {
        return d;
      }
    },
    set(k, v) {
      try {
        localStorage.setItem(k, JSON.stringify(v));
      } catch (e) { /* private mode / quota */ }
    },
  };

  // Lucide icons (ISC licence), same set as the app.
  const ICONS = {
    back: '<path d="m15 18-6-6 6-6" />',
    search: '<path d="m21 21-4.34-4.34" /><circle cx="11" cy="11" r="8" />',
    bookmark: '<path d="M17 3a2 2 0 0 1 2 2v15a1 1 0 0 1-1.496.868l-4.512-2.578a2 2 0 0 0-1.984 0l-4.512 2.578A1 1 0 0 1 5 20V5a2 2 0 0 1 2-2z" />',
    bookmarkOn: '<path fill="currentColor" d="M17 3a2 2 0 0 1 2 2v15a1 1 0 0 1-1.496.868l-4.512-2.578a2 2 0 0 0-1.984 0l-4.512 2.578A1 1 0 0 1 5 20V5a2 2 0 0 1 2-2z" />',
    list: '<path d="M3 5h.01" /><path d="M3 12h.01" /><path d="M3 19h.01" /><path d="M8 5h13" /><path d="M8 12h13" /><path d="M8 19h13" />',
    type: '<path d="m15 16 2.536-7.328a1.02 1.02 1 0 1 1.928 0L22 16" /><path d="M15.697 14h5.606" /><path d="m2 16 4.039-9.69a.5.5 0 0 1 .923 0L11 16" /><path d="M3.304 13h6.392" />',
    prev: '<path d="m11 17-5-5 5-5" /><path d="m18 17-5-5 5-5" />',
    next: '<path d="m6 17 5-5-5-5" /><path d="m13 17 5-5-5-5" />',
    close: '<path d="M18 6 6 18" /><path d="m6 6 12 12" />',
    note: '<path d="M13 21h8" /><path d="m15 5 4 4" /><path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z" />',
    copy: '<rect width="14" height="14" x="8" y="8" rx="2" ry="2" /><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2" />',
    trash: '<path d="M10 11v6" /><path d="M14 11v6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" /><path d="M3 6h18" /><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />',
  };
  const svg = (name) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICONS[name]}</svg>`;

  const I18N = {
    uz: {
      previewEnd: 'Parcha tugadi', previewText: "Davomini o'qish uchun kitobni kutubxonangizga qo'shing", buyFull: "To'liq kitobni olish", previewBadge: 'Parcha',
      pageTurn: 'Varaqlash', turnSlide: 'Surish', turnFlip: 'Varaq', turnFade: 'Xira', turnNone: "Yo'q", turnSpeed: 'Tezlik', fast: 'Tez', normal: "O'rta", slow: 'Sekin',
      loading: 'Kitob yuklanmoqda…', errorTitle: "Kitobni ochib bo'lmadi", back: 'Orqaga', contents: 'Mundarija', bookmarks: "Xatcho'plar",
      notes: 'Belgilar', search: 'Qidirish', fontSize: 'Shrift', theme: 'Fon', font: 'Harf', spacing: 'Qator', margins: 'Chekka', align: 'Tekislash',
      justify: 'Kenglik', left: 'Chap', mode: 'Rejim', paged: 'Sahifa', scroll: 'Aylantirish', brightness: "Yorug'lik", delete: "O'chirish",
      cancel: 'Bekor', save: 'Saqlash', page: 'bet', of: '/', minLeft: 'daq. qoldi', chapterEnd: 'Bob tugadi', nextChapter: 'Keyingi bob',
      bookEnd: 'Kitob tugadi', noBookmarks: "Xatcho'plar yo'q.\nYuqoridagi belgini bosib sahifani saqlang.", noNotes: "Belgilar yo'q.\nMatnni bosib turing va rangni tanlang.",
      searchHint: "Kamida 2 ta harf yozing", searching: 'Qidirilmoqda…', found: 'ta natija', notFound: 'Hech narsa topilmadi', copied: 'Nusxa olindi',
      bookmarkAdded: "Xatcho'p qo'shildi", bookmarkRemoved: "Xatcho'p olib tashlandi", notePlaceholder: 'Izoh yozing…', chapter: 'Bob', percentRead: "o'qildi",
    },
    ru: {
      previewEnd: 'Конец фрагмента', previewText: 'Чтобы читать дальше, добавьте книгу в библиотеку', buyFull: 'Получить полную книгу', previewBadge: 'Фрагмент',
      pageTurn: 'Листание', turnSlide: 'Сдвиг', turnFlip: 'Страница', turnFade: 'Растворение', turnNone: 'Нет', turnSpeed: 'Скорость', fast: 'Быстро', normal: 'Средне', slow: 'Медленно',
      loading: 'Загрузка книги…', errorTitle: 'Не удалось открыть книгу', back: 'Назад', contents: 'Оглавление', bookmarks: 'Закладки',
      notes: 'Заметки', search: 'Поиск', fontSize: 'Шрифт', theme: 'Фон', font: 'Гарнитура', spacing: 'Интервал', margins: 'Поля', align: 'Выравнивание',
      justify: 'По ширине', left: 'Влево', mode: 'Режим', paged: 'Страницы', scroll: 'Прокрутка', brightness: 'Яркость', delete: 'Удалить',
      cancel: 'Отмена', save: 'Сохранить', page: 'стр.', of: '/', minLeft: 'мин. осталось', chapterEnd: 'Конец главы', nextChapter: 'Следующая глава',
      bookEnd: 'Конец книги', noBookmarks: 'Закладок нет.\nНажмите значок вверху, чтобы сохранить страницу.', noNotes: 'Заметок нет.\nВыделите текст и выберите цвет.',
      searchHint: 'Введите минимум 2 буквы', searching: 'Поиск…', found: 'результатов', notFound: 'Ничего не найдено', copied: 'Скопировано',
      bookmarkAdded: 'Закладка добавлена', bookmarkRemoved: 'Закладка удалена', notePlaceholder: 'Напишите заметку…', chapter: 'Глава', percentRead: 'прочитано',
    },
    en: {
      previewEnd: 'End of sample', previewText: 'Get the book to keep reading', buyFull: 'Get the full book', previewBadge: 'Sample',
      pageTurn: 'Page turn', turnSlide: 'Slide', turnFlip: 'Curl', turnFade: 'Fade', turnNone: 'None', turnSpeed: 'Speed', fast: 'Fast', normal: 'Normal', slow: 'Slow',
      loading: 'Loading book…', errorTitle: 'Could not open the book', back: 'Back', contents: 'Contents', bookmarks: 'Bookmarks',
      notes: 'Notes', search: 'Search', fontSize: 'Text size', theme: 'Theme', font: 'Font', spacing: 'Spacing', margins: 'Margins', align: 'Align',
      justify: 'Justify', left: 'Left', mode: 'Mode', paged: 'Pages', scroll: 'Scroll', brightness: 'Brightness', delete: 'Delete',
      cancel: 'Cancel', save: 'Save', page: 'p.', of: '/', minLeft: 'min left', chapterEnd: 'End of chapter', nextChapter: 'Next chapter',
      bookEnd: 'The end', noBookmarks: 'No bookmarks yet.\nTap the icon at the top to save a page.', noNotes: 'No highlights yet.\nPress and hold text, then pick a colour.',
      searchHint: 'Type at least 2 letters', searching: 'Searching…', found: 'results', notFound: 'Nothing found', copied: 'Copied',
      bookmarkAdded: 'Bookmark added', bookmarkRemoved: 'Bookmark removed', notePlaceholder: 'Write a note…', chapter: 'Chapter', percentRead: 'read',
    },
  };
  let T = I18N.uz;

  // Bundled fonts (fonts/*.ttf). Lora backs up glyphs others lack (Ҳ, ʻ).
  const FONTS = {
    serif: '"Literata", "Lora", Georgia, serif',
    lora: '"Lora", Georgia, serif',
    pt: '"PT Serif", "Lora", Georgia, serif',
    sans: '"Inter", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
  };
  const DEFAULT_SETTINGS = {
    fontSize: window.innerWidth >= 900 ? 20 : 19,
    theme: window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light',
    font: 'serif',
    lineHeight: 1.6,
    margin: window.innerWidth >= 900 ? 40 : 22,
    align: 'justify',
    mode: 'paged',
    brightness: 0,
    pageTurn: 'slide', // slide | flip | fade | none
    turnSpeed: 'normal', // fast | normal | slow
  };

  // ------------------------------------------------------------------ state
  const S = {
    cfg: null,
    book: null,
    ch: 0, // chapter index
    page: 0,
    pages: 1,
    W: 0,
    H: 0,
    settings: { ...DEFAULT_SETTINGS },
    bookmarks: [],
    highlights: [],
    charsBefore: [],
    totalChars: 1,
    textCache: [], // per chapter: array of block texts (for search)
    ui: false,
    selHighlight: null, // highlight being edited via the toolbar
    pendingRange: null,
    lastPos: null,
    updatedAt: 0,
  };

  const els = {};

  // ------------------------------------------------------------------ host bridge
  function post(type, data) {
    const msg = JSON.stringify(Object.assign({ type }, data || {}));
    try {
      if (window.ReaderBridge && window.ReaderBridge.postMessage) window.ReaderBridge.postMessage(msg);
      else if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) window.flutter_inappwebview.callHandler('reader', msg);
      else if (window.parent && window.parent !== window) window.parent.postMessage({ mbook: true, type, ...data }, '*');
    } catch (e) { /* host gone */ }
  }
  const isEmbedded = () => !!(window.ReaderBridge || window.flutter_inappwebview || (S.cfg && S.cfg.embedded));

  // ------------------------------------------------------------------ config
  function configFromLocation() {
    const q = new URLSearchParams(location.search);
    if (window.READER_CONFIG) return window.READER_CONFIG;
    if (q.get('remote')) {
      const api = (q.get('api') || '').replace(/\/$/, '');
      const id = q.get('remote');
      const rt = q.get('rt') || '';
      return {
        bookBase: `${api}/api/books/${encodeURIComponent(id)}/package/`,
        query: rt ? `?rt=${encodeURIComponent(rt)}` : '',
        syncUrl: rt ? `${api}/api/books/${encodeURIComponent(id)}/reading?rt=${encodeURIComponent(rt)}` : null,
        backUrl: q.get('back') || null,
        uiLang: q.get('lang') || null,
      };
    }
    if (q.get('book')) {
      const b = q.get('book').replace(/\/?$/, '/');
      return { bookBase: b, backUrl: q.get('back') || 'index.html', uiLang: q.get('lang') || null };
    }
    return null;
  }

  function loadBookScript(cfg) {
    return new Promise((resolve, reject) => {
      if (cfg.bookData) return resolve(cfg.bookData);
      window.MBookLoad = (b) => resolve(b);
      const s = document.createElement('script');
      s.src = cfg.bookBase + (cfg.bookFile || 'book.js') + (cfg.query || '');
      s.onerror = () => reject(new Error(cfg.bookBase + 'book.js'));
      document.head.appendChild(s);
    });
  }

  function assetUrl(src) {
    if (!src || /^(https?:|data:|blob:|file:|\/)/i.test(src)) return src;
    return S.cfg.bookBase + src + (S.cfg.query || '');
  }

  // ------------------------------------------------------------------ persistence
  const keyFor = () => 'mbook:' + S.book.id;

  function loadLocal() {
    const saved = storage.get(keyFor(), {});
    S.settings = Object.assign({}, DEFAULT_SETTINGS, storage.get('mbook:settings', {}), S.cfg.settings || {});
    let data = { pos: saved.pos, bookmarks: saved.bookmarks || [], highlights: saved.highlights || [], updatedAt: saved.updatedAt || 0 };
    const remote = S.cfg.reading; // supplied by the host or server
    if (remote && (remote.updatedAt || 0) > data.updatedAt) {
      data = {
        pos: remote.position || remote.pos || data.pos,
        bookmarks: remote.bookmarks || data.bookmarks,
        highlights: remote.highlights || data.highlights,
        updatedAt: remote.updatedAt,
      };
    }
    S.bookmarks = data.bookmarks;
    S.highlights = data.highlights;
    S.updatedAt = data.updatedAt;
    return S.cfg.position || data.pos || null;
  }

  function saveNow() {
    if (S.book) storage.set(keyFor(), { pos: S.lastPos, bookmarks: S.bookmarks, highlights: S.highlights, updatedAt: S.updatedAt, percent: percent() });
  }
  const saveLocal = debounce(saveNow, 400);

  const syncRemote = debounce(() => {
    if (!S.cfg.syncUrl || !navigator.onLine) return;
    fetch(S.cfg.syncUrl, {
      method: 'PUT',
      headers: Object.assign({ 'Content-Type': 'application/json' }, S.cfg.syncHeaders || {}),
      body: JSON.stringify(readingState()),
      keepalive: true,
    }).catch(() => {});
  }, 2500);

  function readingState() {
    return { position: S.lastPos, percent: percent(), bookmarks: S.bookmarks, highlights: S.highlights, updatedAt: S.updatedAt };
  }

  function touchData(annotationsChanged) {
    S.updatedAt = Date.now();
    saveLocal();
    syncRemote();
    if (annotationsChanged) post('annotations', { bookmarks: S.bookmarks, highlights: S.highlights, updatedAt: S.updatedAt });
  }

  // ------------------------------------------------------------------ settings
  function applySettings() {
    const st = S.settings;
    const root = document.documentElement;
    root.dataset.theme = st.theme;
    root.style.setProperty('--font-size', st.fontSize + 'px');
    root.style.setProperty('--line-height', st.lineHeight);
    root.style.setProperty('--margin', st.margin + 'px');
    if (!FONTS[st.font]) st.font = 'serif';
    root.style.setProperty('--font', FONTS[st.font]);
    els.content.classList.toggle('justify', st.align === 'justify');
    els.content.classList.toggle('indent', st.align === 'justify');
    document.body.classList.toggle('mode-scroll', st.mode === 'scroll');
    els.dim.style.opacity = String(st.brightness / 100);
    const bg = getComputedStyle(root).getPropertyValue('--bg').trim();
    const meta = $('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', bg);
    post('theme', { theme: st.theme, background: bg, dark: st.theme === 'dark' || st.theme === 'black' });
    // Settings sheet state.
    els.fsValue.textContent = st.fontSize;
    const mark = (id, v) => $$(`#${id} button`).forEach((b) => b.classList.toggle('on', b.dataset.v === String(v)));
    mark('segTheme', st.theme);
    mark('segFont', st.font);
    mark('segLine', st.lineHeight);
    mark('segMargin', st.margin);
    mark('segAlign', st.align);
    mark('segMode', st.mode);
    mark('segTurn', st.pageTurn);
    mark('segSpeed', st.turnSpeed);
    root.style.setProperty('--turn-ms', (TURN_MS[st.turnSpeed] || TURN_MS.normal) + 'ms');
    els.brightness.value = st.brightness;
  }

  function changeSetting(key, value) {
    const pos = currentPosition();
    S.settings[key] = value;
    storage.set('mbook:settings', S.settings);
    applySettings();
    post('settings', { settings: S.settings });
    if (key === 'align') renderChapter(S.ch, { pos });
    else relayout(pos);
  }

  // ------------------------------------------------------------------ layout
  function section() {
    return els.content.firstElementChild;
  }

  function measure() {
    S.W = els.viewport.clientWidth;
    S.H = els.viewport.clientHeight;
  }

  function layout() {
    measure();
    const c = els.content;
    const st = S.settings;
    if (st.mode === 'scroll') {
      Object.assign(c.style, { columnWidth: '', columnGap: '', columnFill: '', width: '', left: '', height: '', transform: '' });
      $$('img', c).forEach((img) => (img.style.maxHeight = Math.round(S.H * 0.8) + 'px'));
      S.pages = 1;
      return;
    }
    const M = st.margin;
    const cpp = S.W >= 1000 ? 2 : 1; // two-page spread on wide screens
    const G = 2 * M;
    const colW = Math.floor((S.W - 2 * M - (cpp - 1) * G) / cpp);
    Object.assign(c.style, {
      left: M + 'px',
      width: S.W - 2 * M + 'px',
      height: S.H + 'px',
      columnWidth: colW + 'px',
      columnGap: G + 'px',
      columnFill: 'auto',
    });
    $$('img', c).forEach((img) => (img.style.maxHeight = S.H - 24 + 'px'));
    const cols = Math.max(1, Math.round((c.scrollWidth + G) / (colW + G)));
    S.pages = Math.max(1, Math.ceil(cols / cpp));
  }

  function showPage(p, animate) {
    S.page = clamp(p, 0, S.pages - 1);
    if (S.settings.mode === 'paged') {
      els.content.classList.toggle('anim', !!animate);
      els.content.style.transform = `translateX(${-S.page * S.W}px)`;
    }
    afterMove();
  }

  // ------------------------------------------------------------------ text positions
  function blockOf(node) {
    const sec = section();
    while (node && node.parentNode !== sec) node = node.parentNode;
    return node && node.dataset && node.dataset.b !== undefined ? node : null;
  }

  // Offsets are counted in "visible" characters: soft hyphens inserted for
  // justified text are skipped, so saved positions survive setting changes.
  const SHY = /­/g;
  const vlen = (s) => s.length - (s.match(SHY) || []).length;
  const stripShy = (s) => String(s).replace(SHY, '');

  function textOffset(block, node, offset) {
    // Character offset of (node, offset) inside block's visible text.
    if (node.nodeType !== 3) {
      const child = node.childNodes[offset];
      if (child) {
        node = child;
        offset = 0;
      } else {
        const r = document.createRange();
        r.selectNodeContents(block);
        r.setEnd(node, offset);
        return vlen(r.toString());
      }
    }
    let total = 0;
    const walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT);
    let n;
    while ((n = walker.nextNode())) {
      if (n === node) return total + vlen(n.data.slice(0, offset));
      total += vlen(n.data);
    }
    if (node.nodeType !== 3) {
      // node is an element before which we want the offset
      const r = document.createRange();
      r.selectNodeContents(block);
      r.setEndBefore(node);
      return vlen(r.toString());
    }
    return total;
  }

  function pointAt(block, offset) {
    const walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT);
    let n;
    let total = 0;
    let last = null;
    while ((n = walker.nextNode())) {
      const len = vlen(n.data);
      if (total + len >= offset) {
        // Map the visible offset back to a raw index in this node.
        let want = offset - total;
        let i = 0;
        while (i < n.data.length && (want > 0 || n.data[i] === '­')) {
          if (n.data[i] !== '­') want--;
          i++;
        }
        return { node: n, offset: i };
      }
      total += len;
      last = n;
    }
    return last ? { node: last, offset: last.length } : { node: block, offset: 0 };
  }

  // ---- Uzbek hyphenation (browsers have no dictionary for it) ----
  const VOWELS = 'aeiouAEIOUаеёиоуыэюяўАЕЁИОУЫЭЮЯЎ';
  const APOS = '‘’ʻʼ\'`';
  const WORD_RE = /[A-Za-zА-Яа-яЁёЎўҚқҒғҲҳ‘’ʻʼ'`]{6,}/g;

  function hyphenateWord(word) {
    const units = [];
    for (let i = 0; i < word.length; i++) {
      const ch = word[i];
      if (APOS.includes(ch)) {
        if (units.length) units[units.length - 1].s += ch;
        else units.push({ s: ch, v: false });
        continue;
      }
      const lo = ch.toLowerCase();
      const nx = (word[i + 1] || '').toLowerCase();
      // sh, ch are one sound; ng too, except before a vowel (keng-ay -> ken-gay).
      const ngUnit = lo === 'n' && nx === 'g' && !VOWELS.includes(word[i + 2] || '');
      if (((lo === 's' || lo === 'c') && nx === 'h') || ngUnit) {
        units.push({ s: ch + word[i + 1], v: false });
        i++;
        continue;
      }
      units.push({ s: ch, v: VOWELS.includes(ch) });
    }
    const vi = [];
    units.forEach((u, i) => u.v && vi.push(i));
    if (vi.length < 2) return word;
    const breaks = new Set();
    for (let k = 0; k < vi.length - 1; k++) {
      const a = vi[k];
      const b = vi[k + 1];
      const cons = b - a - 1;
      breaks.add(cons === 0 ? b : cons === 1 ? b - 1 : cons === 2 ? a + 2 : a + 3);
    }
    const total = word.length;
    let out = '';
    let seen = 0;
    units.forEach((u, i) => {
      if (breaks.has(i) && seen >= 2 && total - seen >= 3) out += '­';
      out += u.s;
      seen += u.s.length;
    });
    return out;
  }

  function hyphenate(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: (n) => (n.parentNode.closest('h1,h2,h3,h4,.tp,code,pre,a') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT),
    });
    const nodes = [];
    let n;
    while ((n = walker.nextNode())) nodes.push(n);
    for (const t of nodes) {
      const v = t.data;
      if (v.length < 6) continue;
      const h = v.replace(WORD_RE, hyphenateWord);
      if (h !== v) t.data = h;
    }
  }

  function rangeFor(start, end) {
    const sec = section();
    const b1 = sec && sec.querySelector(`[data-b="${start.b}"]`);
    const b2 = sec && sec.querySelector(`[data-b="${end.b}"]`);
    if (!b1 || !b2) return null;
    const p1 = pointAt(b1, start.o);
    const p2 = pointAt(b2, end.o);
    const r = document.createRange();
    try {
      r.setStart(p1.node, p1.offset);
      r.setEnd(p2.node, p2.offset);
    } catch (e) {
      return null;
    }
    return r;
  }

  function caretAt(x, y) {
    if (document.caretRangeFromPoint) {
      const r = document.caretRangeFromPoint(x, y);
      return r ? { node: r.startContainer, offset: r.startOffset } : null;
    }
    if (document.caretPositionFromPoint) {
      const p = document.caretPositionFromPoint(x, y);
      return p ? { node: p.offsetNode, offset: p.offset } : null;
    }
    return null;
  }

  // First visible block + character offset on the current page.
  function currentPosition() {
    const sec = section();
    if (!sec || !S.book) return { c: S.ch, b: 0, o: 0 };
    const vr = els.viewport.getBoundingClientRect();
    const blocks = sec.children;
    const scroll = S.settings.mode === 'scroll';
    for (let i = 0; i < blocks.length; i++) {
      const el = blocks[i];
      if (el.dataset.b === undefined) continue;
      const rects = el.getClientRects();
      let hit = null;
      for (const r of rects) {
        const visible = scroll ? r.bottom > vr.top + 4 && r.top < vr.bottom : r.right > vr.left + 4 && r.left < vr.right - 4 && r.bottom > vr.top;
        if (visible) {
          hit = r;
          break;
        }
      }
      if (!hit) continue;
      let o = 0;
      const startsBefore = scroll ? hit.top < vr.top : false;
      const lineRects = (() => {
        const r = document.createRange();
        r.selectNodeContents(el);
        return Array.from(r.getClientRects());
      })();
      const firstLine = lineRects.find((r) => (scroll ? r.top >= vr.top - 2 : r.left >= vr.left - 2 && r.left < vr.right) && r.width > 0);
      if (firstLine && (startsBefore || firstLine !== lineRects[0])) {
        const caret = caretAt(firstLine.left + 2, firstLine.top + firstLine.height / 2);
        if (caret && el.contains(caret.node)) o = textOffset(el, caret.node, caret.offset);
      }
      return { c: S.ch, b: +el.dataset.b, o };
    }
    return { c: S.ch, b: 0, o: 0 };
  }

  function pageOfRect(rect) {
    const cr = els.content.getBoundingClientRect();
    const x = rect.left - cr.left;
    return clamp(Math.floor((x + 2) / S.W), 0, S.pages - 1);
  }

  function goToPositionInChapter(pos) {
    const sec = section();
    const el = sec && sec.querySelector(`[data-b="${pos.b || 0}"]`);
    if (!el) return showPage(0);
    let rect = null;
    if (pos.o) {
      const pt = pointAt(el, pos.o);
      const r = document.createRange();
      try {
        r.setStart(pt.node, pt.offset);
        r.setEnd(pt.node, Math.min(pt.offset + 1, pt.node.length || 0));
        rect = r.getClientRects()[0] || null;
      } catch (e) {
        rect = null;
      }
    }
    rect = rect || el.getClientRects()[0] || el.getBoundingClientRect();
    if (S.settings.mode === 'scroll') {
      const vr = els.viewport.getBoundingClientRect();
      els.viewport.scrollTop += rect.top - vr.top - 8;
      afterMove();
    } else {
      showPage(pageOfRect(rect));
    }
  }

  function relayout(pos) {
    if (!S.book) return;
    pos = pos || currentPosition();
    layout();
    goToPositionInChapter(pos);
  }

  // ------------------------------------------------------------------ chapters
  function renderChapter(index, target) {
    const book = S.book;
    index = clamp(index, 0, book.chapters.length - 1);
    S.ch = index;
    const ch = book.chapters[index];
    const isLast = index === book.chapters.length - 1;
    const next = book.chapters[index + 1];
    const end = isLast && book.preview
      ? `<div class="chapter-end preview-end"><b>${esc(T.previewEnd)}</b><br>${esc(T.previewText)}<br><button data-buy>${esc(T.buyFull)}</button></div>`
      : isLast
      ? `<div class="chapter-end">— ${esc(T.bookEnd)} —</div>`
      : `<div class="chapter-end">${esc(T.chapterEnd)}<br><button data-next-chapter>${esc(T.nextChapter)}: ${esc(shorten(next.title, 48))}</button></div>`;
    els.content.classList.remove('anim');
    els.content.style.transform = '';
    // Resolve picture paths before the HTML hits the DOM so the browser never
    // requests them relative to reader.html.
    const html = ch.html.replace(/(<img\b[^>]*?\ssrc=")([^"]+)"/g, (m, pre, src) => pre + esc(assetUrl(src.replace(/&amp;/g, '&'))) + '"');
    els.content.innerHTML = `<section>${html}</section>${end}`;
    $$('img', els.content).forEach((img) => {
      img.loading = 'eager';
      img.decoding = 'async';
      if (!img.complete) img.addEventListener('load', onImageLoad, { once: true });
    });
    els.content.lang = S.book.lang || 'uz';
    if (S.settings.align === 'justify' && (S.book.lang || 'uz') === 'uz') hyphenate(section());
    applyHighlights();
    layout();
    els.viewport.scrollTop = 0;
    target = target || {};
    if (target.pos) goToPositionInChapter(target.pos);
    else if (target.anchor) {
      const a = document.getElementById(target.anchor);
      if (a) goToPositionInChapter({ b: +((blockOf(a) || a).dataset.b || 0), o: 0 });
      else showPage(0);
    } else if (target.page === 'last') {
      if (S.settings.mode === 'scroll') {
        els.viewport.scrollTop = els.viewport.scrollHeight;
        afterMove();
      } else showPage(S.pages - 1);
    } else if (typeof target.fraction === 'number') {
      if (S.settings.mode === 'scroll') {
        els.viewport.scrollTop = target.fraction * (els.viewport.scrollHeight - S.H);
        afterMove();
      } else showPage(Math.floor(target.fraction * S.pages));
    } else showPage(0);
    if (target.flash) flashRange(target.flash);
  }

  const onImageLoad = debounce(() => relayout(S.lastPos && S.lastPos.c === S.ch ? S.lastPos : null), 120);

  function nextPage() {
    if (S.settings.mode === 'scroll') {
      els.viewport.scrollBy({ top: S.H * 0.9, behavior: 'smooth' });
      return;
    }
    if (S.page < S.pages - 1) {
      const p = S.page + 1;
      turn(1, (animate) => showPage(p, animate));
    } else if (S.ch < S.book.chapters.length - 1) {
      const c = S.ch + 1;
      turn(1, () => renderChapter(c, { page: 0 }), true);
    } else bounce(1);
  }

  function prevPage() {
    if (S.settings.mode === 'scroll') {
      els.viewport.scrollBy({ top: -S.H * 0.9, behavior: 'smooth' });
      return;
    }
    if (S.page > 0) {
      const p = S.page - 1;
      turn(-1, (animate) => showPage(p, animate));
    } else if (S.ch > 0) {
      const c = S.ch - 1;
      turn(-1, () => renderChapter(c, { page: 'last' }), true);
    } else bounce(-1);
  }

  // ---- page-turn animations (settings: pageTurn + turnSpeed) ----
  const TURN_MS = { fast: 170, normal: 300, slow: 520 };
  const turnMs = () => TURN_MS[S.settings.turnSpeed] || TURN_MS.normal;
  let turnTimers = [];
  let turnLayers = [];

  // Ends a running animation at once (fast repeated taps stay responsive).
  function finishTurn() {
    turnTimers.forEach(clearTimeout);
    turnTimers = [];
    turnLayers.forEach((l) => l.remove());
    turnLayers = [];
    const c = els.content;
    c.style.transition = '';
    c.style.transitionDuration = '';
    c.style.opacity = '';
    c.classList.remove('anim');
    c.style.transform = `translateX(${-S.page * S.W}px)`;
  }
  const later = (fn, ms) => turnTimers.push(setTimeout(fn, ms));

  /**
   * apply(animate) changes the page or chapter; acrossChapter tells whether
   * the content is re-rendered (the slide then has to fake the movement).
   */
  function turn(dir, apply, acrossChapter) {
    const busy = turnTimers.length > 0;
    finishTurn();
    const kind = busy ? 'none' : S.settings.pageTurn || 'slide';
    if (kind === 'slide') return acrossChapter ? slideAcross(dir, apply) : apply(true);
    if (kind === 'fade') return fadeTurn(apply);
    if (kind === 'flip') return flipTurn(dir, apply);
    apply(false);
  }

  function slideAcross(dir, apply) {
    // The old chapter slides out, the new one slides in from the other side.
    const c = els.content;
    const half = Math.round(turnMs() * 0.6);
    c.style.transitionDuration = half + 'ms';
    c.classList.add('anim');
    c.style.transform = `translateX(${-S.page * S.W - dir * S.W}px)`;
    later(() => {
      apply(false);
      const base = -S.page * S.W;
      c.classList.remove('anim');
      c.style.transform = `translateX(${base + dir * S.W}px)`;
      void c.offsetWidth; // commit the start position before animating
      c.style.transitionDuration = half + 'ms';
      c.classList.add('anim');
      c.style.transform = `translateX(${base}px)`;
      later(() => {
        c.style.transitionDuration = '';
        turnTimers = [];
      }, half + 20);
    }, half);
  }

  function fadeTurn(apply) {
    const c = els.content;
    const half = Math.round(turnMs() / 2);
    c.style.transition = `opacity ${half}ms ease`;
    c.style.opacity = '0';
    later(() => {
      apply(false);
      c.style.transition = `opacity ${half}ms ease`;
      c.style.opacity = '1';
      later(() => {
        c.style.transition = '';
        turnTimers = [];
      }, half + 20);
    }, half);
  }

  // Paper-like turn: a snapshot of the page rotates around its left edge.
  function flipTurn(dir, apply) {
    const ms = Math.round(turnMs() * 1.5);
    const layer = () => {
      const ov = document.createElement('div');
      ov.className = 'turn-layer';
      const copy = els.content.cloneNode(true); // keeps id="content" so book styles apply
      copy.classList.remove('anim');
      ov.appendChild(copy);
      const shade = document.createElement('div');
      shade.className = 'turn-shade';
      ov.appendChild(shade);
      els.viewport.appendChild(ov);
      turnLayers.push(ov);
      return ov;
    };
    const animate = (ov, toTurned) => {
      void ov.offsetWidth;
      const t = `${ms}ms cubic-bezier(.35, .05, .25, 1)`;
      ov.style.transition = `transform ${t}, box-shadow ${t}`;
      ov.querySelector('.turn-shade').style.transition = `opacity ${t}`;
      ov.classList.toggle('turned', toTurned);
    };
    if (dir > 0) {
      // Current page lifts away to the left, the next one is already below.
      const ov = layer();
      apply(false);
      animate(ov, true);
    } else {
      // Previous page comes back over the current one.
      layer(); // current page stays visible underneath
      apply(false);
      const ov = layer();
      ov.classList.add('turned');
      animate(ov, false);
    }
    later(() => {
      turnLayers.forEach((l) => l.remove());
      turnLayers = [];
      turnTimers = [];
    }, ms + 40);
  }

  function bounce(dir) {
    // End of the book: a small nudge in every animation mode.
    finishTurn();
    const base = -S.page * S.W;
    els.content.classList.add('anim');
    els.content.style.transform = `translateX(${base - dir * 30}px)`;
    setTimeout(() => (els.content.style.transform = `translateX(${base}px)`), 140);
  }

  function goTo(pos, extra) {
    if (!pos) return;
    if (pos.c === S.ch && !extra) goToPositionInChapter(pos);
    else renderChapter(pos.c, Object.assign({ pos }, extra || {}));
  }

  // ------------------------------------------------------------------ progress UI
  function chapterFraction() {
    if (S.settings.mode === 'scroll') {
      const max = els.viewport.scrollHeight - S.H;
      return max > 0 ? clamp(els.viewport.scrollTop / max, 0, 1) : 1;
    }
    return S.pages > 1 ? S.page / (S.pages - 1) : 1;
  }

  function percent() {
    if (!S.book) return 0;
    const ch = S.book.chapters[S.ch];
    const done = S.charsBefore[S.ch] + (ch.chars || 1) * chapterFraction();
    return clamp(done / S.totalChars, 0, 1);
  }

  function shorten(s, n) {
    s = String(s || '');
    return s.length > n ? s.slice(0, n - 1) + '…' : s;
  }

  // Position updates carry their own timestamp so the newest device wins;
  // annotations are only sent when they change (see touchData).
  const syncPosition = debounce(() => {
    if (!S.cfg.syncUrl || !navigator.onLine) return;
    fetch(S.cfg.syncUrl, {
      method: 'PUT',
      headers: Object.assign({ 'Content-Type': 'application/json' }, S.cfg.syncHeaders || {}),
      body: JSON.stringify({ position: S.lastPos, percent: percent(), updatedAt: S.updatedAt }),
      keepalive: true,
    }).catch(() => {});
  }, 2500);

  let firstReport = true;
  const reportPosition = debounce(() => {
    // The initial render restores a position; it is not a new reading event.
    if (firstReport) {
      firstReport = false;
    } else {
      S.updatedAt = Date.now();
      syncPosition();
    }
    post('position', { position: S.lastPos, percent: percent(), chapter: S.ch, chapterTitle: S.book.chapters[S.ch].title });
    saveLocal();
  }, 300);

  function afterMove() {
    if (!S.book) return;
    const ch = S.book.chapters[S.ch];
    const pct = percent();
    S.lastPos = currentPosition();
    const paged = S.settings.mode === 'paged';
    els.headLeft.textContent = shorten(ch.title, 70);
    els.headRight.textContent = '';
    els.footLeft.textContent = paged ? `${S.page + 1} ${T.of} ${S.pages}` : '';
    els.footRight.textContent = Math.round(pct * 100) + '%';
    els.barSub.textContent = ch.title;
    els.slider.value = Math.round(pct * 1000);
    els.slider.style.setProperty('--p', pct * 100 + '%');
    const left = Math.max(0, Math.round((ch.words * (1 - chapterFraction())) / 200));
    els.locLeft.textContent = `${T.chapter} ${S.ch + 1}/${S.book.chapters.length}` + (left ? ` · ${left} ${T.minLeft}` : '');
    els.locRight.textContent = `${Math.round(pct * 100)}% ${T.percentRead}`;
    const bm = bookmarkHere();
    els.btnBookmark.innerHTML = svg(bm ? 'bookmarkOn' : 'bookmark');
    els.btnBookmark.classList.toggle('on', !!bm);
    els.bookmarkFlag.classList.toggle('hidden', !bm);
    reportPosition();
  }

  // ------------------------------------------------------------------ bookmarks
  function pageRange() {
    // Positions covered by the visible page: from current position to the next page start.
    const start = S.lastPos || currentPosition();
    return start;
  }

  function bookmarkHere() {
    if (!S.lastPos) return null;
    const pos = S.lastPos;
    if (S.settings.mode === 'scroll') return S.bookmarks.find((b) => b.pos.c === pos.c && b.pos.b === pos.b) || null;
    // A bookmark belongs to this page if it resolves to this page.
    const sec = section();
    return (
      S.bookmarks.find((b) => {
        if (b.pos.c !== S.ch) return false;
        const el = sec && sec.querySelector(`[data-b="${b.pos.b}"]`);
        if (!el) return false;
        let rect = null;
        if (b.pos.o) {
          const pt = pointAt(el, b.pos.o);
          const r = document.createRange();
          try {
            r.setStart(pt.node, pt.offset);
            r.setEnd(pt.node, Math.min(pt.offset + 1, pt.node.length || 0));
            rect = r.getClientRects()[0];
          } catch (e) { /* ignore */ }
        }
        rect = rect || el.getClientRects()[0];
        return rect && pageOfRect(rect) === S.page;
      }) || null
    );
  }

  function snippetAt(pos, len) {
    const sec = section();
    const el = sec && sec.querySelector(`[data-b="${pos.b}"]`);
    const t = el ? stripShy(el.textContent) : '';
    return t.slice(pos.o || 0, (pos.o || 0) + (len || 120)).replace(/\s+/g, ' ').trim();
  }

  function toggleBookmark() {
    const existing = bookmarkHere();
    if (existing) {
      S.bookmarks = S.bookmarks.filter((b) => b !== existing);
      toast(T.bookmarkRemoved);
    } else {
      const pos = pageRange();
      S.bookmarks.push({ id: uid(), pos, title: S.book.chapters[S.ch].title, text: snippetAt(pos), percent: percent(), at: Date.now() });
      toast(T.bookmarkAdded);
    }
    touchData(true);
    afterMove();
  }

  // ------------------------------------------------------------------ highlights
  function applyHighlights() {
    const list = S.highlights.filter((h) => h.c === S.ch).sort((a, b) => a.s.b - b.s.b || a.s.o - b.s.o);
    for (const h of list) {
      const r = rangeFor(h.s, h.e);
      if (r) wrapRange(r, h);
    }
  }

  function wrapRange(range, h) {
    const root = range.commonAncestorContainer.nodeType === 3 ? range.commonAncestorContainer.parentNode : range.commonAncestorContainer;
    const nodes = [];
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    let n;
    while ((n = walker.nextNode())) if (range.intersectsNode(n) && n.length) nodes.push(n);
    for (const node of nodes) {
      let s = node === range.startContainer ? range.startOffset : 0;
      let e = node === range.endContainer ? range.endOffset : node.length;
      if (s >= e) continue;
      let target = node;
      if (e < target.length) target.splitText(e);
      if (s > 0) target = target.splitText(s);
      if (!target.data.trim() && target.parentNode && /^(TR|TBODY|TABLE|UL|OL)$/.test(target.parentNode.nodeName)) continue;
      const mark = document.createElement('mark');
      mark.className = `hl hl-${h.color}${h.note ? ' has-note' : ''}`;
      mark.dataset.hid = h.id;
      target.parentNode.insertBefore(mark, target);
      mark.appendChild(target);
    }
  }

  function positionsOfRange(range) {
    const b1 = blockOf(range.startContainer);
    const b2 = blockOf(range.endContainer);
    if (!b1 || !b2) return null;
    return {
      s: { b: +b1.dataset.b, o: textOffset(b1, range.startContainer, range.startOffset) },
      e: { b: +b2.dataset.b, o: textOffset(b2, range.endContainer, range.endOffset) },
    };
  }

  function addHighlight(range, color, note) {
    const p = positionsOfRange(range);
    if (!p) return null;
    const h = { id: uid(), c: S.ch, s: p.s, e: p.e, text: stripShy(range.toString()).replace(/\s+/g, ' ').trim().slice(0, 1000), color, note: note || '', at: Date.now() };
    S.highlights.push(h);
    wrapRange(range, h);
    touchData(true);
    return h;
  }

  function rerenderKeepingPlace() {
    const pos = currentPosition();
    renderChapter(S.ch, { pos });
  }

  function removeHighlight(id) {
    S.highlights = S.highlights.filter((h) => h.id !== id);
    touchData(true);
    rerenderKeepingPlace();
  }

  function recolorHighlight(h, color) {
    h.color = color;
    $$(`mark[data-hid="${h.id}"]`).forEach((m) => (m.className = `hl hl-${color}${h.note ? ' has-note' : ''}`));
    touchData(true);
  }

  function flashRange(f) {
    const r = rangeFor({ b: f.b, o: f.o }, { b: f.b, o: f.o + f.len });
    if (!r) return;
    const tmp = { id: 'flash', color: 'search', note: '' };
    wrapRange(r, tmp);
    $$('mark[data-hid="flash"]').forEach((m) => (m.className = 'search-hit'));
    const first = $('mark.search-hit');
    if (first) {
      if (S.settings.mode === 'scroll') first.scrollIntoView({ block: 'center' });
      else showPage(pageOfRect(first.getClientRects()[0] || first.getBoundingClientRect()));
    }
    setTimeout(() => {
      $$('mark.search-hit').forEach((m) => m.replaceWith(...m.childNodes));
      section() && section().normalize();
    }, 2500);
  }

  // selection toolbar
  function hideSelbar() {
    els.selbar.classList.add('hidden');
    S.selHighlight = null;
    S.pendingRange = null;
  }

  function showSelbarAt(rect, h) {
    const bar = els.selbar;
    bar.classList.remove('hidden');
    $('#selDelete').classList.toggle('hidden', !h);
    $$('#selbar .dot').forEach((d) => d.classList.toggle('on', !!h && d.dataset.color === h.color));
    const bw = bar.offsetWidth;
    const bh = bar.offsetHeight;
    let x = rect.left + rect.width / 2 - bw / 2;
    x = clamp(x, 8, window.innerWidth - bw - 8);
    let y = rect.top - bh - 12;
    if (y < 60) y = rect.bottom + 12;
    if (y + bh > window.innerHeight - 10) y = window.innerHeight / 2 - bh / 2;
    bar.style.left = x + 'px';
    bar.style.top = y + 'px';
  }

  const onSelectionChange = debounce(() => {
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed || !sel.rangeCount) {
      if (!S.selHighlight) els.selbar.classList.add('hidden');
      return;
    }
    const range = sel.getRangeAt(0);
    if (!els.content.contains(range.commonAncestorContainer)) return;
    if (!range.toString().trim()) return;
    S.selHighlight = null;
    S.pendingRange = range.cloneRange();
    const rects = range.getClientRects();
    showSelbarAt(rects[0] || range.getBoundingClientRect(), null);
  }, 250);

  function onSelbarColor(color) {
    if (S.selHighlight) {
      recolorHighlight(S.selHighlight, color);
    } else if (S.pendingRange) {
      addHighlight(S.pendingRange, color);
      window.getSelection().removeAllRanges();
    }
    hideSelbar();
  }

  function onSelbarNote() {
    let h = S.selHighlight;
    if (!h && S.pendingRange) {
      h = addHighlight(S.pendingRange, 'yellow');
      window.getSelection().removeAllRanges();
    }
    hideSelbar();
    if (h) openNoteEditor(h);
  }

  function onSelbarCopy() {
    const text = S.selHighlight ? S.selHighlight.text : S.pendingRange ? stripShy(S.pendingRange.toString()) : '';
    if (text) {
      const done = () => toast(T.copied);
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, () => post('copy', { text }));
      else post('copy', { text });
      if (isEmbedded()) post('copy', { text });
    }
    window.getSelection().removeAllRanges();
    hideSelbar();
  }

  let editingNote = null;
  function openNoteEditor(h) {
    editingNote = h;
    $('#noteQuote').textContent = h.text;
    $('#noteQuote').style.borderColor = `var(--hl-${h.color})`;
    els.noteText.value = h.note || '';
    els.noteText.placeholder = T.notePlaceholder;
    openPanel('noteEdit');
    setTimeout(() => els.noteText.focus(), 300);
  }

  // ------------------------------------------------------------------ footnotes, links, images
  function showFootnote(id) {
    const el = document.getElementById(id);
    if (!el) return;
    const n = el.getAttribute('value') || '';
    els.noteBody.innerHTML = (n ? `<p><b>${esc(n)}.</b></p>` : '') + el.innerHTML;
    $$('img', els.noteBody).forEach((img) => (img.src = img.src));
    openPanel('noteSheet');
  }

  function followLink(a) {
    const href = a.getAttribute('href') || '';
    if (a.classList.contains('fnref') || a.dataset.fn) return showFootnote(a.dataset.fn || href.slice(1));
    if (href.startsWith('#')) {
      const id = href.slice(1);
      const c = a.dataset.c !== undefined ? +a.dataset.c : S.ch;
      if (c === S.ch) {
        const t = document.getElementById(id);
        if (t) goToPositionInChapter({ b: +((blockOf(t) || t).dataset.b || 0), o: 0 });
      } else renderChapter(c, { anchor: id });
      return;
    }
    if (/^https?:/i.test(href)) {
      if (isEmbedded()) post('openUrl', { url: href });
      else window.open(href, '_blank', 'noopener');
    }
  }

  function openImage(img) {
    const v = els.imgViewer;
    const big = $('img', v);
    big.src = img.src;
    big.classList.remove('zoom');
    v.classList.remove('hidden');
  }

  // ------------------------------------------------------------------ panels
  let openPanelId = null;
  function openPanel(id) {
    closePanels(true);
    openPanelId = id;
    $('#' + id).classList.add('open');
    els.scrim.classList.add('open');
    setUi(false);
  }
  function closePanels(silent) {
    if (openPanelId) $('#' + openPanelId).classList.remove('open');
    openPanelId = null;
    els.scrim.classList.remove('open');
    if (!silent) hideSelbar();
  }

  function setUi(on) {
    S.ui = on;
    document.body.classList.toggle('ui', on);
    post('ui', { visible: on });
  }

  // TOC / bookmarks / notes drawer
  let tocTab = 'toc';
  function renderTocPanel() {
    const list = els.tocList;
    $$('#tocPanel .tabs button').forEach((b) => b.classList.toggle('on', b.dataset.tab === tocTab));
    if (tocTab === 'toc') {
      const toc = S.book.toc && S.book.toc.length ? S.book.toc : S.book.chapters.map((c, i) => ({ title: c.title, level: 1, chapter: i }));
      // Current entry: the last one at or before the current page.
      let current = -1;
      toc.forEach((t, i) => {
        if (t.chapter < S.ch) current = i;
        else if (t.chapter === S.ch) {
          if (!t.anchor) current = i;
          else {
            const a = document.getElementById(t.anchor);
            if (!a) return;
            const r = a.getClientRects()[0];
            if (S.settings.mode === 'scroll') {
              if (r && r.top <= els.viewport.getBoundingClientRect().top + S.H / 3) current = i;
            } else if (r && pageOfRect(r) <= S.page) current = i;
          }
        }
      });
      list.innerHTML = toc.map((t, i) => `<button class="toc-item l${Math.min(t.level, 3)}${i === current ? ' current' : ''}" data-i="${i}">${esc(t.title)}</button>`).join('');
      list.onclick = (e) => {
        const b = e.target.closest('.toc-item');
        if (!b) return;
        const t = toc[+b.dataset.i];
        closePanels();
        if (t.anchor) renderChapter(t.chapter, { anchor: t.anchor });
        else renderChapter(t.chapter, { page: 0 });
      };
      const cur = $('.toc-item.current', list);
      if (cur) setTimeout(() => cur.scrollIntoView({ block: 'center' }), 50);
    } else if (tocTab === 'bookmarks') {
      const items = S.bookmarks.slice().sort((a, b) => a.pos.c - b.pos.c || a.pos.b - b.pos.b || a.pos.o - b.pos.o);
      list.innerHTML = items.length
        ? items.map((b) => `<div class="note-item" data-id="${b.id}"><div class="meta"><span>${esc(shorten(b.title, 46))} · ${Math.round((b.percent || 0) * 100)}%</span><button data-del="${b.id}" class="icon" style="width:28px;height:28px">${svg('close')}</button></div><div class="quote">${esc(b.text || '…')}</div></div>`).join('')
        : `<div class="empty">${esc(T.noBookmarks).replace('\n', '<br>')}</div>`;
      list.onclick = (e) => {
        const del = e.target.closest('[data-del]');
        if (del) {
          S.bookmarks = S.bookmarks.filter((b) => b.id !== del.dataset.del);
          touchData(true);
          renderTocPanel();
          afterMove();
          return;
        }
        const it = e.target.closest('.note-item');
        if (!it) return;
        const b = S.bookmarks.find((x) => x.id === it.dataset.id);
        closePanels();
        if (b) goTo(b.pos, {});
      };
    } else {
      const items = S.highlights.slice().sort((a, b) => a.c - b.c || a.s.b - b.s.b || a.s.o - b.s.o);
      list.innerHTML = items.length
        ? items.map((h) => `<div class="note-item" data-id="${h.id}"><div class="meta"><span>${esc(shorten(S.book.chapters[h.c] ? S.book.chapters[h.c].title : '', 46))}</span><button data-del="${h.id}" class="icon" style="width:28px;height:28px">${svg('trash')}</button></div><div class="quote c-${h.color}">${esc(shorten(h.text, 300))}</div>${h.note ? `<div class="note">${esc(h.note)}</div>` : ''}</div>`).join('')
        : `<div class="empty">${esc(T.noNotes).replace('\n', '<br>')}</div>`;
      list.onclick = (e) => {
        const del = e.target.closest('[data-del]');
        if (del) {
          const id = del.dataset.del;
          S.highlights = S.highlights.filter((h) => h.id !== id);
          touchData(true);
          if (S.highlights.every((h) => h.c !== S.ch) || true) rerenderKeepingPlace();
          renderTocPanel();
          return;
        }
        const it = e.target.closest('.note-item');
        if (!it) return;
        const h = S.highlights.find((x) => x.id === it.dataset.id);
        closePanels();
        if (h) goTo({ c: h.c, b: h.s.b, o: h.s.o }, {});
      };
    }
  }

  // ------------------------------------------------------------------ search
  const norm = (s) => {
    let out = '';
    for (const ch of s) {
      let c = ch;
      if (/[‘’ʻʼ`´']/.test(c)) c = "'";
      else {
        const l = c.toLowerCase();
        c = l.length === ch.length ? l : ch;
      }
      out += c;
    }
    return out;
  };

  function chapterTexts(i) {
    if (S.textCache[i]) return S.textCache[i];
    const div = document.createElement('div');
    div.innerHTML = S.book.chapters[i].html;
    const sec = div.querySelector('section') || div;
    const blocks = [];
    for (const el of sec.children) {
      if (el.dataset.b === undefined) continue;
      const t = el.textContent;
      blocks.push({ b: +el.dataset.b, text: t, n: norm(t) });
    }
    S.textCache[i] = blocks;
    return blocks;
  }

  let searchToken = 0;
  function runSearch(q) {
    const token = ++searchToken;
    const query = norm(q.trim());
    els.searchList.innerHTML = '';
    if (query.length < 2) {
      els.searchStatus.textContent = T.searchHint;
      return;
    }
    els.searchStatus.textContent = T.searching;
    const results = [];
    let i = 0;
    const step = () => {
      if (token !== searchToken) return;
      const until = performance.now() + 12;
      while (i < S.book.chapters.length && performance.now() < until) {
        for (const blk of chapterTexts(i)) {
          let from = 0;
          let at;
          while ((at = blk.n.indexOf(query, from)) !== -1 && results.length < 500) {
            results.push({ c: i, b: blk.b, o: at, len: query.length, text: blk.text });
            from = at + query.length;
          }
        }
        i++;
      }
      renderResults(results, i >= S.book.chapters.length);
      if (i < S.book.chapters.length && results.length < 500) setTimeout(step, 0);
    };
    step();
  }

  function renderResults(results, done) {
    els.searchStatus.textContent = results.length ? `${results.length}${results.length >= 500 ? '+' : ''} ${T.found}` : done ? T.notFound : T.searching;
    els.searchList.innerHTML = results
      .slice(0, 300)
      .map((r, k) => {
        const a = Math.max(0, r.o - 50);
        const pre = (a > 0 ? '…' : '') + r.text.slice(a, r.o);
        const hit = r.text.slice(r.o, r.o + r.len);
        const post2 = r.text.slice(r.o + r.len, r.o + r.len + 80) + '…';
        return `<button class="result" data-k="${k}"><div class="meta">${esc(shorten(S.book.chapters[r.c].title, 60))}</div><div class="snip">${esc(pre)}<b>${esc(hit)}</b>${esc(post2)}</div></button>`;
      })
      .join('');
    els.searchList.onclick = (e) => {
      const b = e.target.closest('.result');
      if (!b) return;
      const r = results[+b.dataset.k];
      closePanels();
      renderChapter(r.c, { pos: { b: r.b, o: r.o }, flash: { b: r.b, o: r.o, len: r.len } });
    };
  }

  // ------------------------------------------------------------------ input
  function setupInput() {
    const vp = els.viewport;
    let sx = 0;
    let sy = 0;
    let st = 0;
    let dragging = false;
    let moved = false;
    let tracking = false;

    vp.addEventListener('touchstart', (e) => {
      if (e.touches.length !== 1) return;
      const t = e.touches[0];
      sx = t.clientX;
      sy = t.clientY;
      st = Date.now();
      dragging = false;
      moved = false;
      tracking = S.settings.mode === 'paged' && !openPanelId;
    }, { passive: true });

    vp.addEventListener('touchmove', (e) => {
      if (!tracking || e.touches.length !== 1) return;
      const sel = window.getSelection();
      if (sel && !sel.isCollapsed) {
        tracking = false;
        return;
      }
      const t = e.touches[0];
      const dx = t.clientX - sx;
      const dy = t.clientY - sy;
      if (!dragging && Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(dy) * 1.2) dragging = true;
      if (Math.abs(dx) > 10 || Math.abs(dy) > 10) moved = true;
      if (dragging) {
        e.preventDefault();
        // Only the slide animation follows the finger; others turn on release.
        if (S.settings.pageTurn && S.settings.pageTurn !== 'slide') return;
        finishTurn();
        els.content.classList.remove('anim');
        let off = dx;
        if ((S.page === 0 && S.ch === 0 && dx > 0) || (S.page === S.pages - 1 && S.ch === S.book.chapters.length - 1 && dx < 0)) off = dx / 4;
        els.content.style.transform = `translateX(${-S.page * S.W + off}px)`;
      }
    }, { passive: false });

    vp.addEventListener('touchend', (e) => {
      if (!tracking) return;
      tracking = false;
      if (!dragging) return;
      const t = e.changedTouches[0];
      const dx = t.clientX - sx;
      const fast = Date.now() - st < 300 && Math.abs(dx) > 30;
      if (dx < -S.W * 0.18 || (fast && dx < 0)) nextPage();
      else if (dx > S.W * 0.18 || (fast && dx > 0)) prevPage();
      else showPage(S.page, true);
      dragging = false;
      suppressClick = Date.now();
    });

    let suppressClick = 0;
    vp.addEventListener('click', (e) => {
      if (Date.now() - suppressClick < 400) return;
      const sel = window.getSelection();
      if (sel && !sel.isCollapsed) return;
      if (moved && S.settings.mode === 'scroll') return;
      const target = e.target;
      if (target.closest('[data-buy]')) return post('buy', { id: S.book.id });
      const nextBtn = target.closest('[data-next-chapter]');
      if (nextBtn) return renderChapter(S.ch + 1, { page: 0 });
      const a = target.closest('a');
      if (a) {
        e.preventDefault();
        return followLink(a);
      }
      const mark = target.closest('mark.hl');
      if (mark) {
        const h = S.highlights.find((x) => x.id === mark.dataset.hid);
        if (h) {
          if (h.note) {
            S.selHighlight = h;
            openNoteEditor(h);
            return;
          }
          S.selHighlight = h;
          S.pendingRange = null;
          showSelbarAt(mark.getBoundingClientRect(), h);
          return;
        }
      }
      if (target.tagName === 'IMG') return openImage(target);
      if (!els.selbar.classList.contains('hidden')) return hideSelbar();
      if (S.ui) return setUi(false);
      const x = e.clientX - vp.getBoundingClientRect().left;
      if (x < S.W * 0.28) prevPage();
      else if (x > S.W * 0.72) nextPage();
      else setUi(true);
    });

    // Mouse wheel turns pages on desktop.
    let wheelAt = 0;
    vp.addEventListener('wheel', (e) => {
      if (S.settings.mode !== 'paged') return;
      e.preventDefault();
      const now = Date.now();
      if (now - wheelAt < 350 || Math.abs(e.deltaY) + Math.abs(e.deltaX) < 8) return;
      wheelAt = now;
      if (e.deltaY > 0 || e.deltaX > 0) nextPage();
      else prevPage();
    }, { passive: false });

    vp.addEventListener('scroll', debounce(() => S.settings.mode === 'scroll' && afterMove(), 120));

    document.addEventListener('keydown', (e) => {
      if (e.target.matches('input, textarea')) return;
      if (e.key === 'Escape') {
        if (!els.imgViewer.classList.contains('hidden')) return els.imgViewer.classList.add('hidden');
        if (openPanelId) return closePanels();
        return setUi(!S.ui);
      }
      if (openPanelId) return;
      if (['ArrowRight', 'PageDown', ' '].includes(e.key)) {
        e.preventDefault();
        nextPage();
      } else if (['ArrowLeft', 'PageUp'].includes(e.key)) {
        e.preventDefault();
        prevPage();
      }
    });

    document.addEventListener('selectionchange', onSelectionChange);
    window.addEventListener('resize', debounce(() => relayout(S.lastPos && S.lastPos.c === S.ch ? S.lastPos : null), 150));
    window.addEventListener('pagehide', () => {
      saveNow();
      if (S.cfg && S.cfg.syncUrl && navigator.sendBeacon) {
        try {
          navigator.sendBeacon(S.cfg.syncUrl.replace('/reading', '/reading/beacon'), new Blob([JSON.stringify(readingState())], { type: 'application/json' }));
        } catch (e) { /* ignore */ }
      }
    });
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden || !S.book) return;
      saveNow();
      post('position', { position: S.lastPos, percent: percent(), chapter: S.ch, chapterTitle: S.book.chapters[S.ch].title });
    });
  }

  function setupUi() {
    $$('[data-icon]').forEach((b) => (b.innerHTML = svg(b.dataset.icon)));
    els.bookmarkFlag.innerHTML = '<svg viewBox="0 0 18 30"><path d="M0 0h18v30l-9-7-9 7z" fill="currentColor"/></svg>';

    els.btnBack.onclick = () => {
      if (isEmbedded()) return post('close', { position: S.lastPos, percent: percent() });
      if (S.cfg.backUrl) location.href = S.cfg.backUrl;
      else history.back();
    };
    $('#errorBack').onclick = els.btnBack.onclick;
    els.btnToc.onclick = () => {
      tocTab = 'toc';
      renderTocPanel();
      openPanel('tocPanel');
    };
    $$('#tocPanel .tabs button').forEach((b) => (b.onclick = () => {
      tocTab = b.dataset.tab;
      renderTocPanel();
    }));
    els.btnSettings.onclick = () => openPanel('settingsPanel');
    els.btnSearch.onclick = () => {
      openPanel('searchPanel');
      setTimeout(() => els.searchInput.focus(), 280);
    };
    els.btnBookmark.onclick = toggleBookmark;
    els.btnPrevCh.onclick = () => renderChapter(S.ch > 0 && S.page === 0 ? S.ch - 1 : S.ch, { page: 0 });
    els.btnNextCh.onclick = () => S.ch < S.book.chapters.length - 1 && renderChapter(S.ch + 1, { page: 0 });
    els.scrim.onclick = () => closePanels();
    $$('[data-close]').forEach((b) => (b.onclick = () => closePanels()));

    // slider
    const tip = $('#sliderTip');
    const locate = (v) => {
      const target = (v / 1000) * S.totalChars;
      let c = 0;
      while (c < S.book.chapters.length - 1 && S.charsBefore[c + 1] <= target) c++;
      const frac = clamp((target - S.charsBefore[c]) / (S.book.chapters[c].chars || 1), 0, 0.999);
      return { c, frac };
    };
    els.slider.addEventListener('input', () => {
      const { c } = locate(+els.slider.value);
      els.slider.style.setProperty('--p', els.slider.value / 10 + '%');
      tip.textContent = `${Math.round(els.slider.value / 10)}% · ${S.book.chapters[c].title}`;
      tip.classList.remove('hidden');
    });
    els.slider.addEventListener('change', () => {
      tip.classList.add('hidden');
      const { c, frac } = locate(+els.slider.value);
      renderChapter(c, { fraction: frac });
    });

    // settings
    $('#fsMinus').onclick = () => changeSetting('fontSize', clamp(S.settings.fontSize - 1, 13, 34));
    $('#fsPlus').onclick = () => changeSetting('fontSize', clamp(S.settings.fontSize + 1, 13, 34));
    const seg = (id, key, parse) => $$(`#${id} button`).forEach((b) => (b.onclick = () => changeSetting(key, parse ? parse(b.dataset.v) : b.dataset.v)));
    seg('segTheme', 'theme');
    seg('segFont', 'font');
    seg('segLine', 'lineHeight', Number);
    seg('segMargin', 'margin', Number);
    seg('segAlign', 'align');
    seg('segMode', 'mode');
    // Turn style/speed: no relayout needed, and show a quick preview.
    const previewTurn = (key, value) => {
      S.settings[key] = value;
      storage.set('mbook:settings', S.settings);
      applySettings();
      post('settings', { settings: S.settings });
      if (S.settings.mode !== 'paged') return;
      if (S.page < S.pages - 1) {
        nextPage();
        setTimeout(() => prevPage(), turnMs() * 1.6 + 250);
      } else if (S.page > 0) {
        prevPage();
        setTimeout(() => nextPage(), turnMs() * 1.6 + 250);
      }
    };
    $$('#segTurn button').forEach((b) => (b.onclick = () => previewTurn('pageTurn', b.dataset.v)));
    $$('#segSpeed button').forEach((b) => (b.onclick = () => previewTurn('turnSpeed', b.dataset.v)));
    els.brightness.oninput = () => {
      S.settings.brightness = +els.brightness.value;
      els.dim.style.opacity = String(S.settings.brightness / 100);
    };
    els.brightness.onchange = () => storage.set('mbook:settings', S.settings);

    // search
    els.searchInput.addEventListener('input', debounce(() => runSearch(els.searchInput.value), 350));
    $('#searchForm').onsubmit = (e) => {
      e.preventDefault();
      runSearch(els.searchInput.value);
      els.searchInput.blur();
    };

    // selection bar
    $$('#selbar .dot').forEach((d) => d.addEventListener('mousedown', (e) => e.preventDefault()));
    $$('#selbar button').forEach((d) => d.addEventListener('touchstart', (e) => e.stopPropagation(), { passive: true }));
    $$('#selbar .dot').forEach((d) => (d.onclick = () => onSelbarColor(d.dataset.color)));
    $('#selNote').onclick = onSelbarNote;
    $('#selCopy').onclick = onSelbarCopy;
    $('#selDelete').onclick = () => {
      const h = S.selHighlight;
      hideSelbar();
      if (h) removeHighlight(h.id);
    };
    $('#noteSave').onclick = () => {
      if (editingNote) {
        editingNote.note = els.noteText.value.trim();
        $$(`mark[data-hid="${editingNote.id}"]`).forEach((m) => m.classList.toggle('has-note', !!editingNote.note));
        touchData(true);
      }
      closePanels();
    };
    $('#noteDelete').onclick = () => {
      const h = editingNote;
      closePanels();
      if (h) removeHighlight(h.id);
    };

    // image viewer
    els.imgViewer.onclick = (e) => {
      if (e.target.tagName === 'IMG') e.target.classList.toggle('zoom');
      else els.imgViewer.classList.add('hidden');
    };
    $('#imgClose').onclick = () => els.imgViewer.classList.add('hidden');
  }

  let toastTimer;
  function toast(text) {
    els.toast.textContent = text;
    els.toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => els.toast.classList.remove('show'), 1800);
  }

  function translateUi() {
    $$('[data-i18n]').forEach((el) => {
      const k = el.dataset.i18n;
      if (T[k]) el.textContent = T[k];
    });
    els.searchInput.placeholder = T.search + '…';
  }

  function showError(msg) {
    $('#loader').classList.add('hidden');
    $('#error').classList.remove('hidden');
    $('#errorText').textContent = msg || '';
    post('error', { message: msg });
  }

  // ------------------------------------------------------------------ open
  let started = false;
  async function open(cfg) {
    if (started) return;
    started = true;
    S.cfg = Object.assign({ query: '' }, cfg);
    // The app knows the real status/navigation bar sizes better than env().
    if (S.cfg.insets) {
      document.documentElement.style.setProperty('--safe-top', (S.cfg.insets.top || 0) + 'px');
      document.documentElement.style.setProperty('--safe-bottom', (S.cfg.insets.bottom || 0) + 'px');
    }
    T = I18N[S.cfg.uiLang] || I18N.uz;
    document.documentElement.lang = S.cfg.uiLang || 'uz';
    translateUi();
    try {
      const book = await loadBookScript(S.cfg);
      if (!book || !book.chapters || !book.chapters.length) throw new Error('Empty book');
      S.book = book;
    } catch (e) {
      showError((e && e.message) || String(e));
      return;
    }
    const book = S.book;
    document.title = book.title;
    els.barTitle.textContent = book.preview ? `${T.previewBadge} · ${book.title}` : book.title;
    $('#tocBookTitle').textContent = book.title;
    let acc = 0;
    S.charsBefore = book.chapters.map((c) => {
      const before = acc;
      acc += c.chars || 1;
      return before;
    });
    S.totalChars = acc || 1;

    const startPos = loadLocal();
    applySettings();
    if (document.fonts && document.fonts.ready) await Promise.race([document.fonts.ready, new Promise((r) => setTimeout(r, 800))]);
    const pos = startPos && startPos.c < book.chapters.length ? startPos : { c: 0, b: 0, o: 0 };
    renderChapter(pos.c, { pos });
    $('#loader').classList.add('hidden');
    post('loaded', { id: book.id, title: book.title, chapters: book.chapters.length, percent: percent() });
    if (!startPos) {
      setUi(true);
      setTimeout(() => S.ui && !openPanelId && setUi(false), 2500);
    }
  }

  function init() {
    ['content', 'viewport', 'headLeft', 'headRight', 'footLeft', 'footRight', 'barTitle', 'barSub', 'slider', 'locLeft', 'locRight', 'btnBack', 'btnToc', 'btnSettings',
      'btnSearch', 'btnBookmark', 'btnPrevCh', 'btnNextCh', 'scrim', 'tocList', 'searchList', 'searchStatus', 'searchInput', 'fsValue', 'brightness', 'dim',
      'selbar', 'noteBody', 'noteText', 'imgViewer', 'toast', 'bookmarkFlag'].forEach((id) => (els[id] = document.getElementById(id)));
    setupUi();
    setupInput();
    const cfg = configFromLocation();
    if (cfg) open(cfg);
    else if (!isEmbedded()) {
      // Wait a moment for a host to call Reader.open(); otherwise explain.
      setTimeout(() => !started && showError('reader.html?book=<papka> yoki Reader.open({...})'), 4000);
    }
    post('ready', {});
  }

  window.Reader = {
    open,
    goTo: (pos) => S.book && goTo(pos, {}),
    getState: () => (S.book ? Object.assign(readingState(), { settings: S.settings, chapter: S.ch }) : null),
    setReading: (r) => {
      if (!S.book || !r) return;
      if ((r.updatedAt || 0) <= S.updatedAt) return;
      S.bookmarks = r.bookmarks || S.bookmarks;
      S.highlights = r.highlights || S.highlights;
      S.updatedAt = r.updatedAt;
      saveLocal();
      rerenderKeepingPlace();
    },
    setSettings: (s) => {
      Object.assign(S.settings, s || {});
      applySettings();
      relayout();
    },
    next: () => nextPage(),
    prev: () => prevPage(),
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
