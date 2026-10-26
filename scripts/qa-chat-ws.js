#!/usr/bin/env node
'use strict';
// Sohbet WebSocket/STOMP QA matrisi (T2): kimlik/oturum omru, askiya alma, cok cihaz, siralama, yeniden baglanma ve
// bosluk kapatma, uye cikarma, Unicode, kotu cerceveler, 200 eszamanli baglanti.
// Kullanim: COMPOSE_PROJECT_NAME=wt_t2 BASE=http://localhost:8102 node scripts/qa-chat-ws.js
//   SLOW=1  -> token suresi dolunca SEND reddi + kalp atisi zaman asimi (~100 sn ekler)
// Kayit ucu IP basina saatte 10 sinirli: once `docker compose exec -T redis redis-cli flushall`.
const { BASE, WS_URL, check, sleep, api, admin, redis, register, forgeJwt, Stomp, login, summary } = require('./qa-chat-lib');

function clearMsgLimits() {
  const keys = redis('keys rl:msg:*').split(/\r?\n/).filter(Boolean);
  if (keys.length) redis('del ' + keys.join(' '));
}
let seq = 0;
const cid = () => 'w' + Date.now().toString(36) + (seq++);
const em = (n) => '\u{1F600}'.repeat(n);

(async () => {
  const sfx = Math.floor(Math.random() * 1e6);
  console.log('== kullanicilar');
  const U = [];
  for (const [i, n] of ['Ali', 'Ayse', 'Can', 'Dilek'].entries()) U.push(await register(`qw${i}x${sfx}@bingol.edu.tr`, 'QW ' + n));
  const [A, B, C, D] = U;
  const ab = (await api('POST', '/conversations', A.token, { userId: B.id })).json.id;
  const grp = (await api('POST', '/conversations', A.token, { title: 'WSGrup', memberIds: [B.id, C.id] })).json.id;

  console.log('== oturum acma/kimlik');
  let x = await Stomp.open(null, { timeout: 3000 });
  check('CONNECT oncesi SEND: baglanti kurulmaz', !x.connected);
  // CONNECT gondermeyen baglanti (timeToFirstMessage 10 sn) kapanir
  const idle = process.env.SLOW !== '1' ? 0 : await new Promise((resolve) => {
    const ws = new WebSocket(WS_URL, ['v12.stomp']);
    const t0 = Date.now();
    ws.onclose = () => resolve(Date.now() - t0);
    ws.onerror = () => {};
    setTimeout(() => resolve(-1), 80000);
  });
  // Spring oturum denetimi 60 sn'de bir calisir: timeToFirstMessage(10 sn) + en cok ~60 sn. Yalnizca SLOW=1'de beklenir.
  if (process.env.SLOW === '1') check('CONNECT gondermeyen baglanti en gec ~75 sn icinde kapanir', idle > 0 && idle < 75000, idle);
  const bad = await new Promise((resolve) => {
    const ws = new WebSocket(WS_URL, ['v12.stomp']);
    ws.onopen = () => ws.send('SEND\ndestination:/app/chat.send\ncontent-type:application/json\n\n{"conversationId":1,"text":"x","clientId":"z"}\0');
    ws.onmessage = (ev) => resolve(String(ev.data));
    ws.onclose = () => resolve('closed');
    setTimeout(() => resolve('timeout'), 6000);
  });
  check('CONNECT\'siz SEND hata/kapanis ile sonuclanir', /ERROR|closed/.test(bad), bad.slice(0, 80));

  console.log('== abonelik sahtekarligi');
  x = await Stomp.open(A.token);
  x.subscribe(`/user/${B.id}/queue/messages`);
  check('baska kullanici kuyrugu aboneligi reddedilir', !!(await x.waitFor((f) => f.command === 'ERROR', 3000)));
  x = await Stomp.open(A.token);
  x.subscribe('/queue/messages');
  check('/queue/messages (user oneksiz) reddedilir', !!(await x.waitFor((f) => f.command === 'ERROR', 3000)));
  x = await Stomp.open(A.token);
  x.subscribe('/user/queue/*');
  check('joker abonelik reddedilir', !!(await x.waitFor((f) => f.command === 'ERROR', 3000)));

  console.log('== iki cihaz, siralama, gonderen sahteciligi');
  const a1 = await login(A.token), a2 = await login(A.token), b1 = await login(B.token), b2 = await login(B.token);
  clearMsgLimits();
  const N = 20;
  for (let i = 0; i < N; i++) a1.send('/app/chat.send', { conversationId: ab, text: 'sira-' + i, clientId: 'ord-' + i, senderId: B.id, userId: B.id });
  for (let t = 0; t < 40 && b1.count('messages', (m) => m.clientId && m.clientId.startsWith('ord-')) < N; t++) await sleep(250);
  await sleep(1500);
  const got = (cl) => cl.frames.filter((f) => f.command === 'MESSAGE' && f.headers.destination === '/user/queue/messages' && f.json.clientId && f.json.clientId.startsWith('ord-')).map((f) => f.json);
  const g1 = got(b1), g2 = got(b2), ga2 = got(a2);
  check('B cihaz 1: 20 mesaj', g1.length === N, g1.length);
  check('B cihaz 2: 20 mesaj', g2.length === N, g2.length);
  check('A diger cihaz (echo): 20 mesaj', ga2.length === N, ga2.length);
  check('teslim sirasi = gonderim sirasi', g1.every((m, i) => m.clientId === 'ord-' + i) && g1.every((m, i) => i === 0 || m.id > g1[i - 1].id));
  check('gonderen kimlikten alinir (payload senderId yok sayilir)', g1.every((m) => m.senderId === A.id));
  check('tekrar teslim yok', new Set(g1.map((m) => m.id)).size === N);

  console.log('== yeniden baglanma ve bosluk kapatma (after=)');
  const lastSeen = g1[g1.length - 1].id;
  b1.close(); b2.close();
  await sleep(600);
  clearMsgLimits();
  for (let i = 0; i < 6; i++) await api('POST', `/conversations/${ab}/messages`, A.token, { text: 'kacan-' + i, clientId: 'gap-' + i });
  const b3 = await login(B.token);
  const gapPage = await api('GET', `/conversations/${ab}/messages?after=${lastSeen}&size=50`, B.token);
  check('after= kacirilan 6 mesaji eksiksiz getirir', gapPage.json.items.length === 6 && gapPage.json.items.every((m, i) => m.clientId === 'gap-' + i), gapPage.json.items.map((m) => m.clientId));
  a1.send('/app/chat.send', { conversationId: ab, text: 'baglandiktan sonra', clientId: 'gap-live' });
  const live = await b3.on('messages', (m) => m.clientId === 'gap-live');
  check('yeniden baglanan canli mesaj alir', !!live);
  const after2 = await api('GET', `/conversations/${ab}/messages?after=${gapPage.json.items[5].id}&size=50`, B.token);
  check('canli mesaj sonraki after= sorgusunda da var (id ile tekillestirilir)', after2.json.items.length === 1 && after2.json.items[0].id === live.json.id);
  check('WS mesaji REST ile ayni id', live.json.id === after2.json.items[0].id);

  console.log('== askiya alma (WS ortasinda)');
  const ds = await login(D.token);
  const dgrp = (await api('POST', '/conversations', A.token, { userId: D.id })).json.id;
  const sg = (await api('POST', '/conversations', A.token, { title: 'AskiGrup', memberIds: [B.id, D.id] })).json.id;
  clearMsgLimits();
  ds.send('/app/chat.send', { conversationId: dgrp, text: 'askidan once', clientId: 'sp-1' });
  check('askidan once D gonderir', !!(await ds.on('messages', (m) => m.clientId === 'sp-1')));
  check('admin D\'yi askiya alir', (await admin('POST', `/users/${D.id}/suspend`, { reason: 'qa-ws' })).status === 204);
  ds.send('/app/chat.send', { conversationId: dgrp, text: 'askida', clientId: 'sp-2' });
  const spErr = await ds.waitFor((f) => f.command === 'ERROR' || (f.command === 'MESSAGE' && f.json && f.json.clientId === 'sp-2'), 3000);
  check('askidaki kullanicinin SEND\'i reddedilir', !!spErr && spErr.command === 'ERROR', spErr && spErr.command);
  const hist = await api('GET', `/conversations/${dgrp}/messages`, A.token);
  check('askidaki kullanicinin mesaji kaydedilmedi', !hist.json.items.some((m) => m.clientId === 'sp-2'));
  const ds2 = await login(D.token);
  check('askidaki kullanici yeniden baglanamaz', !ds2.connected);
  // Askidakine A yazinca acik (eski) WS oturumuna teslim edilmemeli
  const dsOpen = await login(D.token).catch(() => null);
  await admin('POST', `/users/${D.id}/unsuspend`);
  const dLive = await login(D.token);
  check('askidan alininca baglanabilir', dLive.connected);
  await admin('POST', `/users/${D.id}/suspend`, { reason: 'qa-ws-2' });
  const before = dLive.count('messages');
  clearMsgLimits();
  const bsg = await login(B.token);
  await api('POST', `/conversations/${sg}/messages`, A.token, { text: 'askidaki uye de grupta', clientId: 'sg-1' });
  check('grubun digeri askisiz uyesi alir', !!(await bsg.on('messages', (m) => m.clientId === 'sg-1')));
  await sleep(800);
  check('askidaki kullanicinin ACIK WS oturumuna teslim edilmez', dLive.count('messages', (m) => m.clientId === 'sg-1') === 0);
  bsg.close();
  clearMsgLimits();
  const toSusp = await api('POST', `/conversations/${dgrp}/messages`, A.token, { text: 'askidakine', clientId: 'sp-3' });
  await sleep(1200);
  check('askidakine mesaj gonderimi 403 (kayit yok)', toSusp.status === 403, toSusp.status);
  await admin('POST', `/users/${D.id}/unsuspend`);
  dLive.close();

  console.log('== hesabi silinen kullanici acik WS oturumunda');
  const E = await register(`qw4x${sfx}@bingol.edu.tr`, 'QW Eda');
  const ae = (await api('POST', '/conversations', A.token, { userId: E.id })).json.id;
  const es = await login(E.token);
  clearMsgLimits();
  es.send('/app/chat.send', { conversationId: ae, text: 'silinmeden once', clientId: 'del-1' });
  check('silmeden once gonderir', !!(await es.on('messages', (m) => m.clientId === 'del-1')));
  check('hesap silinir', (await api('DELETE', '/users/me', E.token, { password: 'Sifre1234' })).status === 204);
  es.send('/app/chat.send', { conversationId: ae, text: 'hayalet', clientId: 'del-2' });
  const delErr = await es.waitFor((f) => (f.command === 'MESSAGE' && f.headers.destination === '/user/queue/errors') || f.command === 'ERROR', 3000);
  const ghostSaved = (await api('GET', `/conversations/${ae}/messages`, A.token)).json.items.some((m) => m.clientId === 'del-2');
  check('silinen kullanici acik WS ile mesaj kaydedemez', !ghostSaved && !!delErr, { ghostSaved, delErr: delErr && delErr.json });

  console.log('== uye cikarilinca / ayrilinca acik WS oturumu');
  const ga = await login(A.token), gb = await login(B.token), gc = await login(C.token);
  clearMsgLimits();
  ga.send('/app/chat.send', { conversationId: grp, text: 'herkese', clientId: 'g-1' });
  check('uc uye de alir', !!(await gb.on('messages', (m) => m.clientId === 'g-1')) && !!(await gc.on('messages', (m) => m.clientId === 'g-1')));
  check('A C\'yi cikarir', (await api('DELETE', `/conversations/${grp}/members/${C.id}`, A.token)).status === 204);
  ga.send('/app/chat.send', { conversationId: grp, text: 'C yok artik', clientId: 'g-2' });
  await gb.on('messages', (m) => m.clientId === 'g-2');
  await sleep(800);
  check('cikarilan C yeni mesaji almaz', gc.count('messages', (m) => m.clientId === 'g-2') === 0);
  gc.send('/app/chat.send', { conversationId: grp, text: 'hala yaziyorum', clientId: 'g-3' });
  const gcErr = await gc.on('errors', (m) => m.clientId === 'g-3');
  check('cikarilan C gonderemez (CONVERSATION_NOT_FOUND)', !!gcErr && gcErr.json.code === 'CONVERSATION_NOT_FOUND', gcErr && gcErr.json);
  gc.send('/app/chat.typing', { conversationId: grp });
  gc.send('/app/chat.read', { conversationId: grp, lastMessageId: 1 });
  await sleep(600);
  check('cikarilan C yazma/okundu bilgisi uretmez', gb.count('typing') === 0 && gb.count('read-receipts') === 0);
  ga.send('/app/chat.typing', { conversationId: grp });
  check('uye yaziyor bilgisi diger uyeye gider', !!(await gb.on('typing', (m) => m.userId === A.id)));
  check('B ayrilir', (await api('POST', `/conversations/${grp}/leave`, B.token)).status === 204);
  ga.send('/app/chat.send', { conversationId: grp, text: 'B de yok', clientId: 'g-4' });
  await sleep(800);
  check('ayrilan B yeni mesaji almaz', gb.count('messages', (m) => m.clientId === 'g-4') === 0);

  console.log('== engel (grup, WS ortasinda)');
  const grp2 = (await api('POST', '/conversations', A.token, { title: 'Engel', memberIds: [B.id, C.id] })).json.id;
  clearMsgLimits();
  check('B A\'yi engeller', (await api('POST', `/users/${A.id}/block`, B.token)).status === 204);
  ga.send('/app/chat.send', { conversationId: grp2, text: 'engelliyim', clientId: 'bl-1' });
  check('C (engelsiz) alir', !!(await gc.on('messages', (m) => m.clientId === 'bl-1')));
  await sleep(800);
  check('A\'yi engelleyen B WS teslimi almaz', gb.count('messages', (m) => m.clientId === 'bl-1') === 0);
  gb.send('/app/chat.typing', { conversationId: grp2 });
  await sleep(800);
  check('engelliye yaziyor bilgisi gitmez', ga.count('typing', (m) => m.userId === B.id) === 0);
  await api('DELETE', `/users/${A.id}/block`, B.token);

  console.log('== Unicode ve kotu cerceveler (WS)');
  clearMsgLimits();
  const abConv = ab;
  const cases = [
    ['2000 emoji WS ile gecer', em(2000), em(2000)],
    ['Arapca + emoji', 'مرحبا \u{1F44B}', 'مرحبا \u{1F44B}'],
    ['bidi override temizlenir', 'a‮b', 'ab'],
  ];
  const a1b = await login(A.token);
  const b4 = await login(B.token);
  for (const [name, t, expect] of cases) {
    const id = cid();
    a1b.send('/app/chat.send', { conversationId: abConv, text: t, clientId: id });
    const m = await b4.on('messages', (mm) => mm.clientId === id, 5000);
    check(name, !!m && m.json.text === expect, m && m.json.text.length);
  }
  const id2 = cid();
  a1b.send('/app/chat.send', { conversationId: abConv, text: em(2001), clientId: id2 });
  const tl = await a1b.on('errors', (m) => m.clientId === id2);
  check('2001 emoji MESSAGE_TOO_LONG', !!tl && tl.json.code === 'MESSAGE_TOO_LONG', tl && tl.json);
  const badPayloads = [
    ['conversationId yok', { text: 'x', clientId: cid() }],
    ['conversationId metin', { conversationId: 'abc', text: 'x', clientId: cid() }],
    ['text nesne', { conversationId: abConv, text: { a: 1 }, clientId: cid() }],
    ['clientId 65 karakter', { conversationId: abConv, text: 'x', clientId: 'c'.repeat(65) }],
    ['dizi govde', [1, 2, 3]],
    ['null govde', 'null'],
    ['bos govde', ''],
    ['cok buyuk sayi', { conversationId: 1e30, text: 'x', clientId: cid() }],
  ];
  for (const [name, p] of badPayloads) {
    const before = a1b.frames.length;
    a1b.send('/app/chat.send', p);
    await sleep(500);
    const err = a1b.frames.slice(before).some((f) => f.command === 'MESSAGE' && f.headers.destination === '/user/queue/errors');
    check(`kotu yuk (${name}) hata kuyruguna duser, baglanti acik`, err && !a1b.closed);
  }
  a1b.send('/app/chat.read', { conversationId: abConv, lastMessageId: -1 });
  a1b.send('/app/chat.read', { conversationId: abConv, lastMessageId: null });
  a1b.send('/app/chat.typing', {});
  await sleep(600);
  check('kotu read/typing yukleri baglantiyi dusurmez', !a1b.closed);
  const big = await Stomp.open(A.token);
  big.send('/app/chat.send', { conversationId: abConv, text: 'x'.repeat(20 * 1024), clientId: cid() });
  await sleep(1500);
  check('16 KB ustu cerceve baglantiyi kapatir', big.closed);
  const health = await fetch(BASE + '/actuator/health');
  check('sunucu ayakta', health.status === 200);

  console.log('== hiz sinirli patlama (WS)');
  clearMsgLimits();
  const rlConv = (await api('POST', '/conversations', B.token, { userId: C.id })).json.id;
  const bc = await login(B.token);
  for (let i = 0; i < 40; i++) bc.send('/app/chat.send', { conversationId: rlConv, text: 'p' + i, clientId: 'burst-' + i });
  await sleep(4000);
  const errs = bc.count('errors', (m) => m.code === 'RATE_LIMITED');
  const stored = (await api('GET', `/conversations/${rlConv}/messages?size=50`, B.token)).json.items.length;
  check('40 mesajdan 30\'u kaydedilir, 10\'u RATE_LIMITED', stored === 30 && errs === 10, { stored, errs });
  check('hiz asimi baglantiyi dusurmez', !bc.closed);
  clearMsgLimits();

  [a1, a2, a1b, b3, b4, bc, ds, es, ga, gb, gc].forEach((s) => s.close());
  await sleep(1000);
  console.log('== 200 eszamanli baglanti');
  const sessions = { A: [], B: [], C: [] };
  const plan = [['A', A, 40], ['B', B, 80], ['C', C, 80]];
  const t0 = Date.now();
  const opens = [];
  for (const [k, u, n] of plan) for (let i = 0; i < n; i++) opens.push(login(u.token).then((s) => sessions[k].push(s)));
  for (let i = 0; i < opens.length; i += 50) await Promise.all(opens.slice(i, i + 50));
  const all = [...sessions.A, ...sessions.B, ...sessions.C];
  const okConn = all.filter((s) => s.connected).length;
  check('200 baglantinin tamami kuruldu', okConn === 200, { okConn, ms: Date.now() - t0 });
  const firstConv = (await api('POST', '/conversations', A.token, { title: 'Yuk', memberIds: [B.id, C.id] })).json.id;
  clearMsgLimits();
  const sendAt = Date.now();
  const lat = [];
  const K = 20;
  for (let i = 0; i < K; i++) sessions.A[0].send('/app/chat.send', { conversationId: firstConv, text: 'yuk-' + i, clientId: 'load-' + i });
  const everyone = [...sessions.A, ...sessions.B, ...sessions.C];
  await Promise.all(everyone.map((s) => s.waitFor(() => s.count('messages', (m) => m.clientId && m.clientId.startsWith('load-')) >= K, 15000).then(() => s.count('messages', (m) => m.clientId && m.clientId.startsWith('load-')) >= K && lat.push(Date.now() - sendAt)).catch(() => {})));
  await sleep(1500);
  const counts = everyone.map((s) => s.count('messages', (m) => m.clientId && m.clientId.startsWith('load-')));
  check('200 oturumun her biri tam 20 mesaj aldi (kayip/cift yok)', counts.every((n) => n === K), { min: Math.min(...counts), max: Math.max(...counts) });
  const ordered = everyone.every((s) => { const ids = s.frames.filter((f) => f.command === 'MESSAGE' && f.json && f.json.clientId && f.json.clientId.startsWith('load-')).map((f) => f.json.id); return ids.every((v, i) => i === 0 || v > ids[i - 1]); });
  check('her oturumda sira korunur', ordered);
  lat.sort((x1, y) => x1 - y);
  console.log('  bilgi: son oturumun teslim suresi ~' + (lat[lat.length - 1] || -1) + ' ms, medyan ' + (lat[Math.floor(lat.length / 2)] || -1) + ' ms');
  check('teslim 10 sn icinde', lat.length > 0 && lat[lat.length - 1] < 10000, lat[lat.length - 1]);
  everyone.forEach((s) => s.close());
  await sleep(1500);
  const pr = await api('GET', `/users/${B.id}/presence`, A.token);
  check('tum oturumlar kapaninca cevrimdisi', pr.status === 200 && pr.json.online === false, pr.json);
  check('sunucu hala saglikli', (await fetch(BASE + '/actuator/health')).status === 200);

  if (process.env.SLOW === '1') {
    console.log('== token suresi (SLOW)');
    const soon = await login(forgeJwt(A.id, Math.floor(Date.now() / 1000) + 3));
    clearMsgLimits();
    soon.send('/app/chat.send', { conversationId: ab, text: 'once', clientId: 'ex-1' });
    check('sure dolmadan gonderir', !!(await soon.on('messages', (m) => m.clientId === 'ex-1')));
    await sleep(68000);
    soon.send('/app/chat.send', { conversationId: ab, text: 'sonra', clientId: 'ex-2' });
    const er = await soon.waitFor((f) => f.command === 'ERROR', 4000);
    check('sure + tolerans sonrasi SEND ERROR', !!er);
    const saved = (await api('GET', `/conversations/${ab}/messages?size=5`, A.token)).json.items.some((m) => m.clientId === 'ex-2');
    check('suresi dolan oturum mesaji kaydedilmedi', !saved);
    console.log('== kalp atisi zaman asimi (SLOW)');
    const hb = await Stomp.open(A.token, { heartbeat: '1000,0' });
    const t1 = Date.now();
    await hb.waitFor(() => hb.closed, 45000);
    check('istemci kalp atisi gondermezse sunucu baglantiyi keser', hb.closed, Date.now() - t1);
  }

  summary('WS');
})().catch((err) => { console.error(err); process.exit(2); });
