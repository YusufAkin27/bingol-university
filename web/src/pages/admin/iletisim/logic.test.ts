import { describe, expect, it } from 'vitest';
import {
  AGE_KEYS,
  ageBuckets,
  ageKeyOf,
  ageMinutes,
  answeredShare,
  campaignTone,
  countsByKey,
  deliveryRate,
  firstReplyVerdict,
  humanizeDuration,
  mailShareSegments,
  queueHealth,
  queueProblems,
  reachRate,
  staleCount,
  statusCounts,
  ticketTotal,
} from './logic';

const NOW = Date.parse('2026-11-01T12:00:00Z');
const ago = (ms: number) => new Date(NOW - ms).toISOString();
const H = 3_600_000;
const D = 24 * H;

describe('talep yaşı', () => {
  it('kova sınırları: 4 saat, 1 gün, 3 gün', () => {
    expect(ageKeyOf(ago(10 * 60_000), NOW)).toBe('lt4h');
    expect(ageKeyOf(ago(4 * H), NOW)).toBe('lt24h');
    expect(ageKeyOf(ago(23 * H), NOW)).toBe('lt24h');
    expect(ageKeyOf(ago(D), NOW)).toBe('lt3d');
    expect(ageKeyOf(ago(3 * D - 1), NOW)).toBe('lt3d');
    expect(ageKeyOf(ago(3 * D), NOW)).toBe('gt3d');
  });
  it('geçersiz ya da gelecek tarih en yeni kovaya düşer, hata atmaz', () => {
    expect(ageKeyOf('bozuk', NOW)).toBe('lt4h');
    expect(ageKeyOf(new Date(NOW + D).toISOString(), NOW)).toBe('lt4h');
  });
  it('dağılım her kovayı sabit sırada döner (boş olanlar 0)', () => {
    const b = ageBuckets([{ updatedAt: ago(H) }, { updatedAt: ago(5 * D) }, { updatedAt: ago(6 * D) }], NOW);
    expect(b.map((x) => x.key)).toEqual(AGE_KEYS);
    expect(b.map((x) => x.count)).toEqual([1, 0, 0, 2]);
    expect(staleCount(b)).toBe(2);
    expect(ageBuckets([], NOW).every((x) => x.count === 0)).toBe(true);
  });
});

describe('talep sayıları', () => {
  it('yanıtlanma oranı: yanıtlanan + kapanan / toplam; talep yoksa null', () => {
    expect(answeredShare({ open: 1, answered: 1, closed: 2 })).toBe(75);
    expect(answeredShare({ open: 0, answered: 0, closed: 0 })).toBeNull();
    expect(ticketTotal({ open: 2, answered: 3, closed: 5 })).toBe(10);
  });
  it('ilk yanıt kararı: 1 gün iyi, 3 gün dikkat, üstü kötü, veri yok none', () => {
    expect(firstReplyVerdict(null)).toBe('none');
    expect(firstReplyVerdict(0)).toBe('none');
    expect(firstReplyVerdict(Number.NaN)).toBe('none');
    expect(firstReplyVerdict(90)).toBe('good');
    expect(firstReplyVerdict(24 * 60)).toBe('good');
    expect(firstReplyVerdict(24 * 60 + 1)).toBe('warn');
    expect(firstReplyVerdict(72 * 60)).toBe('warn');
    expect(firstReplyVerdict(72 * 60 + 1)).toBe('bad');
  });
  it('süre insanlaştırma', () => {
    expect(humanizeDuration(0.2)).toEqual({ unit: 'minutes', value: 1 });
    expect(humanizeDuration(45)).toEqual({ unit: 'minutes', value: 45 });
    expect(humanizeDuration(96)).toEqual({ unit: 'hours', value: 1.6 });
    expect(humanizeDuration(3000)).toEqual({ unit: 'days', value: 2.1 });
  });
  it('sunucu listesinden sayı çıkarma: eksik anahtar 0', () => {
    expect(countsByKey([{ key: 'NEW', count: 3 }], ['NEW', 'DONE'])).toEqual({ NEW: 3, DONE: 0 });
    expect(countsByKey(undefined, ['NEW'])).toEqual({ NEW: 0 });
  });
});

describe('kampanyalar', () => {
  it('ulaşma oranı yalnız gönderilmiş ve kitlesi bilinen kampanyaları sayar', () => {
    const r = reachRate([
      { status: 'SENT', recipientCount: 90, audienceSize: 100 },
      { status: 'SENT', recipientCount: 50, audienceSize: 100 },
      { status: 'SENT', recipientCount: 10, audienceSize: null },
      { status: 'SCHEDULED', recipientCount: null, audienceSize: 500 },
      { status: 'FAILED', recipientCount: 0, audienceSize: 200 },
    ]);
    expect(r).toEqual({ reached: 140, audience: 200, percent: 70 });
  });
  it('ölçülebilir kampanya yoksa null; ulaşılan kitleden büyük çıkmaz', () => {
    expect(reachRate([])).toBeNull();
    expect(reachRate([{ status: 'SENT', recipientCount: 5, audienceSize: 0 }])).toBeNull();
    expect(reachRate([{ status: 'SENT', recipientCount: 150, audienceSize: 100 }])?.percent).toBe(100);
  });
  it('durum sayımı verilen sırayı korur, olmayan durum 0', () => {
    expect(
      statusCounts(
        [{ status: 'SENT' }, { status: 'SENT' }, { status: 'FAILED' }],
        ['SENT', 'SCHEDULED', 'FAILED'],
      ),
    ).toEqual([
      { key: 'SENT', count: 2 },
      { key: 'SCHEDULED', count: 0 },
      { key: 'FAILED', count: 1 },
    ]);
  });
  it('durum tonu: hata kırmızı, biten yeşil, sürüyor mavi', () => {
    expect(campaignTone('FAILED')).toBe('danger');
    expect(campaignTone('SENT')).toBe('success');
    expect(campaignTone('DONE')).toBe('success');
    expect(campaignTone('SENDING')).toBe('info');
    expect(campaignTone('bilinmiyor')).toBe('neutral');
  });
});

describe('kuyruk sağlığı', () => {
  it('ölü varsa kötü, başarısız varsa dikkat, yoksa iyi', () => {
    expect(queueHealth({ pending: 9, failed: 0, dead: 0 })).toBe('good');
    expect(queueHealth({ pending: 0, failed: 2, dead: 0 })).toBe('warn');
    expect(queueHealth({ pending: 0, failed: 2, dead: 1 })).toBe('bad');
    expect(queueProblems({ pending: 5, failed: 2, dead: 1 })).toBe(3);
  });
  it('bekleyen en eski kaydın yaşı dakika olarak; tarih yoksa ya da bozuksa null', () => {
    expect(ageMinutes(ago(90 * 60_000), NOW)).toBe(90);
    expect(ageMinutes(null, NOW)).toBeNull();
    expect(ageMinutes('bozuk', NOW)).toBeNull();
    expect(ageMinutes(new Date(NOW + H).toISOString(), NOW)).toBe(0);
  });
  it('teslim oranı: payda 0 ise null', () => {
    expect(deliveryRate(90, 5, 5)).toBe(90);
    expect(deliveryRate(0, 0, 0)).toBeNull();
  });
});

describe('e-posta kampanyası dağılımı', () => {
  it('beş parçayı sabit sırada ve tonla üretir; toplam hedefe eşittir', () => {
    const seg = mailShareSegments(
      { target: 100, pending: 10, queued: 70, skipped: 12, failed: 5, cancelled: 3 },
      {
        queued: 'Kuyruğa alındı',
        pending: 'Bekliyor',
        skipped: 'Atlandı',
        failed: 'Başarısız',
        cancelled: 'İptal',
      },
    );
    expect(seg.map((s) => s.key)).toEqual(['queued', 'pending', 'skipped', 'failed', 'cancelled']);
    expect(seg.find((s) => s.key === 'failed')?.tone).toBe('danger');
    expect(seg.reduce((s, x) => s + x.value, 0)).toBe(100);
  });
});
