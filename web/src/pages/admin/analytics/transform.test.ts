import { describe, expect, it } from 'vitest';
import {
  cohortLevel,
  cohortStyle,
  conversion,
  funnelRows,
  humanizeMinutes,
  isCohortMature,
  parseTab,
  percentChange,
  periodCompare,
  truncate,
} from './transform';

describe('percentChange / periodCompare', () => {
  it('önceki 0 ise tanımsızdır', () => {
    expect(percentChange(5, 0)).toBeNull();
    expect(percentChange(15, 10)).toBe(50);
    expect(percentChange(5, 10)).toBe(-50);
    expect(percentChange(1, 3)).toBe(-66.7);
  });

  it('son N günü bir önceki N günle karşılaştırır', () => {
    const counts = [1, 1, 1, 1, 2, 2, 2, 2]; // N=4: önceki 4 = 4, son 4 = 8
    expect(periodCompare(counts, 4)).toEqual({ current: 8, previous: 4, change: 100 });
  });

  it('veri kısaysa önceki dönem eksik kalır', () => {
    expect(periodCompare([3, 3], 7)).toEqual({ current: 6, previous: 0, change: null });
  });
});

describe('huni yüzdeleri', () => {
  const funnel = [
    { step: 'verified' as const, count: 80 },
    { step: 'registered' as const, count: 100 },
    { step: 'profileCompleted' as const, count: 40 },
    { step: 'joinedCommunity' as const, count: 10 },
    { step: 'sentMessage' as const, count: 20 },
  ];

  it('adımları kanonik sıraya dizer ve ilk adıma/öncekine oranlar', () => {
    const rows = funnelRows(funnel);
    expect(rows.map((r) => r.step)).toEqual([
      'registered',
      'verified',
      'profileCompleted',
      'joinedCommunity',
      'sentMessage',
    ]);
    expect(rows.map((r) => r.fromTop)).toEqual([100, 80, 40, 10, 20]);
    expect(rows[0].fromPrev).toBeNull();
    expect(rows[1].fromPrev).toBe(80);
    expect(rows[2].fromPrev).toBe(50);
    expect(rows[3].fromPrev).toBe(25);
  });

  it('bağımsız sayımda önceki adımdan büyük adım için dönüşüm gösterilmez (>%100 olmaz)', () => {
    const rows = funnelRows(funnel);
    expect(rows[4].fromPrev).toBeNull();
    expect(conversion(10, 20)).toBeNull();
    expect(conversion(0, 0)).toBeNull();
    expect(conversion(3, 1)).toBe(33);
  });

  it('boş huni boş döner', () => {
    expect(funnelRows([])).toEqual([]);
  });
});

describe('kohort renk skalası', () => {
  it('yüzdeleri 6 kademeye ayırır ve artan yüzde koyulaşır', () => {
    expect([0, 4.9, 5, 14.9, 15, 29, 30, 44, 45, 64, 65, 100].map(cohortLevel)).toEqual([
      0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5,
    ]);
    const mixes = [0, 10, 20, 40, 50, 80].map((v) => Number(/ (\d+)%/.exec(cohortStyle(v).background)?.[1]));
    expect(mixes).toEqual([...mixes].sort((a, b) => a - b));
  });

  it('koyu zeminde zıt metin rengi kullanır', () => {
    expect(cohortStyle(10).color).toBe('var(--text)');
    expect(cohortStyle(70).color).toBe('var(--primary-contrast)');
  });
});

describe('isCohortMature', () => {
  const today = new Date(2026, 9, 23); // 23 Ekim 2026
  it('N günü henüz dolmamış kohort ölçülemez', () => {
    expect(isCohortMature('2026-10-19', 1, today)).toBe(true);
    expect(isCohortMature('2026-10-19', 7, today)).toBe(false);
    expect(isCohortMature('2026-10-12', 7, today)).toBe(true);
    expect(isCohortMature('2026-09-28', 30, today)).toBe(false);
    expect(isCohortMature('2026-09-21', 30, today)).toBe(true);
  });
});

describe('küçük yardımcılar', () => {
  it('sekme ayrıştırma geçersiz değerde genel sekmesine düşer', () => {
    expect(parseTab('growth')).toBe('growth');
    expect(parseTab('x')).toBe('overview');
    expect(parseTab(null)).toBe('overview');
  });
  it('dakikayı saate çevirir', () => {
    expect(humanizeMinutes(45)).toEqual({ unit: 'minutes', value: 45 });
    expect(humanizeMinutes(180)).toEqual({ unit: 'hours', value: 3 });
  });
  it('uzun etiketi keser', () => {
    expect(truncate('abcdefghij', 5)).toBe('abcd…');
    expect(truncate('abc', 5)).toBe('abc');
  });
});
