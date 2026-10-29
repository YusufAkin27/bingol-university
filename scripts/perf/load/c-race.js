// Senaryo C2: YARIS DURUMLARI (veri butunlugu). (1) 100 kullanici AYNI ANDA kapasite 100'luk etkinligin son 10 koltugu icin
// katilir: tam 10 basarili olmali, going_count <= capacity. (2) 300 kullanici ayni ankete ayni anda oy verir, 50 kullanici
// ayni anda iki kez oy verir: tek oy kurali (voter_count == ballot sayisi == secenek toplami). Sonuclari run-load.sh SQL ile
// da dogrular; bu betik istemci tarafi sayaclarini /out/C2-race.json'a yazar.
import http from 'k6/http';
import { Counter } from 'k6/metrics';
import { noWarmup, call, tokenOf, fx, BASE, headers, summaryTrendStats, thresholdsFor, summaryFor } from './lib.js';

const raceOk = new Counter('race_event_ok');
const raceFull = new Counter('race_event_full');
const raceOther = new Counter('race_event_other');
const voteOk = new Counter('race_vote_ok');
const voteOther = new Counter('race_vote_other');
noWarmup();
const N = { rsvp: 'PUT /events/{id}/rsvp (yaris)', vote: 'POST /polls/{id}/vote (yaris)', vote2: 'POST /polls/{id}/vote (cift)' };

export const options = {
  scenarios: {
    event: { executor: 'per-vu-iterations', vus: 100, iterations: 1, maxDuration: '1m', exec: 'eventRace', tags: { phase: 'main' } },
    poll: { executor: 'per-vu-iterations', vus: 300, iterations: 1, maxDuration: '1m', exec: 'pollRace', startTime: '10s', tags: { phase: 'main' } },
    pollDouble: { executor: 'per-vu-iterations', vus: 50, iterations: 1, maxDuration: '1m', exec: 'pollDouble', startTime: '20s', tags: { phase: 'main' } },
  },
  thresholds: { ...thresholdsFor(Object.values(N), { default: 3000 }), race_event_ok: ['count>=0'], race_event_full: ['count>=0'], race_vote_ok: ['count>=0'] },
  summaryTrendStats,
};

// raceUserFrom..+99 kapasite kullanicilari; anket kullanicilari 3000..3299; cift oy 4000..4049
export function setup() {
  const pollId = fx.pollIds[0];
  const r = http.get(`${BASE}/api/polls/${pollId}`, { headers: headers(tokenOf(3000)) });
  const opts = (r.json('options') || []).map((o) => o.id);
  return { pollId, opts };
}

export function eventRace() {
  const r = call('PUT', `/api/events/${fx.raceEventId}/rsvp`, N.rsvp, tokenOf(fx.raceUserFrom + __VU - 1), { status: 'GOING' }, [409, 422, 403]);
  if (r.status === 200) raceOk.add(1); else if (r.status === 409 || r.status === 422) raceFull.add(1); else raceOther.add(1);
}

export function pollRace(d) {
  const r = call('POST', `/api/polls/${d.pollId}/vote`, N.vote, tokenOf(3000 + __VU - 1), { optionIds: [d.opts[__VU % d.opts.length]] }, [409]);
  if (r.status === 200) voteOk.add(1); else voteOther.add(1);
}

// Ayni kullanici ayni anda iki oy: ikisinden biri yazar, digeri idempotent/degisiklik; ballot tek kalmali
export function pollDouble(d) {
  const t = tokenOf(4000 + __VU - 1);
  const h = { headers: headers(t), tags: { name: N.vote2, phase: 'main' }, responseCallback: http.expectedStatuses({ min: 200, max: 499 }) };
  const url = `${BASE}/api/polls/${d.pollId}/vote`;
  const res = http.batch([
    ['POST', url, JSON.stringify({ optionIds: [d.opts[0]] }), h],
    ['POST', url, JSON.stringify({ optionIds: [d.opts[1]] }), h],
  ]);
  for (const r of res) { if (r.status === 200) voteOk.add(1); else voteOther.add(1); }
}

export function handleSummary(data) {
  const v = (m) => (data.metrics[m] && data.metrics[m].values ? data.metrics[m].values.count : 0);
  const extra = { eventOk: v('race_event_ok'), eventFull: v('race_event_full'), eventOther: v('race_event_other'), voteOk: v('race_vote_ok'), voteOther: v('race_vote_other') };
  const o = summaryFor('C2-race', data, extra);
  o.stdout += JSON.stringify(extra) + '\n';
  return o;
}
