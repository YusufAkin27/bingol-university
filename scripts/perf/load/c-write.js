// Senaryo C1: YAZMA KARISIMI (mesaj REST + clientId, begeni, takip, etkinlik RSVP). Her VU rastgele bir kullanici olarak
// yazar; dusunme suresi 0.5-2 sn. Dakika-basi kullanici limitleri (mesaj 30/dk, RSVP 30/dk) 20k havuzdan dagitildigi icin
// normalde tetiklenmez; tetiklenenler 429 olarak ayri sayilir. Bitince run-load.sh veri butunlugunu SQL ile denetler.
// Ortam: VUS (150), DURATION (5m), WARMUP_S (60)
import { sleep } from 'k6';
import { call, tokenOf, randomUser, rnd, pick, uuid, fx, pairs, userIds, twoPhase, thresholdsFor, summaryFor, summaryTrendStats } from './lib.js';

const VUS = Number(__ENV.VUS || 150);
const N = { msg: 'POST /conversations/{id}/messages', like: 'PUT /posts/{id}/like', unlike: 'DELETE /posts/{id}/like',
  follow: 'POST /users/{id}/follow', unfollow: 'DELETE /users/{id}/follow', rsvp: 'PUT /events/{id}/rsvp' };

export const options = {
  scenarios: twoPhase(VUS, __ENV.DURATION || '5m', { exec: 'run' }),
  thresholds: thresholdsFor(Object.values(N), { default: 800 }),
  summaryTrendStats,
};

const [P0, P1] = fx.postRange;

export function run() {
  const x = Math.random();
  if (x < 0.40) { // mesaj (en sicak yazma yolu)
    const [conv, a, b] = pick(pairs);
    const who = Math.random() < 0.5 ? a : b;
    call('POST', `/api/conversations/${conv}/messages`, N.msg, tokenOf(who), { text: `yuk testi ${uuid()}`, clientId: uuid() }, [201, 200]);
  } else if (x < 0.65) { // begeni
    const t = tokenOf(randomUser());
    const post = P0 + rnd(P1 - P0 + 1);
    call('PUT', `/api/posts/${post}/like`, N.like, t, null);
    if (Math.random() < 0.3) call('DELETE', `/api/posts/${post}/like`, N.unlike, t, null);
  } else if (x < 0.80) { // takip
    const u = randomUser();
    const target = userIds[rnd(userIds.length)];
    if (userIds[u] !== target) {
      call('POST', `/api/users/${target}/follow`, N.follow, tokenOf(u), null, [409]);
      if (Math.random() < 0.3) call('DELETE', `/api/users/${target}/follow`, N.unfollow, tokenOf(u), null, [404]);
    }
  } else { // etkinlik katilimi (kapasitesiz etkinlikler)
    call('PUT', `/api/events/${pick(fx.eventIds)}/rsvp`, N.rsvp, tokenOf(randomUser()), { status: 'GOING' }, [409]);
  }
  sleep(0.5 + Math.random() * 1.5);
}

export function handleSummary(data) {
  return summaryFor(__ENV.SCEN_NAME || 'C1-write', data);
}
