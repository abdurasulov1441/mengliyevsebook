'use strict';

// GetSMS.uz gateway (see "API Ссылка.pdf"): POST form fields login, password,
// optional nickname and data=[{"phone":"998...","text":"..."}].
// The gateway only accepts requests from whitelisted server IPs: give the
// production server's static IP to GetSMS support before going live.

const config = require('./config');

async function sendSms(phone, text) {
  const s = config.sms;
  if (s.dryRun) {
    console.log(`[sms:dry-run] -> +${phone}: ${text}`);
    return { ok: true, dryRun: true };
  }
  const body = new URLSearchParams({ login: s.login, password: s.password, data: JSON.stringify([{ phone, text }]) });
  if (s.nickname) body.set('nickname', s.nickname);
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 10000);
  try {
    const res = await fetch(s.url, { method: 'POST', body, signal: ctrl.signal, headers: { 'Content-Type': 'application/x-www-form-urlencoded' } });
    const raw = await res.text();
    let json;
    try {
      json = JSON.parse(raw);
    } catch {
      json = null;
    }
    const first = Array.isArray(json) ? json[0] : json;
    if (!res.ok || !first || first.error) {
      const msg = (first && (first.error_text || first.text)) || raw.slice(0, 200) || res.statusText;
      console.error('[sms] gateway error:', msg);
      return { ok: false, error: msg };
    }
    return { ok: true, requestId: first.request_id };
  } catch (e) {
    console.error('[sms] request failed:', e.message);
    return { ok: false, error: e.message };
  } finally {
    clearTimeout(timer);
  }
}

module.exports = { sendSms };
