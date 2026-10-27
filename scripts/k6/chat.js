// Sohbet senaryosu: REST ile sohbet listesi/gecmis + STOMP/WebSocket ile mesaj gonderme (teslim "ack" suresi olculur).
// k6/experimental/websockets kullanir (k6 >= 0.50). Hesabin en az bir sohbeti olmali (yoksa yalniz REST kismi calisir).
import http from 'k6/http';
import { WebSocket } from 'k6/experimental/websockets';
import { setInterval, setTimeout, clearInterval } from 'k6/experimental/timers';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { BASE_URL, baseThresholds, authHeaders, loginAll, tokenFor, get, rand, uuid, allow429 } from './lib.js';

allow429();

const ackLatency = new Trend('chat_ack_ms', true);
const wsErrors = new Counter('chat_ws_errors');
const sent = new Counter('chat_messages_sent');

const WS_URL = (__ENV.WS_URL || BASE_URL.replace(/^http/, 'ws')) + '/ws';
const SESSION_MS = Number(__ENV.WS_SESSION_SECONDS || 30) * 1000;
const SEND_EVERY_MS = Number(__ENV.SEND_EVERY_MS || 2000);

export const options = {
  scenarios: {
    chatters: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: __ENV.RAMP || '1m', target: Number(__ENV.VUS || 10) },
        { duration: __ENV.HOLD || '3m', target: Number(__ENV.VUS || 10) },
        { duration: '30s', target: 0 },
      ],
    },
  },
  thresholds: {
    ...baseThresholds,
    chat_ack_ms: ['p(95)<800'],
    chat_ws_errors: ['count<5'],
  },
};

export function setup() {
  return { tokens: loginAll() };
}

function frame(command, headers, body) {
  const h = Object.keys(headers).map((k) => `${k}:${headers[k]}`).join('\n');
  return `${command}\n${h}\n\n${body || ''}\0`;
}

export default function (data) {
  const token = tokenFor(data.tokens);

  const list = get('/api/conversations?size=20', token, 'GET /api/conversations');
  check(list, { 'sohbet listesi 200/429': (r) => r.status === 200 || r.status === 429 });
  if (list.status !== 200) {
    sleep(2);
    return;
  }
  const items = list.json('items') || [];
  if (items.length === 0) {
    sleep(2);
    return;
  }
  const conv = items[rand(items.length)];
  check(get(`/api/conversations/${conv.id}/messages?size=30`, token, 'GET /api/conversations/{id}/messages'), {
    'gecmis 200/429': (r) => r.status === 200 || r.status === 429,
  });

  const pending = {};
  const ws = new WebSocket(WS_URL);
  let timer = null;

  ws.onopen = () => {
    ws.send(frame('CONNECT', { 'accept-version': '1.2', 'heart-beat': '0,0', Authorization: `Bearer ${token}` }));
  };

  ws.onmessage = (e) => {
    const text = typeof e.data === 'string' ? e.data : '';
    if (text.startsWith('CONNECTED')) {
      ws.send(frame('SUBSCRIBE', { id: 'sub-0', destination: '/user/queue/messages' }));
      timer = setInterval(() => {
        const clientId = uuid();
        pending[clientId] = Date.now();
        ws.send(frame('SEND', { destination: '/app/chat.send', 'content-type': 'application/json' },
          JSON.stringify({ conversationId: conv.id, text: `k6 ${clientId}`, clientId })));
        sent.add(1);
      }, SEND_EVERY_MS);
    } else if (text.startsWith('MESSAGE')) {
      // Gondericinin kendi mesaji clientId ile geri duser ("ack")
      for (const id of Object.keys(pending)) {
        if (text.indexOf(id) !== -1) {
          ackLatency.add(Date.now() - pending[id]);
          delete pending[id];
        }
      }
    } else if (text.startsWith('ERROR')) {
      wsErrors.add(1);
    }
  };

  ws.onerror = () => wsErrors.add(1);
  ws.onclose = () => {
    if (timer) clearInterval(timer);
  };

  setTimeout(() => ws.close(), SESSION_MS);

  // REST yedek gonderimi de dene (idempotent clientId)
  const res = http.post(`${BASE_URL}/api/conversations/${conv.id}/messages`,
    JSON.stringify({ text: 'k6 rest', clientId: uuid() }), { ...authHeaders(token), tags: { name: 'POST /api/conversations/{id}/messages' } });
  check(res, { 'rest gonderim 2xx/429': (r) => (r.status >= 200 && r.status < 300) || r.status === 429 });
}
