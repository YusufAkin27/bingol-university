// Senaryo D: WEBSOCKET/STOMP. VUS esli baglanti (cift sayida): her cift ayni birebir sohbetin iki ucu. Cift'in bir ucu
// SEND_EVERY_S saniyede bir '/app/chat.send' ile mesaj yollar (metne gonderim zamani gomulur), diger ucu '/user/queue/messages'
// uzerinden alir -> teslim gecikmesi (ayni k6 sureci saati: sunucu + Redis pub/sub + yazma dahil). Gonderen kendi mesajinin
// geri dusmesini 'ack' olarak olcer. Baglanti kurulum suresi, hata/kopma sayisi ve presence (REST) denetlenir.
// Ortam: VUS (1000), HOLD_S (90), SEND_EVERY_S (10; sunucu limiti 30/dk), RAMP_S (30)
import ws from 'k6/ws';
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';
import { BASE, pairs, tokenOf, headers, ipOf, OUT, summaryTrendStats, noWarmup } from './lib.js';

noWarmup();
const VUS = Number(__ENV.VUS || 1000);
const HOLD_S = Number(__ENV.HOLD_S || 90);
const SEND_S = Number(__ENV.SEND_EVERY_S || 10);
const RAMP_S = Number(__ENV.RAMP_S || 30);
const WS_URL = (__ENV.WS_URL || BASE.replace(/^http/, 'ws')) + '/ws';

const deliver = new Trend('ws_deliver_ms', true);
const ackT = new Trend('ws_ack_ms', true);
const connT = new Trend('ws_connect_ms', true);
const sent = new Counter('ws_sent');
const got = new Counter('ws_delivered');
const acks = new Counter('ws_acks');
const connFail = new Counter('ws_conn_fail');
const errors = new Counter('ws_errors');
const closedEarly = new Counter('ws_closed_early');

export const options = {
  scenarios: {
    ws: { executor: 'per-vu-iterations', vus: VUS, iterations: 1, maxDuration: `${RAMP_S + HOLD_S + 90}s` },
  },
  thresholds: { ws_deliver_ms: ['p(95)<250', 'p(99)<500'], ws_conn_fail: ['count<5'], ws_connect_ms: ['p(95)<2000'] },
  summaryTrendStats,
};

const frame = (cmd, h, body) => `${cmd}\n${Object.entries(h).map(([k, v]) => `${k}:${v}`).join('\n')}\n\n${body || ''}\0`;

export default function () {
  sleep(Math.random() * RAMP_S); // baglanti dalgasini yay (kampuste herkes ayni milisaniyede baglanmaz)
  const idx = __VU - 1;
  const pair = pairs[Math.floor(idx / 2) % pairs.length];
  const isSender = idx % 2 === 0;
  const me = isSender ? pair[1] : pair[2];
  const conv = pair[0];
  const token = tokenOf(me);
  const t0 = Date.now();
  let connected = false;
  const res = ws.connect(WS_URL, { headers: { 'X-Forwarded-For': ipOf(__VU) }, tags: { name: 'WS /ws' } }, (socket) => {
    socket.on('open', () => socket.send(frame('CONNECT', { 'accept-version': '1.2', host: 'localhost', 'heart-beat': '0,0', Authorization: `Bearer ${token}` })));
    socket.on('message', (data) => {
      const now = Date.now();
      for (const part of String(data).split('\0')) {
        const p = part.replace(/^\n+/, '');
        if (!p) continue;
        if (p.startsWith('CONNECTED') && !connected) {
          connected = true;
          connT.add(now - t0);
          socket.send(frame('SUBSCRIBE', { id: 'm', destination: '/user/queue/messages' }));
          socket.send(frame('SUBSCRIBE', { id: 'e', destination: '/user/queue/errors' }));
          if (isSender) {
            socket.setInterval(() => {
              const ts = Date.now();
              socket.send(frame('SEND', { destination: '/app/chat.send', 'content-type': 'application/json' },
                JSON.stringify({ conversationId: conv, text: `wsload ${ts}`, clientId: `ws-${__VU}-${ts}` })));
              sent.add(1);
            }, SEND_S * 1000 + Math.floor(Math.random() * 1000));
          }
        } else if (p.startsWith('MESSAGE')) {
          const i = p.indexOf('\n\n');
          const body = i < 0 ? '' : p.slice(i + 2);
          if (p.indexOf('/user/queue/errors') >= 0) { errors.add(1); continue; }
          const m = /wsload (\d+)/.exec(body);
          if (!m) continue;
          const lat = now - Number(m[1]);
          if (body.indexOf(`"senderId":${me}`) >= 0) { acks.add(1); ackT.add(lat); } else { got.add(1); deliver.add(lat); }
        } else if (p.startsWith('ERROR')) {
          errors.add(1);
        }
      }
    });
    socket.on('error', () => { if (!connected) connFail.add(1); });
    socket.on('close', () => { if (connected && Date.now() - t0 < (HOLD_S - 2) * 1000) closedEarly.add(1); });
    socket.setTimeout(() => {
      if (isSender) { // presence: karsi ucun cevrimici gorundugunu REST ile dogrula
        const peer = pair[2];
        const r = http.get(`${BASE}/api/users/${peer}/presence`, { headers: headers(token), tags: { name: 'GET /users/{id}/presence' } });
        check(r, { 'presence 200': (x) => x.status === 200 });
      }
      socket.close();
    }, HOLD_S * 1000);
  });
  if (!res || res.status !== 101) connFail.add(1);
}

export function handleSummary(data) {
  const v = (m, k) => (data.metrics[m] && data.metrics[m].values ? data.metrics[m].values[k] : null);
  const out = {
    scenario: 'D-ws', at: new Date().toISOString(), vus: VUS, holdSeconds: HOLD_S, sendEverySeconds: SEND_S,
    connect: { p50: v('ws_connect_ms', 'med'), p95: v('ws_connect_ms', 'p(95)'), max: v('ws_connect_ms', 'max'), fail: v('ws_conn_fail', 'count') },
    deliver: { p50: v('ws_deliver_ms', 'med'), p95: v('ws_deliver_ms', 'p(95)'), p99: v('ws_deliver_ms', 'p(99)'), max: v('ws_deliver_ms', 'max') },
    ack: { p50: v('ws_ack_ms', 'med'), p95: v('ws_ack_ms', 'p(95)'), p99: v('ws_ack_ms', 'p(99)') },
    sent: v('ws_sent', 'count'), delivered: v('ws_delivered', 'count'), acks: v('ws_acks', 'count'), errors: v('ws_errors', 'count'),
    closedEarly: v('ws_closed_early', 'count'),
    presence: data.metrics['http_req_duration{name:GET /users/{id}/presence}'] ? { p95: data.metrics['http_req_duration{name:GET /users/{id}/presence}'].values['p(95)'] } : null,
  };
  const txt = `\n== D-ws == vu=${VUS} baglanti basarisiz=${out.connect.fail} erken kopma=${out.closedEarly} hata=${out.errors}\n` +
    `baglanti ms p50=${out.connect.p50} p95=${out.connect.p95} max=${out.connect.max}\n` +
    `gonderilen=${out.sent} teslim=${out.delivered} ack=${out.acks}\n` +
    `teslim ms p50=${out.deliver.p50} p95=${out.deliver.p95} p99=${out.deliver.p99} max=${out.deliver.max}\n`;
  return { [`${OUT}/D-ws.json`]: JSON.stringify(out, null, 2), stdout: txt };
}
