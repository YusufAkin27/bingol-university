// Senaryo B: OKUMA KARISIMI (mobil ana yollar). Her VU rastgele bir kullanici gibi davranir, istekler arasi 1-3 sn dusunme suresi.
// Ortam: VUS (varsayilan 300), DURATION (5m), WARMUP_S (60), THINK_MIN/THINK_MAX (sn)
import { sleep } from 'k6';
import { get, tokenOf, randomUser, rnd, pick, fx, twoPhase, thresholdsFor, summaryFor, summaryTrendStats } from './lib.js';

const VUS = Number(__ENV.VUS || 300);
const THINK_MIN = Number(__ENV.THINK_MIN || 1);
const THINK_MAX = Number(__ENV.THINK_MAX || 3);
const WORDS = ['universite', 'ogrenci', 'sinav', 'burs', 'yemek', 'kampus', 'kutuphane', 'etkinlik', 'kulup', 'seed'];
const N = {
  summary: 'GET /me/summary', feedTop: 'GET /feed?scope=top', feedMore: 'GET /feed?scope=top (cursor)',
  convs: 'GET /conversations', msgs: 'GET /conversations/{id}/messages', unreadMsgs: 'GET /conversations/unread-count',
  notifs: 'GET /notifications', unreadN: 'GET /notifications/unread-count', events: 'GET /events', cal: 'GET /events/calendar',
  event: 'GET /events/{id}', communities: 'GET /communities', community: 'GET /communities/{id}', news: 'GET /news',
  menu: 'GET /menu/today', search: 'GET /search',
};
const NAMES = Object.values(N);

export const options = {
  scenarios: twoPhase(VUS, __ENV.DURATION || '5m', { exec: 'run' }),
  thresholds: thresholdsFor(NAMES, { default: 400 }),
  summaryTrendStats,
  discardResponseBodies: false,
};

const month = new Date().toISOString().slice(0, 7);
const ACTIONS = [
  [25, home], [15, feed], [20, chat], [10, notifications], [10, events], [7, clubs], [8, news], [5, search],
];
const TOTAL = ACTIONS.reduce((s, a) => s + a[0], 0);

function home(t) {
  get('/api/me/summary', N.summary, t);
  get('/api/feed?scope=top&size=12', N.feedTop, t);
  get('/api/menu/today', N.menu, t);
  get(`/api/news?type=HABER&size=20&page=0`, N.news, t);
}
function feed(t) {
  let r = get('/api/feed?scope=top&size=12', N.feedTop, t);
  for (let i = 0; i < 2; i++) {
    const c = r.status === 200 ? r.json('nextCursor') : null;
    if (!c) break;
    sleep(0.5 + Math.random());
    r = get(`/api/feed?scope=top&size=12&cursor=${encodeURIComponent(c)}`, N.feedMore, t);
  }
}
function chat(t) {
  const r = get('/api/conversations?size=20', N.convs, t);
  get('/api/conversations/unread-count', N.unreadMsgs, t);
  const items = r.status === 200 ? r.json('items') || [] : [];
  if (items.length) {
    sleep(0.5 + Math.random());
    get(`/api/conversations/${pick(items).id}/messages?size=30`, N.msgs, t);
  }
}
function notifications(t) {
  get('/api/notifications?size=20', N.notifs, t);
  get('/api/notifications/unread-count', N.unreadN, t);
}
function events(t) {
  get('/api/events?size=20', N.events, t);
  if (Math.random() < 0.4) get(`/api/events/calendar?month=${month}`, N.cal, t);
  if (Math.random() < 0.5 && fx.eventIds.length) get(`/api/events/${pick(fx.eventIds)}`, N.event, t);
}
function clubs(t) {
  get('/api/communities', N.communities, t);
  if (Math.random() < 0.5 && fx.communityIds.length) get(`/api/communities/${pick(fx.communityIds)}`, N.community, t);
}
function news(t) {
  get(`/api/news?type=${pick(['HABER', 'DUYURU', 'ETKINLIK'])}&size=20&page=${rnd(10)}`, N.news, t);
}
function search(t) {
  get(`/api/search?q=${pick(WORDS)}&limit=5`, N.search, t);
}

export function run() {
  const t = tokenOf(randomUser());
  let x = Math.random() * TOTAL;
  for (const [w, fn] of ACTIONS) {
    x -= w;
    if (x <= 0) { fn(t); break; }
  }
  sleep(THINK_MIN + Math.random() * (THINK_MAX - THINK_MIN));
}

export function handleSummary(data) {
  return summaryFor(__ENV.SCEN_NAME || 'B-read', data);
}
