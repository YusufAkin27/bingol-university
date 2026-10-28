#!/usr/bin/env node
// Demo sohbet verisi: test kullanicilari, birebir ve grup sohbetleri, yanitlar, tepkiler, gorsel.
// Kullanim: BASE=http://localhost:8080 node scripts/seed-demo-chat.js   (repo kokunden)
// Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu backend logundan okunur), demo hesap mevcut.
// Tekrar calistirilabilir: kullanicilar varsa giris yapilir, sohbetler yeniden olusturulmaz (birebir mevcut doner),
// gruplar ve mesajlar her calistirmada yeniden eklenir.
const { execSync } = require('node:child_process');
const zlib = require('node:zlib');

const BASE = (process.env.BASE || 'http://localhost:8080').replace(/\/+$/, '');
const DEMO = { email: process.env.DEMO_EMAIL || 'mobil.test@bingol.edu.tr', password: process.env.DEMO_PASSWORD || 'BuTest2026x' };
const PASS = 'Demo1234x';
const people = [
  ['ayse.yilmaz', 'Ayşe Yılmaz'],
  ['mehmet.demir', 'Mehmet Demir'],
  ['zeynep.kaya', 'Zeynep Kaya'],
  ['can.ozturk', 'Can Öztürk'],
  ['elif.arslan', 'Elif Arslan'],
  ['burak.sahin', 'Burak Şahin'],
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let seq = 0;
const cid = () => `seed-${Date.now()}-${++seq}`;

async function api(method, path, token, body) {
  const res = await fetch(`${BASE}/api${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch (_) { /* bos govde */ }
  return { status: res.status, json };
}

async function login(email, password) {
  const r = await api('POST', '/auth/login', null, { email, password });
  return r.status === 200 ? r.json.accessToken : null;
}

function codeFromLogs(email) {
  try {
    const out = execSync('docker compose logs backend --since 2m', { encoding: 'utf8', maxBuffer: 1 << 26 });
    const m = [...out.matchAll(new RegExp(`${email.replace('.', '\\.')}[^\\n]*?kodu: (\\d+)`, 'g'))];
    return m.length ? m[m.length - 1][1] : null;
  } catch (_) { return null; }
}

async function ensureUser(email, name) {
  const existing = await login(email, PASS);
  if (existing) return existing;
  await api('POST', '/auth/register', null, { email, password: PASS, displayName: name, acceptTerms: true });
  await sleep(1500);
  const code = codeFromLogs(email);
  if (code) {
    const v = await api('POST', '/auth/verify-email', null, { email, code, password: PASS });
    if (v.status === 200 && v.json?.accessToken) return v.json.accessToken;
  }
  return login(email, PASS);
}

async function send(token, convId, text, extra = {}) {
  const r = await api('POST', `/conversations/${convId}/messages`, token, { text, clientId: cid(), ...extra });
  if (r.status !== 201 && r.status !== 200) console.log(`  ! mesaj gonderilemedi (${r.status}) ${JSON.stringify(r.json)}`);
  await sleep(250);
  return r.json;
}

async function react(token, messageId, emoji) {
  await api('PUT', `/messages/${messageId}/reaction`, token, { emoji });
}

function pngBuffer(w, h) {
  // Gradyan + desenli basit PNG (harici kutuphane gerektirmez).
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    const row = y * (w * 3 + 1);
    raw[row] = 0;
    for (let x = 0; x < w; x++) {
      const i = row + 1 + x * 3;
      const band = Math.floor(x / 60) % 2 === Math.floor(y / 60) % 2 ? 18 : 0;
      raw[i] = Math.min(255, 190 + Math.floor((x / w) * 60) + band);
      raw[i + 1] = Math.min(255, 40 + Math.floor((y / h) * 110) + band);
      raw[i + 2] = Math.min(255, 50 + Math.floor((x / w) * 70) + band);
    }
  }
  const crcTable = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (buf) => {
    let c = 0xffffffff;
    for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const c = Buffer.alloc(4);
    c.writeUInt32BE(crc(td));
    return Buffer.concat([len, td, c]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

async function uploadImage(token, convId, w, h, name) {
  const form = new FormData();
  form.append('file', new Blob([pngBuffer(w, h)], { type: 'image/png' }), name);
  const res = await fetch(`${BASE}/api/conversations/${convId}/media`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: form,
  });
  const json = await res.json().catch(() => null);
  if (res.status >= 300) console.log(`  ! gorsel yuklenemedi (${res.status}) ${JSON.stringify(json)}`);
  return json?.id;
}

(async () => {
  const health = await fetch(`${BASE}/actuator/health`).catch(() => null);
  if (!health || !health.ok) { console.log('backend ayakta degil'); process.exit(1); }

  const demoTok = await login(DEMO.email, DEMO.password);
  if (!demoTok) { console.log('demo hesapla giris yapilamadi'); process.exit(1); }
  const me = (await api('GET', '/users/me', demoTok)).json;

  console.log('== kullanicilar');
  const users = [];
  for (const [slug, name] of people) {
    const email = `${slug}@bingol.edu.tr`;
    const token = await ensureUser(email, name);
    if (!token) { console.log(`  ! ${email} olusturulamadi (kayit sinirina takilmis olabilir)`); continue; }
    const u = (await api('GET', '/users/me', token)).json;
    users.push({ name, email, token, id: u.id });
    console.log(`  ${name} (#${u.id})`);
  }
  const by = (first) => users.find((u) => u.name.startsWith(first));
  const [ayse, mehmet, zeynep, can, elif, burak] = ['Ayşe', 'Mehmet', 'Zeynep', 'Can', 'Elif', 'Burak'].map(by);
  if (!ayse || !mehmet || !zeynep || !can) { console.log('yeterli kullanici yok, durduruldu'); process.exit(1); }

  console.log('== birebir sohbetler');
  const dm = async (peer) => (await api('POST', '/conversations', demoTok, { userId: peer.id })).json;

  const c1 = await dm(ayse);
  await send(ayse.token, c1.id, 'Selam! Yarınki algoritma sınavına çalıştın mı?');
  const m1 = await send(demoTok, c1.id, 'Selam Ayşe, yarım kaldı biraz 😅 Sen nasılsın?');
  await send(ayse.token, c1.id, 'Ben de son üniteye bakıyorum. Kütüphanede buluşup beraber çalışalım mı?');
  const q = await send(demoTok, c1.id, 'Olur! Saat kaçta müsaitsin?');
  const a = await send(ayse.token, c1.id, '15:00 gibi uygun olur, ikinci kata geçeriz.', { replyToMessageId: q.id });
  await react(demoTok, a.id, '👍');
  await send(ayse.token, c1.id, 'Notlarını da getir lütfen 🙏');

  const c2 = await dm(mehmet);
  await send(mehmet.token, c2.id, 'Merhaba, kulüp toplantısı perşembe günü saat 17:00\'de.');
  await send(demoTok, c2.id, 'Teşekkürler Mehmet, salon belli mi?');
  await send(mehmet.token, c2.id, 'Mühendislik Fakültesi B-204. Projeksiyon da hazır olacak.');
  await send(demoTok, c2.id, 'Harika, görüşürüz 👍');

  if (elif) {
    const c3 = await dm(elif);
    await send(elif.token, c3.id, 'Yemekhane menüsünü gördün mü? Bugün mantı var 😍');
  }

  console.log('== gruplar');
  const g1 = (await api('POST', '/conversations', demoTok, {
    title: 'Bilgisayar Müh. 2. Sınıf',
    memberIds: [ayse.id, mehmet.id, zeynep.id, can.id],
  })).json;
  if (g1?.id) {
    await send(demoTok, g1.id, 'Herkese merhaba! Grubu ders duyuruları için açtım.');
    await send(zeynep.token, g1.id, 'Süper, teşekkürler 🙌');
    const ann = await send(mehmet.token, g1.id, 'Veri yapıları ödevi 12 Kasım\'a kadar. Teslim OBS üzerinden.');
    await react(demoTok, ann.id, '👍');
    await react(ayse.token, ann.id, '👍');
    await react(can.token, ann.id, '😮');
    await send(can.token, g1.id, 'Ödevde ağaç yapısı zorunlu mu?', { replyToMessageId: ann.id });
    await send(demoTok, g1.id, 'Evet, ikili arama ağacı istiyor. Örnek kodu paylaşırım.');
    const imgId = await uploadImage(zeynep.token, g1.id, 800, 520, 'ders-programi.png');
    if (imgId) await send(zeynep.token, g1.id, 'Güncel ders programı bu 👇', { attachmentIds: [imgId] });
    const imgId2 = await uploadImage(ayse.token, g1.id, 520, 760, 'tahta-notlari.png');
    if (imgId2) await send(ayse.token, g1.id, '', { attachmentIds: [imgId2] });
    const last = await send(can.token, g1.id, 'Vize tarihleri belli oldu mu? Ben bir şey duymadım.');
    await react(mehmet.token, last.id, '🤔');
    await send(ayse.token, g1.id, 'Hocanın duyurusuna göre 24 Kasım haftası. Ders notları OBS\'de.');
  }

  const g2 = (await api('POST', '/conversations', demoTok, {
    title: 'Hafta Sonu Futbol ⚽',
    memberIds: [mehmet.id, can.id, ...(burak ? [burak.id] : [])],
  })).json;
  if (g2?.id) {
    await send(can.token, g2.id, 'Cumartesi 14:00 halı saha, kaç kişiyiz?');
    const y = await send(demoTok, g2.id, 'Ben varım!');
    if (burak) await send(burak.token, g2.id, 'Ben de geliyorum, top bende 👌', { replyToMessageId: y.id });
    await send(mehmet.token, g2.id, 'Ben biraz geç kalabilirim, başlayın.');
    await send(can.token, g2.id, 'Saha ücreti kişi başı 60 TL, tamam mı?');
  }

  const g3 = (await api('POST', '/conversations', demoTok, {
    title: 'Proje Ekibi',
    memberIds: [zeynep.id, elif ? elif.id : can.id],
  })).json;
  if (g3?.id) {
    await send(demoTok, g3.id, 'Proje sunumu için görev dağılımını yapalım.');
    await send(zeynep.token, g3.id, 'Ben arayüz tasarımını alırım.');
    await send(elif ? elif.token : can.token, g3.id, 'Ben de veritabanı ve raporu alayım.');
    await send(demoTok, g3.id, 'Ben backend ve sunumu hazırlarım. Cuma günü birleştirelim.');
  }

  console.log(`\nTamam. Demo hesap: ${DEMO.email} / ${DEMO.password} (#${me.id})`);
  console.log(`Diger test hesaplari: <ad.soyad>@bingol.edu.tr / ${PASS}`);
})().catch((e) => { console.error(e); process.exit(1); });
