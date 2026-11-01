import { describe, expect, it } from 'vitest';
import {
  ageHistogram,
  ageMs,
  clampIndex,
  countUrgentByAge,
  DAY_MS,
  dailyCounts,
  fetchQueue,
  HOUR_MS,
  maxUrgency,
  oldestAgeMs,
  runBatch,
  shouldIgnoreShortcut,
  sortByPriority,
  urgencyOfAge,
  urgencyOfStrikes,
  weekOverWeek,
} from './queueLogic';

const NOW = Date.parse('2026-11-01T12:00:00Z');
const ago = (ms: number) => new Date(NOW - ms).toISOString();

describe('kuyruk yaşı', () => {
  it('geçersiz tarih null, gelecek tarih 0 döner', () => {
    expect(ageMs(null, NOW)).toBeNull();
    expect(ageMs('bozuk', NOW)).toBeNull();
    expect(ageMs(ago(-HOUR_MS), NOW)).toBe(0);
  });

  it('dört kovaya sınırlarda doğru dağıtır', () => {
    const hist = ageHistogram(
      [ago(HOUR_MS), ago(DAY_MS), ago(2 * DAY_MS), ago(3 * DAY_MS), ago(6 * DAY_MS), ago(7 * DAY_MS), ago(40 * DAY_MS), null],
      NOW,
    );
    expect(hist.map((b) => b.id)).toEqual(['fresh', 'recent', 'aging', 'stale']);
    expect(hist.map((b) => b.count)).toEqual([1, 2, 2, 2]);
  });

  it('boş listede dört kova sıfırla döner', () => {
    expect(ageHistogram([], NOW).every((b) => b.count === 0)).toBe(true);
  });

  it('en eski bekleme ve acil sayısı', () => {
    const dates = [ago(HOUR_MS), ago(8 * DAY_MS), ago(10 * DAY_MS)];
    expect(oldestAgeMs(dates, NOW)).toBe(10 * DAY_MS);
    expect(countUrgentByAge(dates, NOW)).toBe(2);
    expect(oldestAgeMs([], NOW)).toBeNull();
  });
});

describe('öncelik', () => {
  it('yaşa ve ihlal sayısına göre aciliyet', () => {
    expect(urgencyOfAge(2 * DAY_MS)).toBe('normal');
    expect(urgencyOfAge(3 * DAY_MS)).toBe('attention');
    expect(urgencyOfAge(7 * DAY_MS)).toBe('urgent');
    expect(urgencyOfAge(null)).toBe('normal');
    expect(urgencyOfStrikes(2)).toBe('normal');
    expect(urgencyOfStrikes(3)).toBe('attention');
    expect(urgencyOfStrikes(5)).toBe('urgent');
    expect(maxUrgency('attention', 'urgent')).toBe('urgent');
    expect(maxUrgency('normal', 'attention')).toBe('attention');
  });

  it('önce acil, sonra ağırlık, sonra en eski; girdiyi değiştirmez', () => {
    const items = [
      { id: 'yeni-az', urgency: 'normal' as const, weight: 1, createdAt: '2026-10-31T00:00:00Z' },
      { id: 'eski-az', urgency: 'normal' as const, weight: 1, createdAt: '2026-10-20T00:00:00Z' },
      { id: 'acil', urgency: 'urgent' as const, weight: 0, createdAt: '2026-10-30T00:00:00Z' },
      { id: 'cok', urgency: 'normal' as const, weight: 4, createdAt: '2026-10-31T10:00:00Z' },
    ];
    const copy = [...items];
    const sorted = sortByPriority(items, (x) => x);
    expect(sorted.map((x) => x.id)).toEqual(['acil', 'cok', 'eski-az', 'yeni-az']);
    expect(items).toEqual(copy);
  });
});

describe('günlük sayım', () => {
  it('kayan 24 saatlik pencerelerde eskiden yeniye sayar, pencere dışını atar', () => {
    const daily = dailyCounts([ago(HOUR_MS), ago(2 * HOUR_MS), ago(DAY_MS + HOUR_MS), ago(20 * DAY_MS)], NOW, 14);
    expect(daily).toHaveLength(14);
    expect(daily[13]).toBe(2);
    expect(daily[12]).toBe(1);
    expect(daily.reduce((a, b) => a + b, 0)).toBe(3);
  });

  it('hafta hafta karşılaştırma', () => {
    const daily = [...Array.from({ length: 7 }, () => 1), ...Array.from({ length: 7 }, () => 3)];
    expect(weekOverWeek(daily)).toEqual({ current: 21, previous: 7 });
  });
});

describe('kuyruk okuma', () => {
  it('imleci izler, bitince truncated=false döner', async () => {
    const pages = [
      { items: [1, 2], nextCursor: 2 },
      { items: [3], nextCursor: null },
    ];
    const seen: Array<number | null> = [];
    const r = await fetchQueue(async (c: number | null) => {
      seen.push(c);
      return pages[seen.length - 1];
    });
    expect(r).toEqual({ items: [1, 2, 3], truncated: false });
    expect(seen).toEqual([null, 2]);
  });

  it('sayfa sınırında truncated=true bildirir', async () => {
    let n = 0;
    const r = await fetchQueue(async () => ({ items: [n++], nextCursor: n }), 3);
    expect(r.items).toEqual([0, 1, 2]);
    expect(r.truncated).toBe(true);
  });
});

describe('toplu işlem', () => {
  it('başarı ve hataları ayırır, hatayı dışarı sızdırmaz', async () => {
    const out = await runBatch([1, 2, 3, 4], async (n) => {
      if (n === 3) throw new Error('x');
    });
    expect(out.ok.sort()).toEqual([1, 2, 4]);
    expect(out.failed.map((f) => f.item)).toEqual([3]);
    expect(out.rateLimited).toBe(false);
  });

  it('429 gelince yeni istek başlatmaz ve kalanları bildirir', async () => {
    const called: number[] = [];
    const out = await runBatch(
      [1, 2, 3, 4, 5, 6],
      async (n) => {
        called.push(n);
        if (n === 2) throw Object.assign(new Error('rate'), { status: 429 });
      },
      1,
    );
    expect(out.rateLimited).toBe(true);
    expect(out.ok).toEqual([1]);
    expect(called).toEqual([1, 2]);
    expect(out.skipped).toEqual([2, 3, 4, 5, 6]);
  });
});

describe('klavye', () => {
  const ev = (over: Partial<Pick<KeyboardEvent, 'target' | 'ctrlKey' | 'metaKey' | 'altKey'>>) => ({
    target: document.body,
    ctrlKey: false,
    metaKey: false,
    altKey: false,
    ...over,
  });

  it('yazı alanında ve değiştirici tuşla yoksayar; onay kutusunda yoksaymaz', () => {
    const text = document.createElement('input');
    text.type = 'text';
    const box = document.createElement('input');
    box.type = 'checkbox';
    expect(shouldIgnoreShortcut(ev({}))).toBe(false);
    expect(shouldIgnoreShortcut(ev({ target: text }))).toBe(true);
    expect(shouldIgnoreShortcut(ev({ target: box }))).toBe(false);
    expect(shouldIgnoreShortcut(ev({ ctrlKey: true }))).toBe(true);
  });

  it('açık pencere varken yoksayar', () => {
    const dlg = document.createElement('div');
    dlg.setAttribute('role', 'dialog');
    document.body.appendChild(dlg);
    expect(shouldIgnoreShortcut(ev({}))).toBe(true);
    dlg.remove();
  });

  it('dizin sınırlanır', () => {
    expect(clampIndex(5, 3)).toBe(2);
    expect(clampIndex(-4, 3)).toBe(0);
    expect(clampIndex(0, 0)).toBe(-1);
  });
});
