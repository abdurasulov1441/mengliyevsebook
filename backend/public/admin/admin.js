/* Mengliyev's eBook — admin panel (no build step, talks to /api). */
(function () {
  'use strict';

  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const money = (n) => new Intl.NumberFormat('ru-RU').format(n || 0) + " so'm";
  const num = (n) => new Intl.NumberFormat('ru-RU').format(n || 0);
  const date = (s) => (s ? new Date(s.includes('T') ? s : s.replace(' ', 'T') + 'Z').toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
  const fileUrl = (rel) => (rel ? '/_files' + rel : '');

  const IC = {
    home: '<path d="M3 11l9-8 9 8v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z"/>',
    book: '<path d="M4 4.5A2.5 2.5 0 0 1 6.5 2H20v18H6.5A2.5 2.5 0 0 0 4 22.5z"/><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>',
    card: '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20"/>',
    users: '<circle cx="9" cy="8" r="4"/><path d="M2 21a7 7 0 0 1 14 0M17 3.5a4 4 0 0 1 0 8M22 21a7 7 0 0 0-4-6.3"/>',
    pen: '<path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>',
    tag: '<path d="M20.6 13.4l-7.2 7.2a2 2 0 0 1-2.8 0L2 12V2h10l8.6 8.6a2 2 0 0 1 0 2.8z"/><circle cx="7" cy="7" r="1.5"/>',
    gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
    menu: '<path d="M3 6h18M3 12h18M3 18h18"/>',
    x: '<path d="M18 6L6 18M6 6l12 12"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    eye: '<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8S1 12 1 12z"/><circle cx="12" cy="12" r="3"/>',
    edit: '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.1 2.1 0 0 1 3 3L12 15l-4 1 1-4z"/>',
    trash: '<path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/>',
    refresh: '<path d="M23 4v6h-6M1 20v-6h6"/><path d="M3.5 9a9 9 0 0 1 14.8-3.4L23 10M1 14l4.6 4.4A9 9 0 0 0 20.5 15"/>',
    download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>',
    upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"/>',
    check: '<path d="M20 6L9 17l-5-5"/>',
    gift: '<rect x="3" y="8" width="18" height="4"/><path d="M12 8v13M19 12v9H5v-9M7.5 8a2.5 2.5 0 0 1 0-5C11 3 12 8 12 8s1-5 4.5-5a2.5 2.5 0 0 1 0 5"/>',
  };
  const icon = (n) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${IC[n]}</svg>`;
  const paintIcons = (root = document) => $$('[data-ic]', root).forEach((el) => !el.firstChild && (el.innerHTML = icon(el.dataset.ic)));

  // ------------------------------------------------------------- session & api
  const SESSION_KEY = 'mb_admin_session';
  let session = null;
  try {
    session = JSON.parse(localStorage.getItem(SESSION_KEY) || 'null');
  } catch (e) {
    session = null;
  }
  const saveSession = (s) => {
    session = s;
    if (s) localStorage.setItem(SESSION_KEY, JSON.stringify(s));
    else localStorage.removeItem(SESSION_KEY);
  };

  async function refreshToken() {
    if (!session || !session.refreshToken) return false;
    const r = await fetch('/api/auth/refresh', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken: session.refreshToken }) });
    if (!r.ok) return false;
    const d = await r.json();
    saveSession({ ...session, accessToken: d.accessToken });
    return true;
  }

  async function api(method, url, body, retry = true) {
    const headers = {};
    if (session) headers.Authorization = 'Bearer ' + session.accessToken;
    let payload;
    if (body instanceof FormData) payload = body;
    else if (body !== undefined) {
      headers['Content-Type'] = 'application/json';
      payload = JSON.stringify(body);
    }
    const res = await fetch(url, { method, headers, body: payload });
    if (res.status === 401 && retry && session && (await refreshToken())) return api(method, url, body, false);
    if (res.status === 401 && session) {
      logout();
      throw new Error('Sessiya tugadi. Qaytadan kiring');
    }
    const data = (res.headers.get('content-type') || '').includes('json') ? await res.json() : await res.text();
    if (!res.ok) throw new Error((data && data.message) || res.statusText);
    return data;
  }

  // Multipart upload with progress (fetch cannot report upload progress).
  function upload(method, url, form, onProgress) {
    return new Promise((resolve, reject) => {
      const send = (again) => {
        const x = new XMLHttpRequest();
        x.open(method, url);
        x.setRequestHeader('Authorization', 'Bearer ' + session.accessToken);
        x.upload.onprogress = (e) => e.lengthComputable && onProgress && onProgress(e.loaded / e.total);
        x.onload = async () => {
          if (x.status === 401 && again && (await refreshToken())) return send(false);
          let d;
          try {
            d = JSON.parse(x.responseText);
          } catch (e) {
            d = { message: x.responseText };
          }
          if (x.status >= 200 && x.status < 300) resolve(d);
          else reject(new Error(d.message || 'Xato ' + x.status));
        };
        x.onerror = () => reject(new Error("Tarmoq xatosi. Internetni tekshiring"));
        x.send(form);
      };
      send(true);
    });
  }

  // ------------------------------------------------------------- ui helpers
  let toastT;
  function toast(msg, bad) {
    const t = $('#toast');
    t.textContent = msg;
    t.className = 'toast show' + (bad ? ' bad' : '');
    clearTimeout(toastT);
    toastT = setTimeout(() => (t.className = 'toast'), bad ? 4500 : 2500);
  }
  const fail = (e) => toast(e.message || String(e), true);

  function openModal(title, html, wide) {
    $('#modalTitle').textContent = title;
    $('#modalBody').innerHTML = html;
    $('#modal .modal').classList.toggle('wide', !!wide);
    $('#modal').classList.remove('hidden');
    paintIcons($('#modal'));
    return $('#modalBody');
  }
  function closeModal() {
    $('#modal').classList.add('hidden');
    $('#modalBody').innerHTML = '';
    if (modalTimer) clearInterval(modalTimer);
  }
  let modalTimer = null;
  $('#modal').addEventListener('click', (e) => {
    if (e.target.id === 'modal' || e.target.closest('[data-close]')) closeModal();
  });
  document.addEventListener('keydown', (e) => e.key === 'Escape' && (closeModal(), $('#lightbox').classList.add('hidden')));
  function lightbox(src) {
    const lb = $('#lightbox');
    $('img', lb).src = src;
    lb.classList.remove('hidden');
  }
  $('#lightbox').onclick = () => $('#lightbox').classList.add('hidden');

  const confirmAsk = (msg) => window.confirm(msg);

  function statusBadge(b) {
    const map = {
      ready: ['ok', 'Tayyor'],
      processing: ['info', '<span class="spin"></span> Konvertatsiya'],
      pending: ['info', '<span class="spin"></span> Navbatda'],
      failed: ['bad', 'Xato'],
      none: ['mute', 'Fayl yo‘q'],
    };
    const [cls, label] = map[b.conversion_status] || map.none;
    return `<span class="badge ${cls}">${label}</span>`;
  }

  function coverEl(b, cls = 'cover') {
    return b.photo ? `<img class="${cls}" src="${esc(fileUrl(b.photo))}" alt="" loading="lazy">` : `<div class="${cls}">${esc((b.title || '?')[0])}</div>`;
  }

  async function openReader(bookId) {
    const w = window.open('about:blank', '_blank');
    try {
      const d = await api('GET', `/api/books/${bookId}/read-token`);
      const url = `/reader/reader.html?remote=${bookId}&rt=${encodeURIComponent(d.token)}`;
      if (w) w.location = url;
      else location.href = url;
    } catch (e) {
      if (w) w.close();
      fail(e);
    }
  }

  async function downloadAuthed(url, filename) {
    try {
      const res = await fetch(url, { headers: { Authorization: 'Bearer ' + session.accessToken } });
      if (!res.ok) throw new Error((await res.json().catch(() => ({}))).message || res.statusText);
      const blob = await res.blob();
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = filename;
      a.click();
      setTimeout(() => URL.revokeObjectURL(a.href), 5000);
    } catch (e) {
      fail(e);
    }
  }

  // ------------------------------------------------------------- auth screens
  function showLogin() {
    $('#shell').classList.add('hidden');
    $('#login').classList.remove('hidden');
  }
  function logout() {
    if (session && session.refreshToken) fetch('/api/auth/logout', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken: session.refreshToken }) }).catch(() => {});
    saveSession(null);
    showLogin();
  }
  $('#logout').onclick = logout;
  $('#loginForm').onsubmit = async (e) => {
    e.preventDefault();
    const f = new FormData(e.target);
    $('#loginErr').textContent = '';
    try {
      const d = await api('POST', '/api/auth/admin-login', { phone: f.get('phone'), password: f.get('password') });
      saveSession({ accessToken: d.accessToken, refreshToken: d.refreshToken, user: d.user });
      start();
    } catch (err) {
      $('#loginErr').textContent = err.message;
    }
  };

  // ------------------------------------------------------------- router
  const ROUTES = {
    dashboard: ['Asosiy', renderDashboard],
    books: ['Kitoblar', renderBooks],
    payments: ["To'lovlar", renderPayments],
    users: ['Foydalanuvchilar', renderUsers],
    authors: ['Mualliflar', renderAuthors],
    categories: ['Kategoriyalar', renderCategories],
    settings: ['Sozlamalar', renderSettings],
  };
  let pageTimer = null;
  function route() {
    const name = (location.hash.replace(/^#\/?/, '').split('?')[0] || 'dashboard');
    const r = ROUTES[name] || ROUTES.dashboard;
    if (pageTimer) clearInterval(pageTimer);
    pageTimer = null;
    $$('#nav a').forEach((a) => a.classList.toggle('on', a.dataset.route === name));
    $('#pageTitle').textContent = r[0];
    $('#topActions').innerHTML = '';
    $('#view').innerHTML = '<div class="empty">Yuklanmoqda…</div>';
    $('#side').classList.remove('open');
    $('#sideScrim').classList.remove('open');
    r[1]().catch(fail);
  }
  window.addEventListener('hashchange', route);
  $('#menuBtn').onclick = () => {
    $('#side').classList.add('open');
    $('#sideScrim').classList.add('open');
  };
  $('#sideScrim').onclick = () => {
    $('#side').classList.remove('open');
    $('#sideScrim').classList.remove('open');
  };

  async function refreshBadge() {
    try {
      const d = await api('GET', '/api/payments/get-payments?status=1&limit=1');
      const b = $('#pendingBadge');
      b.textContent = d.pending;
      b.classList.toggle('hidden', !d.pending);
    } catch (e) { /* ignore */ }
  }

  // ------------------------------------------------------------- dashboard
  async function renderDashboard() {
    const s = await api('GET', '/api/admin/stats');
    const max = Math.max(1, ...s.sales_series.map((d) => d.revenue));
    const W = 600;
    const H = 170;
    const bw = W / s.sales_series.length;
    const bars = s.sales_series
      .map((d, i) => {
        const h = Math.round((d.revenue / max) * (H - 24));
        return `<rect x="${i * bw + 2}" y="${H - 16 - h}" width="${bw - 4}" height="${Math.max(h, d.revenue ? 2 : 0)}" rx="2"><title>${d.day}: ${money(d.revenue)} (${d.sales} ta)</title></rect>` +
          '';
      })
      .join('');
    $('#view').innerHTML = `
      <div class="grid stats">
        ${stat('Foydalanuvchilar', num(s.users), `bugun +${s.users_today}`)}
        ${stat('Kitoblar', num(s.books_ready), `jami ${s.books}${s.books_failed ? ` · <span style="color:var(--bad)">${s.books_failed} xato</span>` : ''}`)}
        ${stat("Tekshiriladigan to'lovlar", num(s.payments_pending), `<a href="#/payments">ko'rish →</a>`)}
        ${stat('Bugun sotildi', num(s.sales_today), `jami ${num(s.sales_total)} ta`)}
        ${stat('Shu oy tushum', money(s.revenue_month), `jami ${money(s.revenue_total)}`)}
        ${stat("Faol o'quvchilar", num(s.active_readers_week), 'oxirgi 7 kun')}
      </div>
      <div class="grid two">
        <div class="card"><h3>Tushum — oxirgi 30 kun</h3><svg class="chart" viewBox="0 0 ${W} ${H - 14}" preserveAspectRatio="none">${bars}</svg><div style="display:flex;justify-content:space-between;color:var(--muted);font-size:11px">${s.sales_series.filter((_, i) => i % 5 === 0).map((d) => `<span>${d.day.slice(5)}</span>`).join('')}</div></div>
        <div class="card"><h3>Eng ko'p sotilgan</h3>${listRows(s.top_books, (b) => [esc(b.title), `${b.sold} ta`])}</div>
      </div>
      <div class="grid two" style="margin-top:14px">
        <div class="card"><h3>Eng ko'p o'qilayotgan</h3>${listRows(s.most_read, (b) => [esc(b.title), `${b.readers} o'quvchi · o'rtacha ${b.avg_percent || 0}%`])}</div>
        <div class="card"><h3>Konvertatsiya navbati</h3><div class="list-row"><span>Hozir ishlayapti</span><b>${s.queue.running ? 'ha' : "yo'q"}</b></div><div class="list-row"><span>Navbatda</span><b>${s.queue.queued}</b></div></div>
      </div>`;
  }
  const stat = (label, value, sub) => `<div class="card stat"><small>${label}</small><b>${value}</b><span>${sub || ''}</span></div>`;
  const listRows = (rows, fn) => (rows && rows.length ? rows.map((r) => fn(r)).map(([a, b]) => `<div class="list-row"><span>${a}</span><b>${b}</b></div>`).join('') : '<div class="muted">Hozircha ma\'lumot yo\'q</div>');

  // ------------------------------------------------------------- books
  let lookups = { authors: [], categories: [] };
  async function loadLookups() {
    const [a, c] = await Promise.all([api('GET', '/api/authors/get-authors?limit=500'), api('GET', '/api/categories/categories')]);
    lookups = { authors: a.authors, categories: c };
  }

  async function renderBooks() {
    $('#topActions').innerHTML = `<button class="btn primary" id="addBook"><i data-ic="plus"></i>Kitob qo'shish</button>`;
    paintIcons($('#topActions'));
    $('#addBook').onclick = () => bookModal(null);
    await loadLookups();
    const view = $('#view');
    view.innerHTML = `
      <div class="toolbar">
        <input type="search" id="bq" placeholder="Qidirish: nom, muallif…">
        <select id="bstatus"><option value="">Barcha holatlar</option><option value="ready">Tayyor</option><option value="work">Konvertatsiyada</option><option value="failed">Xato</option><option value="hidden">Yashirilgan</option></select>
        <select id="bcat"><option value="">Barcha kategoriyalar</option>${lookups.categories.map((c) => `<option value="${c.id}">${esc(c.name.uz)}</option>`).join('')}</select>
      </div>
      <div id="bookTable"></div>`;
    let books = [];
    const draw = () => {
      const qv = $('#bq').value.toLowerCase();
      const st = $('#bstatus').value;
      const cat = $('#bcat').value;
      const list = books.filter((b) => {
        if (qv && !(b.title + ' ' + b.author.uz).toLowerCase().includes(qv)) return false;
        if (cat && String(b.category_id) !== cat) return false;
        if (st === 'ready' && b.conversion_status !== 'ready') return false;
        if (st === 'work' && !['pending', 'processing'].includes(b.conversion_status)) return false;
        if (st === 'failed' && b.conversion_status !== 'failed') return false;
        if (st === 'hidden' && b.is_published) return false;
        return true;
      });
      $('#bookTable').innerHTML = list.length
        ? `<div class="table-wrap"><table><thead><tr><th>Kitob</th><th>Kategoriya</th><th>Narx</th><th>Holat</th><th>Hajm</th><th></th></tr></thead><tbody>${list
            .map(
              (b) => `<tr data-id="${b.id}">
              <td><div class="cell-book">${coverEl(b)}<div><b>${esc(b.title)}</b><small>${esc(b.author.uz || 'Muallif ko‘rsatilmagan')}</small></div></div></td>
              <td>${esc(b.category.uz || '—')}</td>
              <td>${b.is_free ? '<span class="badge ok">Bepul</span>' : money(b.price)}</td>
              <td>${statusBadge(b)} ${b.is_published ? '' : '<span class="badge mute">Yashirin</span>'}</td>
              <td class="muted">${b.chapters ? `${b.chapters} bob · ${num(b.words)} so‘z` : '—'}</td>
              <td><div class="actions">
                ${b.conversion_status === 'ready' ? `<button class="btn sm" data-act="read" title="O'qib ko'rish"><i data-ic="eye"></i>O'qish</button>` : ''}
                <button class="btn sm" data-act="edit"><i data-ic="edit"></i></button>
                ${b.conversion_status === 'ready' ? `<button class="btn sm" data-act="epub" title="EPUB yuklab olish"><i data-ic="download"></i></button>` : ''}
                <button class="btn sm danger" data-act="del"><i data-ic="trash"></i></button>
              </div></td></tr>`
            )
            .join('')}</tbody></table></div>`
        : `<div class="empty">${books.length ? 'Hech narsa topilmadi' : "Hozircha kitob yo'q. «Kitob qo'shish» tugmasini bosing va Word faylni yuklang."}</div>`;
      paintIcons($('#bookTable'));
    };
    const load = async () => {
      const d = await api('GET', '/api/books/get-books?all=1&limit=500');
      books = d.books;
      draw();
      const busy = books.some((b) => ['pending', 'processing'].includes(b.conversion_status));
      if (busy && !pageTimer) pageTimer = setInterval(() => load().catch(() => {}), 3000);
      if (!busy && pageTimer) {
        clearInterval(pageTimer);
        pageTimer = null;
      }
    };
    $('#bq').oninput = draw;
    $('#bstatus').onchange = draw;
    $('#bcat').onchange = draw;
    $('#bookTable').onclick = async (e) => {
      const btn = e.target.closest('[data-act]');
      if (!btn) return;
      const id = +btn.closest('tr').dataset.id;
      const b = books.find((x) => x.id === id);
      if (btn.dataset.act === 'read') openReader(id);
      if (btn.dataset.act === 'edit') bookModal(b);
      if (btn.dataset.act === 'epub') downloadAuthed(`/api/books/${id}/epub`, `${b.slug || 'book'}.epub`);
      if (btn.dataset.act === 'del' && confirmAsk(`"${b.title}" kitobini o'chirasizmi? Sotib olganlar ham undan mahrum bo'ladi.`)) {
        await api('DELETE', `/api/books/delete-book/${id}`).then(() => toast("O'chirildi"), fail);
        load();
      }
    };
    window.__reloadBooks = load;
    await load();
  }

  function reportHtml(b) {
    if (b.conversion_status === 'failed') return `<div class="report" style="background:var(--bad-soft);color:var(--bad)"><b>Konvertatsiya xatosi</b><div>${esc(b.conversion_error || '')}</div></div>`;
    if (b.conversion_status !== 'ready' || !b.conversion_report) {
      return ['pending', 'processing'].includes(b.conversion_status) ? `<div class="report"><b><span class="spin" style="display:inline-block"></span> Konvertatsiya ketmoqda…</b><div class="muted">Word fayl telefon uchun qulay formatga o'girilmoqda. Odatda bir necha soniya.</div></div>` : '';
    }
    const r = b.conversion_report;
    const toc = (r.toc || []).map((t) => `<div class="l${t.level}">${esc(t.title)}</div>`).join('');
    return `<div class="report">
      <b>✔ Kitob tayyor${b.source_name ? ` — ${esc(b.source_name)}` : ''}</b>
      <div class="nums"><div><b>${r.chapters}</b>bob</div><div><b>${r.tocEntries}</b>mundarija</div><div><b>${num(r.words)}</b>so'z</div><div><b>${r.images}</b>rasm</div><div><b>${r.footnotes}</b>izoh</div><div><b>${(r.stats && r.stats.readingMinutes) || '—'}</b>daqiqa</div></div>
      ${r.warnings && r.warnings.length ? `<ul class="warn-list">${r.warnings.map((w) => `<li>${esc(w)}</li>`).join('')}</ul>` : ''}
      ${toc ? `<div class="hint">Avtomatik topilgan mundarija (to'g'riligini tekshiring):</div><div class="toc-preview">${toc}</div>` : ''}
      <div><button class="btn sm" type="button" data-read="${b.id}"><i data-ic="eye"></i>O'qib ko'rish</button> <button class="btn sm" type="button" data-reconvert="${b.id}"><i data-ic="refresh"></i>Qayta konvertatsiya</button></div>
    </div>`;
  }

  function bookModal(book) {
    const isEdit = !!book;
    const b = book || { title: '', description: '', is_free: true, price: 0, is_published: true };
    const body = openModal(isEdit ? 'Kitobni tahrirlash' : "Yangi kitob", `
      <form id="bookForm" class="modal-body" style="padding:0">
        <div class="drop ${b.source_name ? 'has' : ''}" id="fileDrop">
          <i data-ic="upload" style="width:28px;height:28px"></i>
          <b id="fileLabel">${b.source_name ? esc(b.source_name) : 'Word faylni shu yerga tashlang yoki bosing'}</b>
          <span>.docx (tavsiya), .doc, .epub, .txt, .rtf, .odt — tizim o'zi telefon uchun formatlaydi</span>
          <input type="file" name="file" accept=".docx,.doc,.epub,.txt,.rtf,.odt" hidden>
        </div>
        <label>Kitob nomi <span class="hint">${isEdit ? '' : "— bo'sh qoldirsangiz, kitobning titul sahifasidan avtomatik olinadi"}</span><input type="text" name="title" value="${esc(b.title)}" ${isEdit ? 'required' : ''} maxlength="300"></label>
        <label>Tavsif<textarea name="description" maxlength="10000">${esc(b.description)}</textarea></label>
        <div class="form-row">
          <label>Muallif<select name="author_id"><option value="">— tanlang —</option>${lookups.authors.map((a) => `<option value="${a.id}" ${a.id === b.author_id ? 'selected' : ''}>${esc(a.name.uz)}</option>`).join('')}</select></label>
          <label>Kategoriya<select name="category_id"><option value="">— tanlang —</option>${lookups.categories.map((c) => `<option value="${c.id}" ${c.id === b.category_id ? 'selected' : ''}>${esc(c.name.uz)}</option>`).join('')}</select></label>
        </div>
        <div class="form-row">
          <label class="check"><input type="checkbox" name="is_free" ${b.is_free ? 'checked' : ''}> Bepul kitob</label>
          <label id="priceWrap" class="${b.is_free ? 'hidden' : ''}">Narx (so'm)<input type="number" name="price" min="0" step="1000" value="${b.price || ''}"></label>
        </div>
        <label class="check"><input type="checkbox" name="is_published" ${b.is_published ? 'checked' : ''}> Ilovada ko'rsatish <span class="hint">(o'chirsangiz, faqat admin ko'radi — avval tekshirib oling)</span></label>
        <div class="cover-pick">
          <div id="coverPrev">${coverEl(b)}</div>
          <div><button type="button" class="btn sm" id="coverBtn"><i data-ic="upload"></i>Muqova rasmi</button><div class="hint">JPG/PNG, 2:3 nisbat tavsiya etiladi</div></div>
          <input type="file" name="image" accept="image/*" hidden>
        </div>
        <div class="progress hidden" id="upProg"><i></i></div>
        <div id="reportBox">${isEdit ? reportHtml(b) : ''}</div>
        ${isEdit ? `<details><summary class="muted" style="cursor:pointer">Foydalanuvchiga bepul berish</summary><div class="toolbar" style="margin:10px 0 0"><input type="tel" id="grantPhone" placeholder="+998 90 123 45 67" style="max-width:220px"><button type="button" class="btn sm" id="grantBtn"><i data-ic="gift"></i>Berish</button></div></details>` : ''}
        <div class="form-foot"><button type="button" class="btn" data-close>Yopish</button><button type="submit" class="btn primary" id="saveBook">${isEdit ? 'Saqlash' : 'Yaratish'}</button></div>
      </form>`, true);
    paintIcons(body);
    const form = $('#bookForm');
    const fileInput = $('input[name=file]', form);
    const imgInput = $('input[name=image]', form);
    const drop = $('#fileDrop');
    drop.onclick = () => fileInput.click();
    drop.ondragover = (e) => {
      e.preventDefault();
      drop.classList.add('over');
    };
    drop.ondragleave = () => drop.classList.remove('over');
    drop.ondrop = (e) => {
      e.preventDefault();
      drop.classList.remove('over');
      if (e.dataTransfer.files[0]) {
        fileInput.files = e.dataTransfer.files;
        fileInput.onchange();
      }
    };
    fileInput.onchange = () => {
      const f = fileInput.files[0];
      if (!f) return;
      drop.classList.add('has');
      $('#fileLabel').textContent = `${f.name} (${(f.size / 1048576).toFixed(1)} MB)`;
    };
    $('#coverBtn').onclick = () => imgInput.click();
    imgInput.onchange = () => {
      const f = imgInput.files[0];
      if (f) $('#coverPrev').innerHTML = `<img class="cover" src="${URL.createObjectURL(f)}" alt="">`;
    };
    $('input[name=is_free]', form).onchange = (e) => $('#priceWrap').classList.toggle('hidden', e.target.checked);

    const bindReport = () => {
      $$('[data-read]', form).forEach((x) => (x.onclick = () => openReader(+x.dataset.read)));
      $$('[data-reconvert]', form).forEach((x) => (x.onclick = async () => {
        try {
          const d = await api('POST', `/api/books/${x.dataset.reconvert}/reconvert`);
          watch(d.book.id);
        } catch (e) {
          fail(e);
        }
      }));
      paintIcons(form);
    };
    bindReport();
    const watch = (id) => {
      if (modalTimer) clearInterval(modalTimer);
      const tickFn = async () => {
        const fresh = await api('GET', `/api/books/${id}`);
        if (!$('#reportBox')) return clearInterval(modalTimer);
        $('#reportBox').innerHTML = reportHtml(fresh);
        bindReport();
        if (!['pending', 'processing'].includes(fresh.conversion_status)) {
          clearInterval(modalTimer);
          if (window.__reloadBooks) window.__reloadBooks();
          if (fresh.conversion_status === 'ready') toast('Kitob tayyor!');
        }
      };
      modalTimer = setInterval(() => tickFn().catch(() => {}), 1500);
      tickFn().catch(() => {});
    };
    if (isEdit && ['pending', 'processing'].includes(b.conversion_status)) watch(b.id);

    if (isEdit) {
      $('#grantBtn').onclick = async () => {
        try {
          await api('POST', `/api/books/${b.id}/grant`, { phone: $('#grantPhone').value });
          toast('Kitob berildi');
          $('#grantPhone').value = '';
        } catch (e) {
          fail(e);
        }
      };
    }

    form.onsubmit = async (e) => {
      e.preventDefault();
      const fd = new FormData();
      fd.set('title', form.title.value.trim());
      fd.set('description', form.description.value.trim());
      fd.set('author_id', form.author_id.value);
      fd.set('category_id', form.category_id.value);
      fd.set('is_free', form.is_free.checked ? 'true' : 'false');
      fd.set('price', form.is_free.checked ? '0' : form.price.value || '0');
      fd.set('is_published', form.is_published.checked ? 'true' : 'false');
      if (fileInput.files[0]) fd.set('file', fileInput.files[0]);
      if (imgInput.files[0]) fd.set('image', imgInput.files[0]);
      const btn = $('#saveBook');
      btn.disabled = true;
      const prog = $('#upProg');
      prog.classList.remove('hidden');
      try {
        const d = await upload(isEdit ? 'PUT' : 'POST', isEdit ? `/api/books/update-book/${b.id}` : '/api/books/create-book', fd, (p) => ($('i', prog).style.width = Math.round(p * 100) + '%'));
        toast(d.message || 'Saqlandi');
        if (window.__reloadBooks) window.__reloadBooks();
        if (!isEdit) {
          // Switch the dialog to edit mode for the new book and follow conversion.
          bookModal(d.book);
        } else if (['pending', 'processing'].includes(d.book.conversion_status)) {
          watch(d.book.id);
        }
      } catch (err) {
        fail(err);
      } finally {
        if ($('#saveBook')) $('#saveBook').disabled = false;
        if ($('#upProg')) $('#upProg').classList.add('hidden');
      }
    };
  }

  // ------------------------------------------------------------- payments
  async function renderPayments() {
    const state = { status: '1', q: '' };
    $('#view').innerHTML = `
      <div class="toolbar">
        <div class="tabs" id="ptabs"><button data-s="1" class="on">Kutilmoqda</button><button data-s="2">Tasdiqlangan</button><button data-s="3">Rad etilgan</button><button data-s="">Hammasi</button></div>
        <input type="search" id="pq" placeholder="Ism, telefon yoki kitob">
      </div>
      <div id="plist"></div>`;
    const load = async () => {
      const d = await api('GET', `/api/payments/get-payments?limit=200&status=${state.status}&q=${encodeURIComponent(state.q)}`);
      $('#plist').innerHTML = d.payments.length
        ? `<div class="grid pay-grid">${d.payments
            .map(
              (p) => `<div class="card pay" data-id="${p.id}">
          ${p.receipt_image ? `<img class="receipt" src="${esc(fileUrl(p.receipt_image))}" alt="Chek" loading="lazy">` : ''}
          <dl>
            <dt>Kitob</dt><dd>${esc(p.book_title)}</dd>
            <dt>Summa</dt><dd>${money(p.amount)}</dd>
            <dt>Foydalanuvchi</dt><dd>${esc(p.user_name || '—')}</dd>
            <dt>Telefon</dt><dd><a href="tel:+${esc((p.phone_number || '').replace(/\D/g, ''))}">${esc(p.phone_number)}</a></dd>
            <dt>To'lov vaqti</dt><dd>${esc(p.approved_at || '—')}</dd>
            <dt>Izoh</dt><dd>${esc(p.comment || '—')}</dd>
            <dt>Yuborilgan</dt><dd>${date(p.created_at)}</dd>
            <dt>Holat</dt><dd><span class="badge ${p.status_id === 2 ? 'ok' : p.status_id === 3 ? 'bad' : 'warn'}">${esc(p.status.uz)}</span>${p.admin_comment ? ` <span class="muted">${esc(p.admin_comment)}</span>` : ''}</dd>
          </dl>
          <div class="actions">
            ${p.status_id !== 2 ? `<button class="btn ok" data-st="2"><i data-ic="check"></i>Tasdiqlash</button>` : ''}
            ${p.status_id !== 3 ? `<button class="btn danger" data-st="3"><i data-ic="x"></i>Rad etish</button>` : ''}
          </div></div>`
            )
            .join('')}</div>`
        : `<div class="empty">${state.status === '1' ? "Tekshiriladigan to'lov yo'q 🎉" : "To'lovlar yo'q"}</div>`;
      paintIcons($('#plist'));
      refreshBadge();
    };
    $('#ptabs').onclick = (e) => {
      const b = e.target.closest('button');
      if (!b) return;
      state.status = b.dataset.s;
      $$('#ptabs button').forEach((x) => x.classList.toggle('on', x === b));
      load().catch(fail);
    };
    let t;
    $('#pq').oninput = (e) => {
      clearTimeout(t);
      t = setTimeout(() => {
        state.q = e.target.value;
        load().catch(fail);
      }, 300);
    };
    $('#plist').onclick = async (e) => {
      if (e.target.classList.contains('receipt')) return lightbox(e.target.src);
      const btn = e.target.closest('[data-st]');
      if (!btn) return;
      const id = btn.closest('.pay').dataset.id;
      const st = +btn.dataset.st;
      let comment = st === 2 ? 'Tasdiqlandi' : '';
      if (st === 3) {
        comment = prompt("Rad etish sababi (foydalanuvchi ko'radi):", "To'lov topilmadi");
        if (comment === null) return;
      }
      try {
        const d = await api('PUT', `/api/payments/update-payment/${id}`, { status: st, comment });
        toast(d.message);
        load();
      } catch (err) {
        fail(err);
      }
    };
    await load();
  }

  // ------------------------------------------------------------- users
  async function renderUsers() {
    $('#topActions').innerHTML = `<button class="btn" id="addAdmin"><i data-ic="plus"></i>Administrator</button>`;
    paintIcons($('#topActions'));
    $('#addAdmin').onclick = () => {
      const body = openModal('Yangi administrator', `
        <form id="admForm" class="modal-body" style="padding:0">
          <label>Ism<input type="text" name="name" required></label>
          <label>Telefon<input type="tel" name="phone" placeholder="+998 90 123 45 67" required></label>
          <label>Parol (kamida 8 belgi)<input type="password" name="password" minlength="8" required></label>
          <div class="form-foot"><button type="button" class="btn" data-close>Bekor</button><button class="btn primary">Yaratish</button></div>
        </form>`);
      $('#admForm', body).onsubmit = async (e) => {
        e.preventDefault();
        const f = e.target;
        try {
          await api('POST', '/api/admin/users', { name: f.name.value, phone: f.phone.value, password: f.password.value, role_id: 1 });
          toast('Administrator yaratildi');
          closeModal();
          load();
        } catch (err) {
          fail(err);
        }
      };
    };
    $('#view').innerHTML = `<div class="toolbar"><input type="search" id="uq" placeholder="Ism yoki telefon"><select id="urole"><option value="">Hammasi</option><option value="2">Foydalanuvchilar</option><option value="1">Administratorlar</option></select></div><div id="ulist"></div>`;
    const load = async () => {
      const d = await api('GET', `/api/admin/users?limit=300&q=${encodeURIComponent($('#uq').value)}&role=${$('#urole').value}`);
      $('#ulist').innerHTML = d.users.length
        ? `<div class="table-wrap"><table><thead><tr><th>Foydalanuvchi</th><th>Rol</th><th>Kitoblar</th><th>Ro'yxatdan o'tgan</th><th>Oxirgi kirish</th><th></th></tr></thead><tbody>${d.users
            .map(
              (u) => `<tr data-id="${u.id}"><td><b>${esc(u.name || '—')}</b><div class="muted">${esc(u.phone_number)}</div></td>
            <td>${u.role_id === 1 ? '<span class="badge info">Admin</span>' : '<span class="badge mute">Foydalanuvchi</span>'} ${u.is_blocked ? '<span class="badge bad">Bloklangan</span>' : ''}</td>
            <td>${u.books_count}</td><td class="muted">${date(u.created_at)}</td><td class="muted">${date(u.last_login_at)}</td>
            <td><div class="actions"><button class="btn sm" data-open>Batafsil</button></div></td></tr>`
            )
            .join('')}</tbody></table></div><div class="pager">Jami: ${d.total}</div>`
        : '<div class="empty">Foydalanuvchilar topilmadi</div>';
    };
    let t;
    $('#uq').oninput = () => {
      clearTimeout(t);
      t = setTimeout(() => load().catch(fail), 300);
    };
    $('#urole').onchange = () => load().catch(fail);
    $('#ulist').onclick = (e) => {
      if (!e.target.closest('[data-open]')) return;
      userModal(+e.target.closest('tr').dataset.id, load);
    };
    await load();
  }

  async function userModal(id, reload) {
    const [u, books] = await Promise.all([api('GET', `/api/admin/users/${id}`), api('GET', '/api/books/get-books?all=1&limit=500')]);
    const owned = new Set(u.books.map((b) => b.id));
    const body = openModal(u.name || u.phone_number, `
      <div class="report"><div class="nums"><div><b>${esc(u.phone_number)}</b>telefon</div><div><b>${u.books.length}</b>kitob</div><div><b>${date(u.created_at)}</b>ro'yxatdan o'tgan</div></div></div>
      <h3 style="margin:4px 0 0">Kitoblari</h3>
      ${u.books.length ? u.books.map((b) => `<div class="list-row"><span>${esc(b.title)} <span class="muted">· ${b.source === 'admin' ? 'admin bergan' : "to'lov"} · ${date(b.created_at)}</span></span><span>${Math.round((b.percent || 0) * 100)}% <button class="btn sm danger" data-revoke="${b.id}">Olish</button></span></div>`).join('') : '<div class="muted">Sotib olingan kitob yo‘q (bepul kitoblar hammaga ochiq)</div>'}
      <div class="toolbar" style="margin:0"><select id="grantSel" style="max-width:320px"><option value="">Kitobni bepul berish…</option>${books.books.filter((b) => !b.is_free && !owned.has(b.id)).map((b) => `<option value="${b.id}">${esc(b.title)}</option>`).join('')}</select><button class="btn sm" id="grantGo"><i data-ic="gift"></i>Berish</button></div>
      <h3 style="margin:4px 0 0">Boshqaruv</h3>
      <form id="uForm" class="modal-body" style="padding:0">
        <div class="form-row"><label>Ism<input type="text" name="name" value="${esc(u.name)}"></label>
        <label>Rol<select name="role_id"><option value="2" ${u.role_id === 2 ? 'selected' : ''}>Foydalanuvchi</option><option value="1" ${u.role_id === 1 ? 'selected' : ''}>Administrator</option></select></label></div>
        <label>Yangi parol (admin panelga kirish uchun, ixtiyoriy)<input type="password" name="password" minlength="8" placeholder="${u.has_password ? 'o‘rnatilgan — o‘zgartirish uchun yozing' : 'kamida 8 belgi'}"></label>
        <label class="check"><input type="checkbox" name="is_blocked" ${u.is_blocked ? 'checked' : ''}> Bloklash</label>
        <div class="form-foot"><button type="button" class="btn" data-close>Yopish</button><button class="btn primary">Saqlash</button></div>
      </form>`);
    paintIcons(body);
    $('#grantGo').onclick = async () => {
      const bid = $('#grantSel').value;
      if (!bid) return;
      try {
        await api('POST', `/api/books/${bid}/grant`, { user_id: id });
        toast('Kitob berildi');
        userModal(id, reload);
      } catch (e) {
        fail(e);
      }
    };
    $$('[data-revoke]', body).forEach((b) => (b.onclick = async () => {
      if (!confirmAsk('Kitobni foydalanuvchidan olib qo‘yasizmi?')) return;
      await api('DELETE', `/api/books/${b.dataset.revoke}/grant/${id}`).catch(fail);
      userModal(id, reload);
    }));
    $('#uForm').onsubmit = async (e) => {
      e.preventDefault();
      const f = e.target;
      const payload = { name: f.name.value, role_id: +f.role_id.value, is_blocked: f.is_blocked.checked };
      if (f.password.value) payload.password = f.password.value;
      try {
        await api('PUT', `/api/admin/users/${id}`, payload);
        toast('Saqlandi');
        closeModal();
        reload();
      } catch (err) {
        fail(err);
      }
    };
  }

  // ------------------------------------------------------------- authors
  async function renderAuthors() {
    $('#topActions').innerHTML = `<button class="btn primary" id="addAuthor"><i data-ic="plus"></i>Muallif qo'shish</button>`;
    paintIcons($('#topActions'));
    const load = async () => {
      const d = await api('GET', '/api/authors/get-authors?limit=500');
      $('#view').innerHTML = d.authors.length
        ? `<div class="table-wrap"><table><thead><tr><th>Muallif</th><th>Ruscha / Inglizcha</th><th>Kitoblar</th><th></th></tr></thead><tbody>${d.authors
            .map(
              (a) => `<tr data-id="${a.id}"><td><div class="cell-book">${a.photo ? `<img class="avatar" src="${esc(fileUrl(a.photo))}" alt="">` : `<span class="avatar">${esc(a.name.uz[0] || '?')}</span>`}<div><b>${esc(a.name.uz)}</b><small>${esc((a.about.uz || '').slice(0, 80))}</small></div></div></td>
            <td class="muted">${esc(a.name.ru)}<br>${esc(a.name.en)}</td><td>${a.books_count}</td>
            <td><div class="actions"><button class="btn sm" data-edit><i data-ic="edit"></i></button><button class="btn sm danger" data-del><i data-ic="trash"></i></button></div></td></tr>`
            )
            .join('')}</tbody></table></div>`
        : '<div class="empty">Mualliflar yo‘q</div>';
      paintIcons($('#view'));
      $('#view').onclick = async (e) => {
        const tr = e.target.closest('tr');
        if (!tr) return;
        const a = d.authors.find((x) => x.id === +tr.dataset.id);
        if (e.target.closest('[data-edit]')) authorModal(a, load);
        if (e.target.closest('[data-del]') && confirmAsk(`"${a.name.uz}" o'chirilsinmi? Kitoblari muallifsiz qoladi.`)) {
          await api('DELETE', `/api/authors/delete-author/${a.id}`).then(() => toast("O'chirildi"), fail);
          load();
        }
      };
    };
    $('#addAuthor').onclick = () => authorModal(null, load);
    await load();
  }

  function authorModal(a, reload) {
    const v = a || { name: {}, about: {} };
    const body = openModal(a ? 'Muallifni tahrirlash' : 'Yangi muallif', `
      <form id="aForm" class="modal-body" style="padding:0">
        <div class="form-row three"><label>Ism (uz)<input type="text" name="name1" value="${esc(v.name.uz)}" required></label><label>Имя (ru)<input type="text" name="name2" value="${esc(v.name.ru)}"></label><label>Name (en)<input type="text" name="name3" value="${esc(v.name.en)}"></label></div>
        <label>Haqida (uz)<textarea name="about1">${esc(v.about.uz)}</textarea></label>
        <div class="form-row"><label>Об авторе (ru)<textarea name="about2">${esc(v.about.ru)}</textarea></label><label>About (en)<textarea name="about3">${esc(v.about.en)}</textarea></label></div>
        <div class="cover-pick"><div id="aPrev">${v.photo ? `<img class="avatar" style="width:64px;height:64px" src="${esc(fileUrl(v.photo))}">` : '<span class="avatar" style="width:64px;height:64px">?</span>'}</div><button type="button" class="btn sm" id="aPhotoBtn"><i data-ic="upload"></i>Rasm</button><input type="file" name="image" accept="image/*" hidden></div>
        <div class="form-foot"><button type="button" class="btn" data-close>Bekor</button><button class="btn primary">Saqlash</button></div>
      </form>`);
    paintIcons(body);
    const f = $('#aForm');
    $('#aPhotoBtn').onclick = () => f.image.click();
    f.image.onchange = () => f.image.files[0] && ($('#aPrev').innerHTML = `<img class="avatar" style="width:64px;height:64px" src="${URL.createObjectURL(f.image.files[0])}">`);
    f.onsubmit = async (e) => {
      e.preventDefault();
      const fd = new FormData(f);
      if (!f.image.files[0]) fd.delete('image');
      try {
        await upload(a ? 'PUT' : 'POST', a ? `/api/authors/update-author/${a.id}` : '/api/authors/create-author', fd);
        toast('Saqlandi');
        closeModal();
        reload();
      } catch (err) {
        fail(err);
      }
    };
  }

  // ------------------------------------------------------------- categories
  async function renderCategories() {
    $('#topActions').innerHTML = `<button class="btn primary" id="addCat"><i data-ic="plus"></i>Kategoriya qo'shish</button>`;
    paintIcons($('#topActions'));
    const load = async () => {
      const list = await api('GET', '/api/categories/categories');
      $('#view').innerHTML = list.length
        ? `<div class="table-wrap"><table><thead><tr><th>O'zbekcha</th><th>Русский</th><th>English</th><th>Kitoblar</th><th></th></tr></thead><tbody>${list
            .map((c) => `<tr data-id="${c.id}"><td><b>${esc(c.name.uz)}</b></td><td>${esc(c.name.ru)}</td><td>${esc(c.name.en)}</td><td>${c.books_count}</td><td><div class="actions"><button class="btn sm" data-edit><i data-ic="edit"></i></button><button class="btn sm danger" data-del><i data-ic="trash"></i></button></div></td></tr>`)
            .join('')}</tbody></table></div>`
        : '<div class="empty">Kategoriyalar yo‘q</div>';
      paintIcons($('#view'));
      $('#view').onclick = async (e) => {
        const tr = e.target.closest('tr');
        if (!tr) return;
        const c = list.find((x) => x.id === +tr.dataset.id);
        if (e.target.closest('[data-edit]')) catModal(c, load);
        if (e.target.closest('[data-del]') && confirmAsk(`"${c.name.uz}" o'chirilsinmi?`)) {
          await api('DELETE', `/api/categories/delete-category/${c.id}`).then(() => toast("O'chirildi"), fail);
          load();
        }
      };
    };
    $('#addCat').onclick = () => catModal(null, load);
    await load();
  }

  function catModal(c, reload) {
    const v = c ? c.name : {};
    const body = openModal(c ? 'Kategoriyani tahrirlash' : 'Yangi kategoriya', `
      <form id="cForm" class="modal-body" style="padding:0">
        <label>O'zbekcha<input type="text" name="name1" value="${esc(v.uz)}" required></label>
        <label>Русский<input type="text" name="name2" value="${esc(v.ru)}"></label>
        <label>English<input type="text" name="name3" value="${esc(v.en)}"></label>
        <div class="form-foot"><button type="button" class="btn" data-close>Bekor</button><button class="btn primary">Saqlash</button></div>
      </form>`);
    $('#cForm', body).onsubmit = async (e) => {
      e.preventDefault();
      const f = e.target;
      const payload = { name1: f.name1.value, name2: f.name2.value, name3: f.name3.value };
      try {
        await api(c ? 'PUT' : 'POST', c ? `/api/categories/update-category/${c.id}` : '/api/categories/create-category', payload);
        toast('Saqlandi');
        closeModal();
        reload();
      } catch (err) {
        fail(err);
      }
    };
  }

  // ------------------------------------------------------------- settings
  async function renderSettings() {
    const c = await api('GET', '/api/references/contact/1');
    $('#view').innerHTML = `
      <div class="grid two">
        <form class="card" id="contactForm" style="display:flex;flex-direction:column;gap:12px">
          <h3>To'lov rekvizitlari</h3>
          <div class="hint">Foydalanuvchi kitob sotib olayotganda shu karta ma'lumotlarini ko'radi va to'lov skrinshotini yuboradi.</div>
          <label>Karta raqami<input type="text" name="card_number" value="${esc(c.card_number)}" placeholder="8600 1234 5678 9012"></label>
          <label>Karta egasi<input type="text" name="name" value="${esc(c.name)}"></label>
          <label>Aloqa telefoni<input type="text" name="phone" value="${esc(c.phone)}"></label>
          <label>Qo'shimcha izoh<input type="text" name="note" value="${esc(c.note)}" placeholder="Masalan: to'lovdan keyin 1 soat ichida tasdiqlanadi"></label>
          <div><button class="btn primary">Saqlash</button></div>
        </form>
        <form class="card" id="passForm" style="display:flex;flex-direction:column;gap:12px">
          <h3>Mening parolim</h3>
          <label>Yangi parol<input type="password" name="password" minlength="8" required></label>
          <div><button class="btn">Parolni o'zgartirish</button></div>
          <hr style="border:0;border-top:1px solid var(--line);width:100%">
          <h3>Oflayn tekshirish</h3>
          <div class="hint">Serversiz tekshirish: <code>npm run convert -- "kitob.docx"</code> buyrug'i <code>backend/offline/index.html</code> kutubxonasini yaratadi.</div>
        </form>
      </div>`;
    $('#contactForm').onsubmit = async (e) => {
      e.preventDefault();
      const f = e.target;
      try {
        await api('PUT', '/api/references/contact/1', { card_number: f.card_number.value, name: f.name.value, phone: f.phone.value, note: f.note.value });
        toast('Saqlandi');
      } catch (err) {
        fail(err);
      }
    };
    $('#passForm').onsubmit = async (e) => {
      e.preventDefault();
      try {
        await api('PUT', `/api/admin/users/${session.user.id}`, { password: e.target.password.value });
        toast("Parol o'zgartirildi");
        e.target.reset();
      } catch (err) {
        fail(err);
      }
    };
  }

  // ------------------------------------------------------------- start
  async function start() {
    if (!session) return showLogin();
    try {
      const me = await api('GET', '/api/users/me');
      if (me.role_id !== 1) {
        saveSession(null);
        $('#loginErr').textContent = 'Bu hisob administrator emas';
        return showLogin();
      }
      session.user = me;
      saveSession(session);
    } catch (e) {
      return showLogin();
    }
    $('#login').classList.add('hidden');
    $('#shell').classList.remove('hidden');
    $('#me').textContent = session.user.name || session.user.phone_number;
    paintIcons();
    route();
    refreshBadge();
    setInterval(refreshBadge, 60000);
  }
  paintIcons();
  start();
})();
