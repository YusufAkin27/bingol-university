import { describe, expect, it } from 'vitest';
import type { CrashGroup } from '../../../api/crashes';
import type { RetentionTable, StorageReport } from '../../../api/dataRetention';
import type { SystemIndicator } from '../../../api/system';
import {
  crashStatusShares,
  crashVersionTotals,
  daysUntilFull,
  fullestDisk,
  growthPerDay,
  growthRows,
  jobLanes,
  pushSample,
  queueSegments,
  summarizeHistory,
  summarizeOps,
  verdictOf,
  worstLevel,
  zoneScale,
} from './logic';

const DAY = 86_400_000;

describe('trafik ışığı', () => {
  it('düzeyi İyi / Dikkat / Acil sözcüğüne çevirir', () => {
    expect(verdictOf('OK')).toBe('good');
    expect(verdictOf('WARN')).toBe('attention');
    expect(verdictOf('CRIT')).toBe('urgent');
    expect(verdictOf('UNKNOWN')).toBe('unknown');
  });
  it('en kötü düzeyi seçer, boş kümede bilinmiyor der', () => {
    expect(worstLevel(['OK', 'WARN', 'OK'])).toBe('WARN');
    expect(worstLevel(['OK', 'CRIT', 'WARN'])).toBe('CRIT');
    expect(worstLevel(['OK', 'UNKNOWN'])).toBe('UNKNOWN');
    expect(worstLevel([])).toBe('UNKNOWN');
  });
});

describe('oturum geçmişi', () => {
  it('aynı anı tekrar eklemez, sıralar ve en son N ölçümü tutar', () => {
    let h = pushSample([], { at: 2, level: 'OK' }, 3);
    h = pushSample(h, { at: 2, level: 'CRIT' }, 3);
    expect(h).toHaveLength(1);
    h = pushSample(h, { at: 1, level: 'WARN' }, 3);
    h = pushSample(h, { at: 3, level: 'OK' }, 3);
    h = pushSample(h, { at: 4, level: 'OK' }, 3);
    expect(h.map((x) => x.at)).toEqual([2, 3, 4]);
  });
  it('geçersiz zamanı yok sayar', () => {
    expect(pushSample([], { at: 0, level: 'OK' })).toEqual([]);
    expect(pushSample([], { at: Number.NaN, level: 'OK' })).toEqual([]);
  });
  it('özetler: iyi/dikkat/acil sayıları ve son kötü an', () => {
    const s = summarizeHistory([
      { at: 1, level: 'OK' },
      { at: 2, level: 'WARN' },
      { at: 3, level: 'OK' },
      { at: 4, level: 'CRIT' },
      { at: 5, level: 'UNKNOWN' },
    ]);
    expect(s).toMatchObject({ total: 5, good: 2, attention: 1, urgent: 1, unknown: 1, lastBadAt: 4 });
    expect(summarizeHistory([{ at: 1, level: 'OK' }]).lastBadAt).toBeNull();
  });
});

describe('bölge ölçeği', () => {
  it('değeri ve eşikleri yüzdeye çevirir; eşik yoksa çizmez', () => {
    const z = zoneScale(30, 60, 120, 240)!;
    expect(z.warnPct).toBe(25);
    expect(z.critPct).toBe(50);
    expect(z.markPct).toBe(12.5);
    expect(zoneScale(30, null, undefined)).toBeNull();
    expect(zoneScale(-1, 10, 20)).toBeNull();
  });
  it('değer kritik eşiği aşınca işaret sağda kalır ve ölçek büyür', () => {
    const z = zoneScale(500, 100, 200)!;
    expect(z.markPct).toBeGreaterThan(80);
    expect(z.markPct).toBeLessThanOrEqual(100);
    expect(z.max).toBeGreaterThan(500);
  });
});

describe('görev şeridi', () => {
  const ind = (status: SystemIndicator['status'], value: number | null): SystemIndicator => ({
    status,
    value,
    threshold: { warn: 3600, crit: 7200 },
    message: null,
  });
  it('yalnız jobs.* alır, saniyeyi dakikaya çevirir, sorunluları öne alır', () => {
    const lanes = jobLanes([
      ['mail.dead', ind('OK', 0)],
      ['jobs.b', ind('OK', 600)],
      ['jobs.a', ind('CRIT', 9000)],
      ['jobs.c', ind('UNKNOWN', null)],
    ]);
    expect(lanes.map((l) => l.id)).toEqual(['jobs.a', 'jobs.c', 'jobs.b']);
    expect(lanes[0]).toMatchObject({ ageMin: 150, warnMin: 60, critMin: 120 });
    expect(lanes[1].scale).toBeNull();
    expect(lanes[2].scale?.markPct).toBeLessThan(lanes[0].scale!.markPct);
  });
});

describe('depolama büyüme tahmini', () => {
  const now = Date.parse('2026-11-01T00:00:00Z');
  const table = (name: string, sizeBytes: number | null, daysAgo: number | null): RetentionTable => ({
    name,
    label: name.toUpperCase(),
    description: '',
    estimatedRows: null,
    sizeBytes,
    oldestAt: daysAgo === null ? null : new Date(now - daysAgo * DAY).toISOString(),
    minRetentionDays: 30,
    maxTo: '2026-10-01',
    deletable: true,
    notDeletableReason: null,
    personalData: false,
  });
  it('boyut / gün; bir günden kısa ya da eksik veride tahmin uydurmaz', () => {
    expect(growthPerDay(1000, new Date(now - 10 * DAY).toISOString(), now)).toBe(100);
    expect(growthPerDay(1000, new Date(now - DAY / 2).toISOString(), now)).toBeNull();
    expect(growthPerDay(null, new Date(now - 10 * DAY).toISOString(), now)).toBeNull();
    expect(growthPerDay(1000, null, now)).toBeNull();
    expect(growthPerDay(0, new Date(now - 10 * DAY).toISOString(), now)).toBeNull();
    expect(growthPerDay(1000, 'bozuk', now)).toBeNull();
  });
  it('en hızlı büyüyenleri sıralar ve sınırlar', () => {
    const rows = growthRows([table('a', 100, 10), table('b', 5000, 10), table('c', null, 10), table('d', 900, 3)], now, 2);
    expect(rows.map((r) => r.name)).toEqual(['b', 'd']);
    expect(growthRows(undefined, now)).toEqual([]);
  });
  it('kaç gün yeter: boş yer / günlük büyüme', () => {
    expect(daysUntilFull(1000, 100)).toBe(10);
    expect(daysUntilFull(null, 100)).toBeNull();
    expect(daysUntilFull(1000, 0)).toBeNull();
    expect(daysUntilFull(-5, 10)).toBeNull();
  });
  it('en dolu diski seçer', () => {
    const disk = (key: string, percent: number | null, free: number | null) => ({
      key,
      roles: [],
      source: 'MEASURED' as const,
      path: null,
      totalBytes: null,
      usedBytes: null,
      freeBytes: free,
      percent,
      status: 'OK' as const,
    });
    const report = {
      dbServerDisk: disk('db', 40, 600),
      appDisks: [disk('app', 91, 90), disk('x', null, null)],
    } as unknown as StorageReport;
    expect(fullestDisk(report)).toEqual({ key: 'app', percent: 91, freeBytes: 90 });
    expect(fullestDisk(undefined)).toBeNull();
  });
});

describe('çökme dağılımı', () => {
  const group = (versions: CrashGroup['versions']): CrashGroup => ({ versions }) as CrashGroup;
  it('aynı sürüm + platformu gruplar arasında toplar, çoktan aza sıralar', () => {
    const v = crashVersionTotals([
      group([
        { version: '2.0.5', platform: 'ANDROID', count: 4 },
        { version: '2.0.4', platform: 'IOS', count: 9 },
      ]),
      group([{ version: '2.0.5', platform: 'ANDROID', count: 7 }]),
    ]);
    expect(v.map((x) => [x.version, x.platform, x.count])).toEqual([
      ['2.0.5', 'ANDROID', 11],
      ['2.0.4', 'IOS', 9],
    ]);
    expect(crashVersionTotals(undefined)).toEqual([]);
  });
  it('durum paylarını verir', () => {
    expect(crashStatusShares({ newGroups: 3, ackGroups: 2, resolvedGroups: 5, events24h: 0, reopened: 0 })).toEqual([
      { key: 'NEW', count: 3 },
      { key: 'ACK', count: 2 },
      { key: 'RESOLVED', count: 5 },
    ]);
    expect(crashStatusShares(undefined)).toEqual([]);
  });
});

describe('kuyruk parçaları', () => {
  it('sıfır ve eksik sayıları atar', () => {
    const segs = queueSegments([
      { key: 'pending', count: 3, tone: 'info' },
      { key: 'sending', count: 0, tone: 'neutral' },
      { key: 'failed', count: undefined, tone: 'warning' },
      { key: 'dead', count: 2, tone: 'danger' },
    ]);
    expect(segs.map((s) => s.key)).toEqual(['pending', 'dead']);
  });
});

describe('operasyon özeti', () => {
  const now = Date.parse('2026-11-01T12:00:00Z');
  const hoursAgo = (h: number) => new Date(now - h * 3_600_000).toISOString();
  it('her şey iyiyse İyi', () => {
    const r = summarizeOps({ healthStatus: 'UP', mailDead: 0, pushDead: 0, backup: { status: 'OK', lastSuccessAt: hoursAgo(2) }, now });
    expect(r.level).toBe('OK');
    expect(r.problems).toEqual([]);
  });
  it('gönderilemeyen kayıt varsa Dikkat ve sayıyı toplar', () => {
    const r = summarizeOps({ healthStatus: 'UP', mailDead: 2, pushDead: 5, backup: null, now });
    expect(r.level).toBe('WARN');
    expect(r.deadTotal).toBe(7);
    expect(r.problems).toEqual(['queues']);
  });
  it('sağlık düşükse ya da yedek başarısızsa Acil', () => {
    expect(summarizeOps({ healthStatus: 'DOWN', now }).level).toBe('CRIT');
    expect(summarizeOps({ backup: { status: 'FAILED', lastSuccessAt: hoursAgo(1) }, now }).level).toBe('CRIT');
  });
  it('yedek 48 saatten eskiyse Dikkat, hiç yoksa Dikkat', () => {
    const stale = summarizeOps({ backup: { status: 'OK', lastSuccessAt: hoursAgo(60) }, now });
    expect(stale.problems).toEqual(['backupStale']);
    expect(stale.backupHours).toBe(60);
    expect(summarizeOps({ backup: { status: 'UNKNOWN', lastSuccessAt: null }, now }).problems).toEqual(['backupNever']);
  });
  it('hiçbir uçtan veri gelmediyse bilinmiyor der (uydurma iyi demez)', () => {
    const r = summarizeOps({ now });
    expect(r.level).toBe('UNKNOWN');
    expect(r.known).toBe(0);
  });
});
