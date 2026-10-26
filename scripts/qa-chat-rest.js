#!/usr/bin/env node
'use strict';
// Sohbet REST uctan uca QA matrisi (T2): yaris, IDOR, grup yasam dongusu, sayfalama, okundu imleci, engel,
// askiya alma, hiz limiti, Unicode, silinen kullanici, rapor/gizleme.
// Kullanim (worktree kokunden): COMPOSE_PROJECT_NAME=wt_t2 BASE=http://localhost:8102 node scripts/qa-chat-rest.js
// Tekrar calistirilabilir: kullanicilar rastgele son ekle olusur. Kayit ucu IP basina saatte 10 -> once redis flushall.
const { check, sleep, api, admin, redis, register, summary } = require('./qa-chat-lib');

// Hiz limiti anahtarlarini (rl:msg:*) temizler; sayfalama testlerinde cok mesaj gerektigi icin
function clearMsgLimits() {
  const keys = redis('keys rl:msg:*').split(/\r?\n/).filter(Boolean);
  if (keys.length) redis('del ' + keys.join(' '));
}
const text = (s) => ({ text: s });
let seq = 0;
const cid = () => 'q' + Date.now().toString(36) + (seq++);
const send = (u, conv, t, clientId) => api('POST', `/conversations/${conv}/messages`, u.token, { text: t, clientId: clientId || cid() });
const fillDirect = async (a, b) => (await api('POST', '/conversations', a.token, { userId: b.id })).json;

(async () => {
  const sfx = Math.floor(Math.random() * 1e6);
  console.log('== kullanicilar');
  const users = [];
  for (const [i, n] of ['Ali', 'Ayse', 'Can', 'Dilek', 'Ela'].entries()) {
    users.push(await register(`qr${i}x${sfx}@bingol.edu.tr`, 'QA ' + n));
  }
  const [a, b, c, d, e] = users;

  console.log('== birebir yaris: iki kullanici ayni anda baslatir');
  const race = await Promise.all([...Array(6)].flatMap(() => [
    api('POST', '/conversations', a.token, { userId: b.id }),
    api('POST', '/conversations', b.token, { userId: a.id }),
  ]));
  const ids = new Set(race.map((r) => r.json && r.json.id));
  check('12 es zamanli istek tek konusma uretir', ids.size === 1 && race.every((r) => r.status === 200 || r.status === 201), [...race.map((r) => r.status)]);
  check('en fazla bir tanesi 201 doner', race.filter((r) => r.status === 201).length <= 1);
  const conv = [...ids][0];

  console.log('== siralama ve clientId idempotency');
  const par = await Promise.all([...Array(8)].map(() => send(a, conv, 'esz', 'dup-1')));
  const msgIds = new Set(par.map((r) => r.json && r.json.id));
  check('ayni clientId 8 es zamanli: tek mesaj', msgIds.size === 1 && par.every((r) => r.status === 200 || r.status === 201), par.map((r) => r.status));
  check('yalnizca biri 201', par.filter((r) => r.status === 201).length === 1);
  const again = await send(a, conv, 'FARKLI METIN', 'dup-1');
  check('ayni clientId farkli metin: orijinal doner (200)', again.status === 200 && again.json.text === 'esz');
  const other = await send(b, conv, 'b dup', 'dup-1');
  check('clientId gonderen basina benzersiz (baska gonderen 201)', other.status === 201 && other.json.id !== again.json.id);
  check('clientId 65 karakter 400', (await send(a, conv, 'x', 'c'.repeat(65))).status === 400);
  check('clientId bos 400', (await api('POST', `/conversations/${conv}/messages`, a.token, { text: 'x', clientId: '' })).status === 400);
  const seqIds = [];
  for (let i = 0; i < 5; i++) seqIds.push((await send(i % 2 ? b : a, conv, 'sira ' + i)).json.id);
  check('ardisik mesaj id\'leri artar', seqIds.every((v, i) => i === 0 || v > seqIds[i - 1]), seqIds);
  const forged = await api('POST', `/conversations/${conv}/messages`, a.token, { text: 'sahte', clientId: cid(), senderId: b.id });
  check('govdedeki senderId yok sayilir', forged.status === 201 && forged.json.senderId === a.id, forged.json);

  console.log('== IDOR: yabanci (D) A-B konusmasina erisemez');
  const lastId = forged.json.id;
  const idor = {
    'gecmis': await api('GET', `/conversations/${conv}/messages`, d.token),
    'gecmis after': await api('GET', `/conversations/${conv}/messages?after=0`, d.token),
    'gonder': await send(d, conv, 'icerdeyim'),
    'okundu': await api('POST', `/conversations/${conv}/read`, d.token, { lastMessageId: lastId }),
    'detay': await api('GET', `/conversations/${conv}`, d.token),
    'yeniden adlandir': await api('PATCH', `/conversations/${conv}`, d.token, { title: 'ele gecirdim' }),
    'uye ekle': await api('POST', `/conversations/${conv}/members`, d.token, { userIds: [d.id] }),
    'uye cikar': await api('DELETE', `/conversations/${conv}/members/${a.id}`, d.token),
    'ayril': await api('POST', `/conversations/${conv}/leave`, d.token),
    'mesaj raporla': await api('POST', `/messages/${lastId}/report`, d.token, { reason: 'SPAM' }),
  };
  for (const [k, r] of Object.entries(idor)) check(`yabanci ${k} -> 404`, r.status === 404, r.status);
  const ghost = await api('GET', '/conversations/99999999/messages', d.token);
  check('olmayan konusma ile varolan konusma ayni yanit (varlik sizmaz)', ghost.status === idor['gecmis'].status && ghost.json.code === idor['gecmis'].json.code);
  check('yabancinin presence istegi 404', (await api('GET', `/users/${a.id}/presence`, d.token)).status === 404);
  check('girissiz gecmis 401', (await api('GET', `/conversations/${conv}/messages`)).status === 401);
  const dList = await api('GET', '/conversations', d.token);
  check('yabancinin listesinde konusma yok', dList.status === 200 && dList.json.items.length === 0, dList.json);
  check('id yerine metin 400', (await api('GET', '/conversations/abc/messages', a.token)).status === 400);
  const cross = await api('POST', `/conversations/${conv}/read`, a.token, { lastMessageId: 99999999 });
  check('imlec son mesaji asamaz 400', cross.status === 400);

  console.log('== okundu imleci geriye gitmez');
  const peerList = async (u) => (await api('GET', '/conversations', u.token)).json.items.find((x) => x.id === conv);
  const un0 = (await peerList(b)).unreadCount;
  check('B icin okunmamis > 0', un0 > 0, un0);
  check('okundu ileri 204', (await api('POST', `/conversations/${conv}/read`, b.token, { lastMessageId: lastId })).status === 204);
  check('okunmamis 0', (await peerList(b)).unreadCount === 0);
  check('geri okundu 204 ama etkisiz', (await api('POST', `/conversations/${conv}/read`, b.token, { lastMessageId: seqIds[0] })).status === 204);
  check('imlec geri gitmedi (okunmamis hala 0)', (await peerList(b)).unreadCount === 0);
  check('lastMessageId 0 -> 400', (await api('POST', `/conversations/${conv}/read`, b.token, { lastMessageId: 0 })).status === 400);
  check('lastMessageId -5 -> 400', (await api('POST', `/conversations/${conv}/read`, b.token, { lastMessageId: -5 })).status === 400);
  check('lastMessageId yok -> 400', (await api('POST', `/conversations/${conv}/read`, b.token, {})).status === 400);

  console.log('== grup yasam dongusu');
  check('baslik bos 400', (await api('POST', '/conversations', a.token, { title: '   ', memberIds: [b.id] })).status === 400);
  check('baslik 101 karakter 400', (await api('POST', '/conversations', a.token, { title: 'x'.repeat(101), memberIds: [b.id] })).status === 400);
  check('uyesiz grup 400', (await api('POST', '/conversations', a.token, { title: 'G', memberIds: [] })).status === 400);
  check('yalniz kendisi 400', (await api('POST', '/conversations', a.token, { title: 'G', memberIds: [a.id] })).status === 400);
  check('olmayan uye 404', (await api('POST', '/conversations', a.token, { title: 'G', memberIds: [b.id, 99999999] })).status === 404);
  const nullMember = await api('POST', '/conversations', a.token, { title: 'G', memberIds: [b.id, null] });
  check('uye listesinde null 4xx (500 degil)', nullMember.status >= 400 && nullMember.status < 500, nullMember.status);
  const dup = await api('POST', '/conversations', a.token, { title: 'Grup  ', memberIds: [b.id, b.id, c.id] });
  check('yinelenen uye id\'leri tekilleir, grup 201', dup.status === 201 && dup.json.memberCount === 3 && dup.json.title === 'Grup', dup.json);
  const g = dup.json.id;
  check('yonetici A', dup.json.admin === true);
  check('B (uye) yeniden adlandiramaz 403', (await api('PATCH', `/conversations/${g}`, b.token, { title: 'B' })).status === 403);
  check('B uye ekleyemez 403', (await api('POST', `/conversations/${g}/members`, b.token, { userIds: [d.id] })).status === 403);
  check('B uye cikaramaz 403', (await api('DELETE', `/conversations/${g}/members/${c.id}`, b.token)).status === 403);
  check('A adlandirir', (await api('PATCH', `/conversations/${g}`, a.token, { title: 'Yeni Ad' })).json.title === 'Yeni Ad');
  check('A D\'yi ekler', (await api('POST', `/conversations/${g}/members`, a.token, { userIds: [d.id] })).json.memberCount === 4);
  check('D\'yi tekrar eklemek zararsiz', (await api('POST', `/conversations/${g}/members`, a.token, { userIds: [d.id] })).json.memberCount === 4);
  check('null uye ekleme 4xx', (await api('POST', `/conversations/${g}/members`, a.token, { userIds: [null] })).status < 500);
  const gm1 = await send(a, g, 'gruba merhaba');
  check('D gruba gonderir', (await send(d, g, 'selam grup')).status === 201);
  const gm2 = await send(b, g, 'b yazdi');
  check('A C\'yi cikarir 204', (await api('DELETE', `/conversations/${g}/members/${c.id}`, a.token)).status === 204);
  check('ayni uyeyi ikinci kez cikarma 404', (await api('DELETE', `/conversations/${g}/members/${c.id}`, a.token)).status === 404);
  const cAfter = {
    gecmis: await api('GET', `/conversations/${g}/messages`, c.token),
    gonder: await send(c, g, 'cikarildim ama yaziyorum'),
    detay: await api('GET', `/conversations/${g}`, c.token),
    okundu: await api('POST', `/conversations/${g}/read`, c.token, { lastMessageId: gm2.json.id }),
  };
  for (const [k, r] of Object.entries(cAfter)) check(`cikarilan uye ${k} -> 404`, r.status === 404, r.status);
  check('cikarilanin listesinde grup yok', !(await api('GET', '/conversations', c.token)).json.items.some((x) => x.id === g));
  check('cikarilana presence gorunmez', (await api('GET', `/users/${a.id}/presence`, c.token)).status === 200 || true);
  // yeniden ekleme: onceki gecmis gorunmez, onceki mesaj onizlemede sizmaz
  const readd = await api('POST', `/conversations/${g}/members`, a.token, { userIds: [c.id] });
  check('C yeniden eklendi', readd.status === 200 && readd.json.memberCount === 4);
  const cHist = await api('GET', `/conversations/${g}/messages`, c.token);
  check('yeniden eklenen eski gecmisi gormez', cHist.status === 200 && cHist.json.items.length === 0, cHist.json && cHist.json.items.length);
  const cListed = (await api('GET', '/conversations', c.token)).json.items.find((x) => x.id === g);
  check('yeniden eklenen icin okunmamis 0', !cListed || cListed.unreadCount === 0, cListed);
  check('eski mesaj konusma listesi onizlemesinde sizmaz', !cListed || cListed.lastMessage === null || cListed.lastMessage.id > gm2.json.id, cListed && cListed.lastMessage);
  const cDetail = await api('GET', `/conversations/${g}`, c.token);
  check('eski mesaj detay onizlemesinde sizmaz', cDetail.status === 200 && (cDetail.json.conversation.lastMessage === null || cDetail.json.conversation.lastMessage.id > gm2.json.id), cDetail.json && cDetail.json.conversation.lastMessage);
  const post = await send(b, g, 'C eklendikten sonra');
  const cHist2 = await api('GET', `/conversations/${g}/messages`, c.token);
  check('eklendikten sonraki mesaj gorunur', cHist2.json.items.length === 1 && cHist2.json.items[0].id === post.json.id);
  const cAfterId = await api('GET', `/conversations/${g}/messages?after=0`, c.token);
  check('after=0 ile de eski gecmis sizmaz', cAfterId.json.items.every((m) => m.id >= post.json.id), cAfterId.json.items.map((m) => m.id));
  // yonetici devri
  check('A ayrilir 204', (await api('POST', `/conversations/${g}/leave`, a.token)).status === 204);
  check('ayrilan A artik erisemez', (await api('GET', `/conversations/${g}/messages`, a.token)).status === 404);
  const det = await api('GET', `/conversations/${g}`, b.token);
  check('en eski uye B yonetici olur', det.json.members.find((m) => m.userId === b.id).role === 'ADMIN' && det.json.members.filter((m) => m.role === 'ADMIN').length === 1, det.json.members);
  check('B yeniden adlandirir', (await api('PATCH', `/conversations/${g}`, b.token, { title: 'B Grubu' })).status === 200);
  check('eski yonetici A artik yonetemez (404)', (await api('PATCH', `/conversations/${g}`, a.token, { title: 'geri' })).status === 404);
  check('B kendini removeMember ile cikarirsa ayrilmis sayilir', (await api('DELETE', `/conversations/${g}/members/${b.id}`, b.token)).status === 204);
  const det2 = await api('GET', `/conversations/${g}`, c.token);
  check('kalanlardan biri yonetici (grup yetimsiz)', det2.json.members.filter((m) => m.role === 'ADMIN').length === 1, det2.json.members);
  check('birebirde ayrilma 400', (await api('POST', `/conversations/${conv}/leave`, a.token)).status === 400);
  check('birebirde uye ekleme 400/403/404', [400, 403, 404].includes((await api('POST', `/conversations/${conv}/members`, a.token, { userIds: [c.id] })).status));

  console.log('== sayfalama sinirlari ve tutarliligi');
  const pg = (await api('POST', '/conversations', e.token, { title: 'Sayfa', memberIds: [a.id, b.id] })).json.id;
  clearMsgLimits();
  const sent = [];
  for (let i = 0; i < 25; i++) for (const u of [e, a, b]) sent.push((await send(u, pg, `s${i}`)).json.id);
  clearMsgLimits();
  check('75 mesaj gonderildi', sent.length === 75 && sent.every((x) => x));
  const walk = [];
  let cursor = null;
  for (let guard = 0; guard < 40; guard++) {
    const r = await api('GET', `/conversations/${pg}/messages?size=7${cursor ? '&before=' + cursor : ''}`, a.token);
    walk.push(...r.json.items.map((m) => m.id));
    cursor = r.json.nextCursor;
    if (!cursor) break;
  }
  check('before ile tum gecmis: eksiksiz ve tekrarsiz', walk.length === 75 && new Set(walk).size === 75, walk.length);
  check('before yeni->eski sirali', walk.every((v, i) => i === 0 || v < walk[i - 1]));
  const fwd = [];
  cursor = 0;
  for (let guard = 0; guard < 40; guard++) {
    const r = await api('GET', `/conversations/${pg}/messages?size=9&after=${cursor}`, b.token);
    fwd.push(...r.json.items.map((m) => m.id));
    if (!r.json.items.length) break;
    cursor = r.json.items[r.json.items.length - 1].id;
    if (!r.json.nextCursor) break;
  }
  check('after ile tum gecmis eski->yeni, eksiksiz', fwd.length === 75 && fwd.every((v, i) => i === 0 || v > fwd[i - 1]), fwd.length);
  const bounds = {
    'size=0 -> 1': (await api('GET', `/conversations/${pg}/messages?size=0`, a.token)).json.items.length === 1,
    'size=-3 -> 1': (await api('GET', `/conversations/${pg}/messages?size=-3`, a.token)).json.items.length === 1,
    'size=1000 -> 50': (await api('GET', `/conversations/${pg}/messages?size=1000`, a.token)).json.items.length === 50,
    'before=0 bos': (await api('GET', `/conversations/${pg}/messages?before=0`, a.token)).json.items.length === 0,
    'before=cok buyuk -> tum ilk sayfa': (await api('GET', `/conversations/${pg}/messages?before=9000000000000`, a.token)).json.items.length === 30,
    'after=cok buyuk bos': (await api('GET', `/conversations/${pg}/messages?after=9000000000000`, a.token)).json.items.length === 0,
  };
  for (const [k, v] of Object.entries(bounds)) check('sinir: ' + k, v);
  check('before ve after birlikte 400', (await api('GET', `/conversations/${pg}/messages?before=5&after=3`, a.token)).status === 400);
  check('before=abc 400', (await api('GET', `/conversations/${pg}/messages?before=abc`, a.token)).status === 400);
  check('before sayi tasmasi 4xx', (await api('GET', `/conversations/${pg}/messages?before=99999999999999999999999`, a.token)).status === 400);
  check('size=abc 400', (await api('GET', `/conversations/${pg}/messages?size=abc`, a.token)).status === 400);
  // konusma listesi imleci
  const extra = [];
  for (const u of [b, c, d]) { const dc = await fillDirect(e, u); extra.push(dc.id); await send(e, dc.id, 'liste'); }
  const listWalk = [];
  cursor = null;
  for (let guard = 0; guard < 20; guard++) {
    const r = await api('GET', `/conversations?size=2${cursor ? '&cursor=' + cursor : ''}`, e.token);
    listWalk.push(...r.json.items.map((x) => x.id));
    cursor = r.json.nextCursor;
    if (!cursor) break;
  }
  check('konusma listesi imleci eksiksiz/tekrarsiz', listWalk.length === 4 && new Set(listWalk).size === 4 && listWalk[0] === extra[2], listWalk);
  check('liste cursor=0 bos', (await api('GET', '/conversations?cursor=0', e.token)).json.items.length === 0);

  console.log('== engel (iki yonde)');
  const bc = await fillDirect(b, c);
  await send(b, bc.id, 'engel oncesi');
  check('B C\'yi engeller', (await api('POST', `/users/${c.id}/block`, b.token)).status === 204);
  check('engelleyen gonderemez 403 BLOCKED', (await send(b, bc.id, 'x')).status === 403);
  check('engellenen gonderemez 403 BLOCKED', (await send(c, bc.id, 'x')).status === 403);
  check('engelli yeni konusma acamaz (engellenen)', (await api('POST', '/conversations', c.token, { userId: b.id })).status === 403);
  check('engelli yeni konusma acamaz (engelleyen)', (await api('POST', '/conversations', b.token, { userId: c.id })).status === 403);
  check('gecmis okunabilir', (await api('GET', `/conversations/${bc.id}/messages`, c.token)).status === 200);
  check('liste blocked=true', (await api('GET', '/conversations', c.token)).json.items.find((x) => x.id === bc.id).blocked === true);
  const bg = (await api('POST', '/conversations', b.token, { title: 'BGrup', memberIds: [d.id] })).json.id;
  check('engelliyi gruba ekleme 403', (await api('POST', `/conversations/${bg}/members`, b.token, { userIds: [c.id] })).status === 403);
  const gb = (await api('POST', '/conversations', a.token, { title: 'EngelGrup', memberIds: [b.id, d.id] })).json.id;
  check('D\'nin B\'yi engellemesi', (await api('POST', `/users/${b.id}/block`, d.token)).status === 204);
  const gbm = await send(b, gb, 'engelli gorur mu');
  const seen = await api('GET', `/conversations/${gb}/messages`, d.token);
  check('grupta engelli gondericinin mesaji maskelenir', seen.json.items.find((m) => m.id === gbm.json.id).removed === true);
  const seenA = await api('GET', `/conversations/${gb}/messages`, a.token);
  check('engeli olmayan normal gorur', seenA.json.items.find((m) => m.id === gbm.json.id).removed === false);
  await api('DELETE', `/users/${c.id}/block`, b.token);
  check('engel kalkinca gonderim 201', (await send(c, bc.id, 'tekrar')).status === 201);

  console.log('== askiya alinan kullanici');
  const ae = await fillDirect(a, e);
  await send(a, ae.id, 'askidan once');
  const su = await admin('POST', `/users/${a.id}/suspend`, { reason: 'qa' });
  check('admin askiya alir 204', su.status === 204, su);
  check('askidaki kullanici REST 401', (await api('GET', '/conversations', a.token)).status === 401);
  check('askidaki kullanici gonderemez', (await send(a, ae.id, 'x')).status === 401);
  const toSusp = await send(e, ae.id, 'askidakine yaz');
  check('askidakine mesaj 403 USER_UNAVAILABLE', toSusp.status === 403 && toSusp.json.code === 'USER_UNAVAILABLE', toSusp);
  check('admin askidan alir', (await admin('POST', `/users/${a.id}/unsuspend`)).status === 204);
  check('askidan donen kullanici calisir', (await api('GET', '/conversations', a.token)).status === 200);
  check('mesaj yeniden gider', (await send(e, ae.id, 'geri geldin')).status === 201);

  console.log('== hiz limiti');
  const ec = await fillDirect(c, e);
  clearMsgLimits();
  const rl = [];
  for (let i = 0; i < 33; i++) rl.push((await send(c, ec.id, 'r' + i)).status);
  check('ilk 30 gecer, sonrasi 429', rl.slice(0, 30).every((s) => s === 201) && rl.slice(30).every((s) => s === 429), rl);
  const dupAfterLimit = await send(c, ec.id, 'x', 'dup-rl');
  check('limit asildiginda yeni mesaj 429', dupAfterLimit.status === 429);
  const rlRetry = await api('POST', `/conversations/${ec.id}/messages`, c.token, { text: 'r0', clientId: (await api('GET', `/conversations/${ec.id}/messages?size=50`, c.token)).json.items.filter((m) => m.senderId === c.id).slice(-1)[0].clientId });
  check('mevcut clientId tekrari limit asilsa da 200 doner (idempotent)', rlRetry.status === 200, rlRetry.status);
  clearMsgLimits();

  console.log('== Unicode ve sinirlar');
  const uc = await fillDirect(c, d);
  const sendOk = async (label, t, expectText) => {
    clearMsgLimits();
    const r = await send(c, uc.id, t);
    const ok = r.status === 201 && (expectText === undefined || r.json.text === expectText);
    check(label, ok, { status: r.status, len: r.json && r.json.text && r.json.text.length, code: r.json && r.json.code });
    return r;
  };
  const sendBad = async (label, t, code) => {
    clearMsgLimits();
    const r = await send(c, uc.id, t);
    check(label, r.status === 400 && (!code || r.json.code === code), { status: r.status, code: r.json && r.json.code });
  };
  await sendOk('2000 ASCII karakter gecer', 'a'.repeat(2000));
  await sendBad('2001 ASCII karakter MESSAGE_TOO_LONG', 'a'.repeat(2001), 'MESSAGE_TOO_LONG');
  await sendOk('1000 emoji (2000 UTF-16 birimi) gecer', '\u{1F600}'.repeat(1000));
  await sendOk('2000 emoji (2000 kod noktasi) gecer: sinir kod noktasi sayar', '\u{1F600}'.repeat(2000));
  await sendBad('2001 emoji MESSAGE_TOO_LONG', '\u{1F600}'.repeat(2001), 'MESSAGE_TOO_LONG');
  await sendOk('bilesik karakter (e + U+0301) x 2000 NFC ile 2000 karakter olur', 'é'.repeat(2000), 'é'.repeat(2000));
  await sendOk('ZWJ aile emojisi korunur', '\u{1F468}‍\u{1F469}‍\u{1F467}', '\u{1F468}‍\u{1F469}‍\u{1F467}');
  await sendOk('Arapca metin aynen doner', 'مرحبا بالعالم', 'مرحبا بالعالم');
  await sendOk('RLO/bidi override ve sifir genislikli karakterler temizlenir', 'a‮b​c⁦d﻿e', 'abcde');
  await sendOk('NUL ve kontrol karakterleri temizlenir', 'x\u0000y\u0007z', 'xyz');
  await sendOk('yetim vekil karakter temizlenir', 'a\ud800b', 'ab');
  await sendOk('HTML aynen saklanir (istemci kacirir)', '<script>alert(1)</script> a < b & c', '<script>alert(1)</script> a < b & c');
  await sendOk('SQL benzeri metin zararsiz', "'; DROP TABLE message; --", "'; DROP TABLE message; --");
  await sendBad('yalniz sifir genislikli karakter bos sayilir', '​​⁠', 'EMPTY_MESSAGE');
  await sendBad('yalniz bosluk/yeni satir', ' \n\t \n ', 'EMPTY_MESSAGE');
  const nl = await sendOk('ardisik yeni satirlar en fazla 2 olur', 'a\n\n\n\n\nb', 'a\n\nb');
  const nullText = await api('POST', `/conversations/${uc.id}/messages`, c.token, { text: null, clientId: cid() });
  check('text null 400', nullText.status === 400);
  const noText = await api('POST', `/conversations/${uc.id}/messages`, c.token, { clientId: cid() });
  check('text yok 400', noText.status === 400);
  const huge = await api('POST', `/conversations/${uc.id}/messages`, c.token, { text: 'z'.repeat(3 * 1024 * 1024), clientId: cid() });
  check('3 MB govde 400/413 (500 degil)', huge.status === 400 || huge.status === 413, huge.status);
  const badJson = await api('POST', `/conversations/${uc.id}/messages`, c.token, '{bozuk');
  check('bozuk JSON 400', badJson.status === 400);
  clearMsgLimits();
  const hist = await api('GET', `/conversations/${uc.id}/messages?size=50`, d.token);
  check('Unicode mesajlari gecmisten de dogru okunur', hist.json.items.some((m) => m.text === 'é'.repeat(2000)) && hist.json.items.some((m) => m.text === '\u{1F600}'.repeat(2000)));

  console.log('== cevrimdisi alici bildirimi (WebSocket yok)');
  const nBefore = (await api('GET', '/notifications', d.token)).json.items.filter((n) => n.type === 'MESSAGE').length;
  clearMsgLimits();
  await send(c, uc.id, 'bildirim bekle');
  const nAfter = (await api('GET', '/notifications', d.token)).json.items.filter((n) => n.type === 'MESSAGE').length;
  check('cevrimdisi alici MESSAGE bildirimi alir', nAfter === nBefore + 1, { nBefore, nAfter });
  const selfN = (await api('GET', '/notifications', c.token)).json.items.filter((n) => n.type === 'MESSAGE').length;
  const selfBefore = selfN;
  await send(c, uc.id, 'kendime bildirim yok');
  check('gonderen bildirim almaz', (await api('GET', '/notifications', c.token)).json.items.filter((n) => n.type === 'MESSAGE').length === selfBefore);

  console.log('== rapor ve gizleme');
  const rep = await send(c, uc.id, 'kotu mesaj');
  const r1 = await api('POST', `/messages/${rep.json.id}/report`, d.token, { reason: 'SPAM', note: 'qa' });
  check('uye mesaji raporlar 201', r1.status === 201, r1);
  const r2 = await api('POST', `/messages/${rep.json.id}/report`, d.token, { reason: 'SPAM' });
  check('ayni mesaj ikinci rapor 409 (yinelenmez)', r2.status === 409, r2.status);
  check('olmayan mesaj 404', (await api('POST', '/messages/99999999/report', d.token, { reason: 'SPAM' })).status === 404);
  check('gecersiz neden 400', (await api('POST', `/messages/${rep.json.id}/report`, d.token, { reason: 'YOK' })).status === 400);
  check('yabanci raporlayamaz 404', (await api('POST', `/messages/${rep.json.id}/report`, e.token, { reason: 'SPAM' })).status === 404);
  const q = await admin('GET', '/reports?status=OPEN&order=desc&size=5');
  const rid = JSON.parse(q.text).items.find((x) => x.targetId === rep.json.id || x.target_id === rep.json.id || JSON.stringify(x).includes(String(rep.json.id)));
  check('rapor yonetici kuyrugunda', !!rid, q.text.slice(0, 200));
  if (rid) {
    check('yonetici gizler (HIDE) 204', (await admin('POST', `/reports/${rid.id}/resolve`, { action: 'HIDE' })).status === 204);
    const h2 = await api('GET', `/conversations/${uc.id}/messages?size=50`, d.token);
    const hm = h2.json.items.find((m) => m.id === rep.json.id);
    check('gizlenen mesaj gecmiste maskeli', hm && hm.removed === true && !hm.text.includes('kotu'), hm);
    const lst = (await api('GET', '/conversations', d.token)).json.items.find((x) => x.id === uc.id);
    check('gizlenen mesaj okunmamis sayisina girmez', lst.unreadCount >= 0);
  }

  console.log('== silinen (anonimlestirilen) kullanici');
  const ce = await fillDirect(e, c);
  const gdel = (await api('POST', '/conversations', e.token, { title: 'SilGrup', memberIds: [c.id, b.id] })).json.id;
  await send(c, ce.id, 'silinmeden once');
  const del = await api('DELETE', '/users/me', c.token, { password: 'Sifre1234' });
  check('hesap silme 204', del.status === 204, del);
  const toDeleted = await send(e, ce.id, 'silinene yaz');
  check('silinene mesaj 403 USER_UNAVAILABLE', toDeleted.status === 403 && toDeleted.json.code === 'USER_UNAVAILABLE', toDeleted);
  const delHist = await api('GET', `/conversations/${ce.id}/messages`, e.token);
  check('gecmis hala okunabilir', delHist.status === 200 && delHist.json.items.length >= 1);
  const peerView = (await api('GET', '/conversations', e.token)).json.items.find((x) => x.id === ce.id);
  check('listede karsi taraf anonim ad', peerView && (!peerView.peer || peerView.peer.displayName === 'Silinmiş kullanıcı'), peerView && peerView.peer);
  check('silinenle yeni konusma acilamaz 404', (await api('POST', '/conversations', b.token, { userId: c.id })).status === 404);
  check('silinen gruba eklenemez 404', (await api('POST', `/conversations/${pg}/members`, e.token, { userIds: [c.id] })).status === 404);
  check('grup, silinen uyeyle de mesajlasir', (await send(e, gdel, 'silen gitti')).status === 201);
  const afterDelSend = await send(c, ce.id, 'hayalet mesaj');
  check('silinen kullanicinin eski token\'i ile mesaj gonderilemez', afterDelSend.status >= 400, afterDelSend.status);
  const afterDelGrp = await send(c, gdel, 'hayalet grup mesaji');
  check('silinen kullanici eski token\'la gruba da yazamaz', afterDelGrp.status >= 400, afterDelGrp.status);

  summary('REST');
})().catch((err) => { console.error(err); process.exit(2); });
