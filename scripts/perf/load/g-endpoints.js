// Senaryo G: UC BASINA KAPASITE. Her ana yol sirayla EP_S saniye (varsayilan 15) boyunca VUS (32) eszamanli, dusunme suresiz
// (kapali dongu) calistirilir: saniyedeki istek (RPS) ve gecikme uc basina ayri okunur -> "bu yol tek basina kac RPS tasir",
// en pahali yollar (istek basina CPU/sorgu) buradan bulunur. Sonuc /out/G-endpoints.json
// Ortam: VUS (32), EP_S (15)
import { get, tokenOf, randomUser, rnd, pick, fx, thresholdsFor, summaryFor, summaryTrendStats, noWarmup } from './lib.js';

noWarmup();
const VUS = Number(__ENV.VUS || 32);
const EP_S = Number(__ENV.EP_S || 15);
const month = new Date().toISOString().slice(0, 7);
const EPS = [
  ['menu', () => get('/api/menu/today', 'EP menu/today', tokenOf(randomUser()))],
  ['summary', () => get('/api/me/summary', 'EP me/summary', tokenOf(randomUser()))],
  ['news', () => get(`/api/news?type=HABER&size=20&page=${rnd(10)}`, 'EP news list', tokenOf(randomUser()))],
  ['feedTop', () => get('/api/feed?scope=top&size=12', 'EP feed top', tokenOf(randomUser()))],
  ['convs', () => get('/api/conversations?size=20', 'EP conversations', tokenOf(randomUser()))],
  ['unread', () => get('/api/conversations/unread-count', 'EP conversations/unread-count', tokenOf(randomUser()))],
  ['notifs', () => get('/api/notifications?size=20', 'EP notifications', tokenOf(randomUser()))],
  ['events', () => get('/api/events?size=20', 'EP events', tokenOf(randomUser()))],
  ['calendar', () => get(`/api/events/calendar?month=${month}`, 'EP events/calendar', tokenOf(randomUser()))],
  ['communities', () => get('/api/communities', 'EP communities', tokenOf(randomUser()))],
  ['search', () => get(`/api/search?q=${pick(['universite', 'ogrenci', 'kampus', 'yemek', 'sinav'])}&limit=5`, 'EP search', tokenOf(randomUser()))],
  ['messages', () => {
    const t = tokenOf(randomUser());
    const r = get('/api/conversations?size=5', 'EP (hazirlik) conversations', t);
    const items = r.status === 200 ? r.json('items') || [] : [];
    if (items.length) get(`/api/conversations/${pick(items).id}/messages?size=30`, 'EP conversation messages', t);
  }],
];
const names = EPS.map((e) => e[0]);
const scen = {};
const only = (__ENV.ONLY || '').split(',').filter(Boolean); // ONLY=menu,feedTop ile yalniz bu yollar
EPS.filter((e) => !only.length || only.includes(e[0])).forEach((e, i) => {
  scen[e[0]] = { executor: 'constant-vus', vus: VUS, duration: `${EP_S}s`, startTime: `${i * (EP_S + 3)}s`, exec: 'ep_' + e[0], gracefulStop: '2s', tags: { ep: e[0] } };
});
export const options = { scenarios: scen, thresholds: {}, summaryTrendStats };
export function ep_menu() { EPS[0][1](); }
export function ep_summary() { EPS[1][1](); }
export function ep_news() { EPS[2][1](); }
export function ep_feedTop() { EPS[3][1](); }
export function ep_convs() { EPS[4][1](); }
export function ep_unread() { EPS[5][1](); }
export function ep_notifs() { EPS[6][1](); }
export function ep_events() { EPS[7][1](); }
export function ep_calendar() { EPS[8][1](); }
export function ep_communities() { EPS[9][1](); }
export function ep_search() { EPS[10][1](); }
export function ep_messages() { EPS[11][1](); }

options.thresholds = thresholdsFor(['EP menu/today', 'EP me/summary', 'EP news list', 'EP feed top', 'EP conversations', 'EP conversations/unread-count',
  'EP notifications', 'EP events', 'EP events/calendar', 'EP communities', 'EP search', 'EP conversation messages'], { default: 5000 });

export function handleSummary(data) {
  const o = summaryFor('G-endpoints', data);
  // RPS = istek sayisi / EP_S
  const j = JSON.parse(Object.values(o)[0]);
  for (const r of Object.values(j.endpoints)) r.rps = Math.round((r.n / EP_S) * 10) / 10;
  const key = Object.keys(o).find((k) => k.endsWith('.json'));
  o[key] = JSON.stringify(j, null, 2);
  o.stdout += '\nRPS (VUS=' + VUS + ', ' + EP_S + ' sn):\n' + Object.entries(j.endpoints).map(([n, r]) => n.padEnd(34) + String(r.rps).padStart(8) + ' rps').join('\n') + '\n';
  return o;
}
