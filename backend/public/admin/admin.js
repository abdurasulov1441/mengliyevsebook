/* BookHub — web admin panel (no build step, talks to /api). */
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
    shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="M9 12l2 2 4-4"/>',
    wallet: '<path d="M19 7V5a2 2 0 0 0-2-2H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1"/><path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/>',
    receipt: '<path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1z"/><path d="M8 8h8M8 12h8M8 16h5"/>',
    gift: '<rect x="3" y="8" width="18" height="4"/><path d="M12 8v13M19 12v9H5v-9M7.5 8a2.5 2.5 0 0 1 0-5C11 3 12 8 12 8s1-5 4.5-5a2.5 2.5 0 0 1 0 5"/>',
  };
  const icon = (n) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${IC[n]}</svg>`;
  const paintIcons = (root = document) => $$('[data-ic]', root).forEach((el) => !el.firstChild && (el.innerHTML = icon(el.dataset.ic)));

  // ------------------------------------------------------------- session & api
  const SESSION_KEY = 'bookhub_admin_session';
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

  const period = (p) => {
    const m = ['Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun', 'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'];
    return p && p.length >= 7 ? `${m[+p.slice(5, 7) - 1]} ${p.slice(0, 4)}` : p || '';
  };
  const card = (c) => String(c || '').replace(/\D/g, '').replace(/(\d{4})(?=\d)/g, '$1 ');

  function statusBadge(b) {
    if (b.conversion_status === 'pending' || b.conversion_status === 'processing') return '<span class="badge info"><span class="spin"></span> Tayyorlanmoqda</span>';
    if (b.conversion_status === 'failed') return '<span class="badge bad">Fayl xatosi</span>';
    const map = { approved: ['ok', 'Nashrda'], pending: ['warn', 'Moderatsiyada'], rejected: ['bad', 'Rad etilgan'], unpublished: ['mute', 'Yashirilgan'], draft: ['mute', 'Qoralama'] };
    const [cls, label] = map[b.status] || map.draft;
    return `<span class="badge ${cls}">${label}</span>`;
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

  // Two ways in: SMS code (same as the app) or phone + password.
  let loginMode = 'sms';
  let codeSent = false;
  function paintLogin() {
    $$('#loginTabs button').forEach((b) => b.classList.toggle('on', b.dataset.mode === loginMode));
    $('#pwdField').classList.toggle('hidden', loginMode !== 'password');
    $('#codeField').classList.toggle('hidden', loginMode !== 'sms' || !codeSent);
    $('#loginBtn').textContent = loginMode === 'sms' && !codeSent ? 'Kod olish' : 'Kirish';
    $('#loginErr').textContent = '';
  }
  $$('#loginTabs button').forEach((b) => (b.onclick = () => ((loginMode = b.dataset.mode), (codeSent = false), paintLogin())));
  $('#loginForm').onsubmit = async (e) => {
    e.preventDefault();
    const f = new FormData(e.target);
    const phone = String(f.get('phone') || '').replace(/\D/g, '');
    $('#loginErr').textContent = '';
    try {
      let d;
      if (loginMode === 'password') {
        d = await api('POST', '/api/auth/admin-login', { phone, password: f.get('password') });
      } else if (!codeSent) {
        await api('POST', '/api/auth/request-otp', { phone });
        codeSent = true;
        paintLogin();
        $('#codeField input').focus();
        return;
      } else {
        d = await api('POST', '/api/auth/verify', { phone, code: f.get('code') });
      }
      if (!d.user.is_admin) throw new Error('Bu hisob administrator emas');
      saveSession({ accessToken: d.accessToken, refreshToken: d.refreshToken, user: d.user });
      start();
    } catch (err) {
      $('#loginErr').textContent = err.message;
    }
  };

  // ------------------------------------------------------------- router
  const ROUTES = {
    dashboard: ['Asosiy', renderDashboard],
    moderation: ['Moderatsiya va kitoblar', renderBooks],
    authors: ['Mualliflar', renderAuthors],
    payouts: ["Mualliflarga to'lovlar", renderPayouts],
    orders: ['Buyurtmalar', renderOrders],
    users: ['Foydalanuvchilar', renderUsers],
    categories: ['Kategoriyalar', renderCategories],
    settings: ['Sozlamalar', renderSettings],
  };
  let pageTimer = null;
  function route() {
    const name = location.hash.replace(/^#\/?/, '').split('?')[0] || 'dashboard';
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
      const s = await api('GET', '/api/admin/stats');
      const b = $('#pendingBadge');
      b.textContent = s.moderation_pending;
      b.classList.toggle('hidden', !s.moderation_pending);
    } catch (e) { /* ignore */ }
  }

  const stat = (label, value, sub) => `<div class="card stat"><small>${label}</small><b>${value}</b><span>${sub || ''}</span></div>`;
  const listRows = (rows, fn) => (rows && rows.length ? rows.map((r) => fn(r)).map(([a, b]) => `<div class="list-row"><span>${a}</span><b>${b}</b></div>`).join('') : '<div class="muted">Hozircha ma\'lumot yo\'q</div>');
  const empty = (text) => `<div class="empty">${text}</div>`;

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
        return `<rect x="${i * bw + 2}" y="${H - 16 - h}" width="${bw - 4}" height="${Math.max(h, d.revenue ? 2 : 0)}" rx="2"><title>${d.day}: ${money(d.revenue)} (${d.sales} ta)</title></rect>`;
      })
      .join('');
    $('#view').innerHTML = `
      ${s.moderation_pending ? `<a class="card notice" href="#/moderation"><b>${s.moderation_pending} ta kitob moderatsiyani kutmoqda</b><span>Ko'rish →</span></a>` : ''}
      <div class="grid stats">
        ${stat('Shu oy tushum', money(s.revenue_month), `jami ${money(s.revenue_total)}`)}
        ${stat('Shu oy komissiya', money(s.commission_month), `jami ${money(s.commission_total)} · ${s.settings.commission_percent}%`)}
        ${stat('Bugun sotildi', num(s.sales_today), '')}
        ${stat('Mualliflarga qarz', money(s.authors_balance), `to'lov kutilmoqda: ${money(s.payouts_pending)}`)}
        ${stat('Foydalanuvchilar', num(s.users), `bugun +${s.users_today}`)}
        ${stat('Mualliflar', num(s.authors), s.authors_unverified ? `<a href="#/authors">${s.authors_unverified} ta karta tekshiruvda</a>` : 'kartalar tekshirilgan')}
        ${stat('Nashr qilingan kitoblar', num(s.books_published), s.converting ? `${s.converting} ta tayyorlanmoqda` : '')}
      </div>
      <div class="grid two">
        <div class="card"><h3>Tushum — oxirgi 30 kun</h3><svg class="chart" viewBox="0 0 ${W} ${H - 14}" preserveAspectRatio="none">${bars}</svg><div style="display:flex;justify-content:space-between;color:var(--muted);font-size:11px">${s.sales_series.filter((_, i) => i % 5 === 0).map((d) => `<span>${d.day.slice(5)}</span>`).join('')}</div></div>
        <div class="card"><h3>Eng ko'p sotilgan</h3>${listRows(s.top_books, (b) => [`${esc(b.title)}<br><small class="muted">${esc(b.author_name || '')}</small>`, `${b.sales_count} ta`])}</div>
      </div>`;
  }

  // ------------------------------------------------------------- books & moderation
  let booksStatus = 'pending';
  let booksQuery = '';
  async function renderBooks() {
    const tabs = [['pending', 'Moderatsiya'], ['approved', 'Nashrda'], ['rejected', 'Rad etilgan'], ['unpublished', 'Yashirilgan'], ['', 'Hammasi']];
    const qs = new URLSearchParams({ limit: 200 });
    if (booksStatus) qs.set('status', booksStatus);
    if (booksQuery) qs.set('q', booksQuery);
    const d = await api('GET', '/api/admin/books?' + qs);
    $('#view').innerHTML = `
      <div class="toolbar">
        <div class="tabs">${tabs.map(([k, l]) => `<button data-st="${k}" class="${k === booksStatus ? 'on' : ''}">${l}</button>`).join('')}</div>
        <input type="search" id="bq" placeholder="Nom yoki muallif" value="${esc(booksQuery)}">
        <span class="muted">${d.total} ta</span>
      </div>
      ${d.books.length ? `<div class="table-wrap"><table>
        <thead><tr><th>Kitob</th><th>Yuklagan</th><th>Narx</th><th>Holat</th><th>Sotuv</th><th>Sana</th><th></th></tr></thead>
        <tbody>${d.books.map((b) => `<tr>
          <td><div class="cell-book">${coverEl(b)}<div><b>${esc(b.title)}</b><small>${esc(b.author_name)}</small></div></div></td>
          <td>${esc(b.owner ? b.owner.name : '—')}</td>
          <td>${b.is_free ? '<span class="badge ok">Bepul</span>' : money(b.price)}</td>
          <td>${statusBadge(b)}</td>
          <td>${num(b.sales_count)}</td>
          <td class="muted">${date(b.submitted_at || b.created_at)}</td>
          <td><div class="actions"><button class="btn sm" data-open="${b.id}">Ko'rish</button></div></td>
        </tr>`).join('')}</tbody></table></div>` : empty(booksStatus === 'pending' ? "Navbat bo'sh — yangi kitoblar shu yerda paydo bo'ladi" : "Kitoblar yo'q")}`;
    $$('.tabs button').forEach((b) => (b.onclick = () => ((booksStatus = b.dataset.st), renderBooks().catch(fail))));
    let t;
    $('#bq').oninput = (e) => {
      clearTimeout(t);
      t = setTimeout(() => ((booksQuery = e.target.value.trim()), renderBooks().then(() => $('#bq').focus()).catch(fail)), 400);
    };
    $$('[data-open]').forEach((b) => (b.onclick = () => bookModal(b.dataset.open)));
    if (d.books.some((b) => b.conversion_status === 'pending' || b.conversion_status === 'processing')) pageTimer = setInterval(() => renderBooks().catch(() => {}), 4000);
  }

  async function bookModal(id) {
    const b = await api('GET', `/api/admin/books/${id}`);
    const o = b.owner_profile;
    const r = b.conversion_report || {};
    const ready = b.conversion_status === 'ready';
    const body = openModal(b.title, `
      <div class="cover-pick">${coverEl(b)}<div>
        <div>${statusBadge(b)} ${b.is_free ? '<span class="badge ok">Bepul</span>' : `<b>${money(b.price)}</b>`}</div>
        <div class="muted">${esc(b.author_name)}${b.category ? ' · ' + esc(b.category.uz) : ''}</div>
        <div class="muted">Yuborilgan: ${date(b.submitted_at)}${b.reviewed_at ? ' · ko‘rib chiqilgan: ' + date(b.reviewed_at) : ''}</div>
      </div></div>
      ${b.rejection_reason ? `<div class="report" style="color:var(--bad)">Rad etish sababi: ${esc(b.rejection_reason)}</div>` : ''}
      ${b.conversion_error ? `<div class="report" style="color:var(--bad)">Konvertatsiya xatosi: ${esc(b.conversion_error)}</div>` : ''}
      ${o ? `<div class="report"><b>${esc(o.display_name)}</b><span>${esc(o.phone || '')} · karta: ${o.card_number ? card(o.card_number) : "yo'q"} ${o.card_verified ? '<span class="badge ok">tasdiqlangan</span>' : '<span class="badge warn">tasdiqlanmagan</span>'} ${o.status === 'blocked' ? '<span class="badge bad">bloklangan</span>' : ''}</span></div>` : ''}
      ${b.description ? `<div><b>Tavsif</b><p style="white-space:pre-wrap;margin:6px 0 0">${esc(b.description)}</p></div>` : ''}
      ${ready ? `<div class="report"><div class="nums"><span><b>${num(r.chapters)}</b>bob</span><span><b>${num(r.words)}</b>so'z</span><span><b>${num(r.images)}</b>rasm</span><span><b>${num(r.footnotes)}</b>izoh</span></div>
        ${b.source_name ? `<span class="muted">${esc(b.source_name)}</span>` : ''}
        ${(r.warnings || []).length ? `<ul class="warn-list">${r.warnings.slice(0, 8).map((w) => `<li>${esc(w)}</li>`).join('')}</ul>` : ''}</div>` : ''}
      <div class="form-foot" style="flex-wrap:wrap">
        ${ready ? `<button class="btn" data-a="read"><i data-ic="eye"></i>O'qish</button>` : ''}
        <button class="btn sm ghost" data-a="reconvert"><i data-ic="refresh"></i>Qayta konvertatsiya</button>
        <button class="btn sm ghost danger" data-a="delete"><i data-ic="trash"></i>O'chirish</button>
        ${b.status === 'approved' ? `<button class="btn" data-a="unpublish">Do'kondan olish</button>` : ''}
        ${b.status === 'pending' || b.status === 'approved' ? `<button class="btn danger" data-a="reject">Rad etish</button>` : ''}
        ${ready && b.status !== 'approved' ? `<button class="btn primary" data-a="approve"><i data-ic="check"></i>Tasdiqlash</button>` : ''}
      </div>`, true);
    const act = async (fn, msg) => {
      try {
        const res = await fn();
        toast((res && res.message) || msg || 'Bajarildi');
        closeModal();
        route();
        refreshBadge();
      } catch (e) {
        fail(e);
      }
    };
    $$('[data-a]', body).forEach((btn) => (btn.onclick = () => {
      const a = btn.dataset.a;
      if (a === 'read') return openReader(b.id);
      if (a === 'approve') return act(() => api('POST', `/api/admin/books/${b.id}/approve`));
      if (a === 'reconvert') return act(() => api('POST', `/api/admin/books/${b.id}/reconvert`));
      if (a === 'unpublish') return confirmAsk("Kitob do'kondan olinsinmi? Sotib olganlar o'qishda davom etadi.") && act(() => api('POST', `/api/admin/books/${b.id}/unpublish`));
      if (a === 'delete') return confirmAsk("Kitob butunlay o'chirilsinmi?") && act(() => api('DELETE', `/api/admin/books/${b.id}`));
      if (a === 'reject') {
        const reason = window.prompt('Rad etish sababi (muallif ko‘radi):');
        if (reason && reason.trim()) act(() => api('POST', `/api/admin/books/${b.id}/reject`, { reason: reason.trim() }));
      }
    }));
  }

  // ------------------------------------------------------------- authors
  let authorsUnverified = false;
  async function renderAuthors() {
    const d = await api('GET', '/api/admin/authors' + (authorsUnverified ? '?unverified=1' : ''));
    $('#view').innerHTML = `
      <div class="toolbar"><label class="check"><input type="checkbox" id="unv" ${authorsUnverified ? 'checked' : ''}>Faqat karta tekshiruvini kutayotganlar</label></div>
      ${d.authors.length ? `<div class="table-wrap"><table>
        <thead><tr><th>Muallif</th><th>Karta</th><th>Kitoblar</th><th>Balans</th><th>Jami daromad</th><th>Holat</th><th></th></tr></thead>
        <tbody>${d.authors.map((a) => `<tr>
          <td><div class="cell-book">${a.photo ? `<img class="avatar" src="${esc(fileUrl(a.photo))}">` : `<span class="avatar">${esc((a.display_name || '?')[0])}</span>`}<div><b>${esc(a.display_name)}</b><small>${esc(a.phone || '')}</small></div></div></td>
          <td>${a.card_number ? `${card(a.card_number)}<br><small class="muted">${esc(a.card_holder || '')}</small>` : '<span class="muted">—</span>'}</td>
          <td>${num(a.books_count)}</td>
          <td>${money(a.balance)}</td>
          <td>${money(a.earned)}</td>
          <td>${a.status === 'blocked' ? '<span class="badge bad">Bloklangan</span>' : a.card_verified ? '<span class="badge ok">Karta tasdiqlangan</span>' : a.card_number ? '<span class="badge warn">Tekshirish kerak</span>' : '<span class="badge mute">Karta yo‘q</span>'}</td>
          <td><div class="actions">
            ${a.card_number ? `<button class="btn sm ${a.card_verified ? '' : 'ok'}" data-verify="${a.user_id}" data-v="${a.card_verified ? 0 : 1}">${a.card_verified ? 'Tasdiqni olish' : 'Kartani tasdiqlash'}</button>` : ''}
            <button class="btn sm ${a.status === 'blocked' ? '' : 'danger'}" data-block="${a.user_id}" data-s="${a.status === 'blocked' ? 'active' : 'blocked'}">${a.status === 'blocked' ? 'Blokdan chiqarish' : 'Bloklash'}</button>
          </div></td></tr>`).join('')}</tbody></table></div>` : empty("Mualliflar yo'q")}`;
    $('#unv').onchange = (e) => ((authorsUnverified = e.target.checked), renderAuthors().catch(fail));
    $$('[data-verify]').forEach((b) => (b.onclick = async () => {
      try {
        await api('PUT', `/api/admin/authors/${b.dataset.verify}`, { card_verified: b.dataset.v === '1' });
        toast('Saqlandi');
        renderAuthors();
      } catch (e) { fail(e); }
    }));
    $$('[data-block]').forEach((b) => (b.onclick = async () => {
      const blocking = b.dataset.s === 'blocked';
      const note = blocking ? window.prompt('Bloklash sababi (muallifga yuboriladi):') : '';
      if (blocking && note === null) return;
      try {
        await api('PUT', `/api/admin/authors/${b.dataset.block}`, { status: b.dataset.s, ...(blocking ? { admin_note: note } : {}) });
        toast('Saqlandi');
        renderAuthors();
      } catch (e) { fail(e); }
    }));
  }

  // ------------------------------------------------------------- payouts
  async function renderPayouts() {
    const d = await api('GET', '/api/admin/payouts');
    const pending = d.payouts.filter((p) => p.status === 'pending');
    const paid = d.payouts.filter((p) => p.status !== 'pending');
    const row = (p, canPay) => `<tr>
      <td><b>${esc(p.author_name || '')}</b></td><td>${period(p.period)}</td><td><b>${money(p.amount)}</b></td>
      <td>${card(p.card_number)}<br><small class="muted">${esc(p.card_holder || '')}</small></td>
      <td class="muted">${canPay ? date(p.created_at) : date(p.paid_at) + (p.reference ? '<br>' + esc(p.reference) : '')}</td>
      <td><div class="actions">${canPay ? `<button class="btn sm" data-copy="${esc(p.card_number || '')}">Kartani nusxalash</button><button class="btn sm primary" data-pay="${p.id}">To'landi</button>` : '<span class="badge ok">O‘tkazildi</span>'}</div></td></tr>`;
    const table = (rows, canPay) => `<div class="table-wrap"><table><thead><tr><th>Muallif</th><th>Davr</th><th>Summa</th><th>Karta</th><th>Sana</th><th></th></tr></thead><tbody>${rows.map((p) => row(p, canPay)).join('')}</tbody></table></div>`;
    $('#topActions').innerHTML = `<button class="btn primary" id="gen"><i data-ic="plus"></i>${period(d.last_month)} uchun to'lovlar</button>`;
    paintIcons($('#topActions'));
    $('#gen').onclick = async () => {
      if (!confirmAsk(`${period(d.last_month)} oxirigacha yig'ilgan daromad bo'yicha to'lovlar yaratilsinmi? (karta tasdiqlangan, summa ≥ ${money(d.payout_min)})`)) return;
      try {
        const r = await api('POST', '/api/admin/payouts/generate', { period: d.last_month });
        toast(`${r.created.length} ta to'lov yaratildi${r.skipped.length ? `, ${r.skipped.length} ta o'tkazib yuborildi` : ''}`);
        renderPayouts();
      } catch (e) { fail(e); }
    };
    $('#view').innerHTML = `
      <div class="card" style="margin-bottom:14px"><h3>Yig'ilgan daromad (hali to'lovga kiritilmagan)</h3>
        ${listRows(d.accrued, (a) => [`${esc(a.author_name || 'Muallif #' + a.author_user_id)} ${a.card_verified ? '' : '<span class="badge warn">karta tasdiqlanmagan</span>'}`, money(a.amount)])}
        <p class="hint">Minimal to'lov: ${money(d.payout_min)}. Kamroq summa keyingi oyga o'tadi.</p></div>
      <h3>To'lanishi kerak (${pending.length})</h3>
      ${pending.length ? table(pending, true) : empty("Kutilayotgan to'lovlar yo'q")}
      ${paid.length ? `<h3 style="margin-top:22px">To'langanlar</h3>${table(paid, false)}` : ''}`;
    $$('[data-copy]').forEach((b) => (b.onclick = () => navigator.clipboard.writeText(b.dataset.copy).then(() => toast('Nusxalandi'))));
    $$('[data-pay]').forEach((b) => (b.onclick = async () => {
      const ref = window.prompt("To'lov raqami / izoh (ixtiyoriy):", '');
      if (ref === null) return;
      try {
        await api('POST', `/api/admin/payouts/${b.dataset.pay}/mark-paid`, { reference: ref });
        toast("Muallifga xabar yuborildi");
        renderPayouts();
      } catch (e) { fail(e); }
    }));
  }

  // ------------------------------------------------------------- orders
  let ordersStatus = 'paid';
  async function renderOrders() {
    const d = await api('GET', `/api/admin/orders?status=${ordersStatus}&limit=200`);
    const tabs = [['paid', "To'langan"], ['created', 'Kutilmoqda'], ['refunded', 'Qaytarilgan'], ['cancelled', 'Bekor']];
    $('#view').innerHTML = `
      <div class="toolbar"><div class="tabs">${tabs.map(([k, l]) => `<button data-st="${k}" class="${k === ordersStatus ? 'on' : ''}">${l}</button>`).join('')}</div><span class="muted">${d.total} ta</span></div>
      ${d.orders.length ? `<div class="table-wrap"><table><thead><tr><th>№</th><th>Kitob</th><th>Xaridor</th><th>Summa</th><th>Usul</th><th>Sana</th><th></th></tr></thead>
        <tbody>${d.orders.map((o) => `<tr><td>${o.id}</td><td>${esc(o.book_title)}</td><td>${esc(o.user_name || '')}<br><small class="muted">${esc(o.phone_number || '')}</small></td>
          <td><b>${money(o.amount)}</b></td><td>${esc(o.provider || '—')}</td><td class="muted">${date(o.paid_at || o.created_at)}</td>
          <td><div class="actions">${o.status === 'created' ? `<button class="btn sm" data-paid="${o.id}">To'landi</button>` : ''}</div></td></tr>`).join('')}</tbody></table></div>` : empty("Buyurtmalar yo'q")}`;
    $$('.tabs button').forEach((b) => (b.onclick = () => ((ordersStatus = b.dataset.st), renderOrders().catch(fail))));
    $$('[data-paid]').forEach((b) => (b.onclick = async () => {
      if (!confirmAsk("Pul haqiqatan tushganini tekshirdingizmi? Kitob xaridorga beriladi, muallifga daromad yoziladi.")) return;
      try {
        await api('POST', `/api/admin/orders/${b.dataset.paid}/mark-paid`);
        toast('Belgilandi');
        renderOrders();
      } catch (e) { fail(e); }
    }));
  }

  // ------------------------------------------------------------- users
  let usersQuery = '';
  async function renderUsers() {
    const d = await api('GET', `/api/admin/users?limit=300${usersQuery ? '&q=' + encodeURIComponent(usersQuery) : ''}`);
    const me = session.user && session.user.id;
    $('#view').innerHTML = `
      <div class="toolbar"><input type="search" id="uq" placeholder="Ism yoki telefon" value="${esc(usersQuery)}"><span class="muted">${d.total} ta</span></div>
      <div class="table-wrap"><table><thead><tr><th>Foydalanuvchi</th><th>Telefon</th><th>Kitoblar</th><th>Ro'yxatdan o'tgan</th><th>Rol</th><th></th></tr></thead>
      <tbody>${d.users.map((u) => `<tr>
        <td><b>${esc(u.name || 'Ismsiz')}</b></td><td>${esc(u.phone_number)}</td><td>${num(u.books_count)}</td><td class="muted">${date(u.created_at)}</td>
        <td>${u.is_admin ? '<span class="badge bad">Admin</span> ' : ''}${u.is_author ? '<span class="badge info">Muallif</span> ' : ''}${u.is_blocked ? '<span class="badge mute">Bloklangan</span>' : ''}</td>
        <td><div class="actions">${u.id === me ? '<span class="muted">siz</span>' : `
          <button class="btn sm" data-role="${u.id}" data-r="${u.is_admin ? 2 : 1}">${u.is_admin ? 'Adminlikdan olish' : 'Admin qilish'}</button>
          <button class="btn sm ${u.is_blocked ? '' : 'danger'}" data-blk="${u.id}" data-b="${u.is_blocked ? 0 : 1}">${u.is_blocked ? 'Blokdan chiqarish' : 'Bloklash'}</button>`}</div></td></tr>`).join('')}</tbody></table></div>`;
    let t;
    $('#uq').oninput = (e) => {
      clearTimeout(t);
      t = setTimeout(() => ((usersQuery = e.target.value.trim()), renderUsers().then(() => $('#uq').focus()).catch(fail)), 400);
    };
    const put = async (id, body) => {
      try {
        await api('PUT', `/api/admin/users/${id}`, body);
        toast('Saqlandi');
        renderUsers();
      } catch (e) { fail(e); }
    };
    $$('[data-role]').forEach((b) => (b.onclick = () => put(b.dataset.role, { role_id: +b.dataset.r })));
    $$('[data-blk]').forEach((b) => (b.onclick = () => put(b.dataset.blk, { is_blocked: b.dataset.b === '1' })));
  }

  // ------------------------------------------------------------- categories
  async function renderCategories() {
    const list = await api('GET', '/api/categories');
    $('#topActions').innerHTML = `<button class="btn primary" id="addCat"><i data-ic="plus"></i>Qo'shish</button>`;
    paintIcons($('#topActions'));
    $('#addCat').onclick = () => catModal(null);
    $('#view').innerHTML = list.length ? `<div class="table-wrap"><table><thead><tr><th>Nomi (uz)</th><th>ru</th><th>en</th><th>Kitoblar</th><th></th></tr></thead>
      <tbody>${list.map((c) => `<tr><td><b>${esc(c.name.uz)}</b></td><td>${esc(c.name.ru)}</td><td>${esc(c.name.en)}</td><td>${num(c.books_count)}</td>
        <td><div class="actions"><button class="btn sm" data-edit="${c.id}"><i data-ic="edit"></i></button><button class="btn sm danger" data-del="${c.id}"><i data-ic="trash"></i></button></div></td></tr>`).join('')}</tbody></table></div>` : empty("Kategoriyalar yo'q");
    paintIcons($('#view'));
    $$('[data-edit]').forEach((b) => (b.onclick = () => catModal(list.find((c) => c.id === +b.dataset.edit))));
    $$('[data-del]').forEach((b) => (b.onclick = async () => {
      if (!confirmAsk("Kategoriya o'chirilsinmi? Kitoblar kategoriyasiz qoladi.")) return;
      try {
        await api('DELETE', `/api/admin/categories/${b.dataset.del}`);
        renderCategories();
      } catch (e) { fail(e); }
    }));
  }
  function catModal(c) {
    const body = openModal(c ? 'Kategoriyani tahrirlash' : 'Yangi kategoriya', `
      <form id="catForm" class="modal-body" style="padding:0">
        <label>Nomi (o'zbekcha)<input type="text" name="name_uz" value="${esc(c ? c.name.uz : '')}" required></label>
        <div class="form-row"><label>Ruscha<input type="text" name="name_ru" value="${esc(c ? c.name.ru : '')}"></label><label>Inglizcha<input type="text" name="name_en" value="${esc(c ? c.name.en : '')}"></label></div>
        <div class="form-foot"><button type="button" class="btn" data-close>Bekor</button><button class="btn primary">Saqlash</button></div>
      </form>`);
    $('#catForm', body).onsubmit = async (e) => {
      e.preventDefault();
      const f = Object.fromEntries(new FormData(e.target));
      try {
        if (c) await api('PUT', `/api/admin/categories/${c.id}`, f);
        else await api('POST', '/api/admin/categories', f);
        closeModal();
        renderCategories();
      } catch (err) { fail(err); }
    };
  }

  // ------------------------------------------------------------- settings
  async function renderSettings() {
    const s = await api('GET', '/api/admin/settings');
    $('#view').innerHTML = `
      <form class="card" id="setForm" style="max-width:560px;display:flex;flex-direction:column;gap:14px">
        <label>Platforma komissiyasi (%)<input type="number" name="commission_percent" min="0" max="90" step="0.5" value="${s.commission_percent}"><span class="hint">Yangi sotuvlarga qo'llaniladi. Muallif ulushi: ${100 - s.commission_percent}%</span></label>
        <label>Minimal to'lov summasi (so'm)<input type="number" name="payout_min" min="0" step="1000" value="${s.payout_min}"><span class="hint">Bundan kam daromad keyingi oyga o'tadi</span></label>
        <label>Qo'llab-quvvatlash telefoni<input type="text" name="support_phone" value="${esc(s.support_phone)}"></label>
        <label>Telegram<input type="text" name="support_telegram" value="${esc(s.support_telegram)}" placeholder="@bookhub_support"></label>
        <div class="form-foot"><button class="btn primary">Saqlash</button></div>
        <p class="hint">API hujjatlari va sinov: <a href="/api/docs" target="_blank">/api/docs</a> (Swagger)</p>
      </form>`;
    $('#setForm').onsubmit = async (e) => {
      e.preventDefault();
      const f = Object.fromEntries(new FormData(e.target));
      try {
        await api('PUT', '/api/admin/settings', { ...f, commission_percent: +f.commission_percent, payout_min: +f.payout_min });
        toast('Saqlandi');
      } catch (err) { fail(err); }
    };
  }

  // ------------------------------------------------------------- start
  async function start() {
    if (!session) return showLogin();
    try {
      const me = await api('GET', '/api/me');
      if (!me.is_admin) {
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
  paintLogin();
  start();
})();
