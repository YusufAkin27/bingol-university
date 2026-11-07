import type { FunnelStep } from '../../../api/types';
import { shiftDate } from '../dashboard/transform';

export const TABS = ['overview', 'growth', 'engagement', 'retention', 'demographics', 'behavior'] as const;
export type TabId = (typeof TABS)[number];

export function parseTab(v: string | null | undefined): TabId {
  return (TABS as readonly string[]).includes(v ?? '') ? (v as TabId) : 'overview';
}

export const DIMENSIONS = [
  'faculty',
  'department',
  'classYear',
  'language',
  'role',
  'status',
  'platform',
] as const;

/** Yüzde değişimi (önceki 0 ise tanımsız → null). Tek ondalık. */
export function percentChange(current: number, previous: number): number | null {
  if (previous <= 0) return null;
  return Math.round(((current - previous) / previous) * 1000) / 10;
}

export interface PeriodCompare {
  current: number;
  previous: number;
  change: number | null;
}

/** Son `days` günün toplamı ile ondan önceki `days` günün toplamını karşılaştırır. */
export function periodCompare(counts: number[], days: number): PeriodCompare {
  const sum = (a: number[]) => a.reduce((s, v) => s + v, 0);
  const current = sum(counts.slice(Math.max(0, counts.length - days)));
  const previous = sum(counts.slice(Math.max(0, counts.length - 2 * days), Math.max(0, counts.length - days)));
  return { current, previous, change: percentChange(current, previous) };
}

export const FUNNEL_ORDER: FunnelStep[] = [
  'registered',
  'verified',
  'profileCompleted',
  'joinedCommunity',
  'sentMessage',
];

export interface FunnelRow {
  step: FunnelStep;
  count: number;
  /** İlk adıma göre yüzde (0-100, tam sayı). */
  fromTop: number;
  /** Önceki adımdan dönüşüm yüzdesi; ilk adımda null. */
  fromPrev: number | null;
}

/**
 * Adımdan adıma dönüşüm yüzdesi. Backend adımları bağımsız saydığından bir adım öncekinden büyük
 * olabilir; bu durumda dönüşüm anlamsızdır ve null döner.
 */
export function conversion(prev: number, cur: number): number | null {
  if (prev <= 0 || cur > prev) return null;
  return Math.round((cur / prev) * 100);
}

/** Huni adımlarını kanonik sıraya dizip adımlar arası dönüşüm yüzdelerini hesaplar. */
export function funnelRows(funnel: { step: FunnelStep; count: number }[]): FunnelRow[] {
  const byStep = new Map(funnel.map((f) => [f.step, f.count]));
  const ordered = FUNNEL_ORDER.filter((s) => byStep.has(s)).map((s) => ({ step: s, count: byStep.get(s) ?? 0 }));
  const top = ordered[0]?.count ?? 0;
  return ordered.map((r, i) => ({
    ...r,
    fromTop: top > 0 ? Math.round((r.count / top) * 100) : 0,
    fromPrev: i === 0 ? null : conversion(ordered[i - 1].count, r.count),
  }));
}

/** Kohort ısı haritası: yüzdeyi 6 kademeye ayırır; kademe 4+ koyu zemindir (okunur metin için zıt renk). */
export const COHORT_LEVEL_MIX = [6, 22, 38, 58, 78, 90] as const;

export function cohortLevel(value: number): 0 | 1 | 2 | 3 | 4 | 5 {
  if (value >= 65) return 5;
  if (value >= 45) return 4;
  if (value >= 30) return 3;
  if (value >= 15) return 2;
  if (value >= 5) return 1;
  return 0;
}

export function cohortStyle(value: number): { background: string; color: string; level: number } {
  const level = cohortLevel(value);
  return {
    level,
    background: `color-mix(in srgb, var(--chart-1) ${COHORT_LEVEL_MIX[level]}%, var(--surface))`,
    color: level >= 4 ? 'var(--primary-contrast)' : 'var(--text)',
  };
}

/**
 * Kohortun D<n> değeri anlamlı mı: kohort haftasının ilk gününden n gün geçmediyse
 * hiçbir kullanıcı için n. gün dolmamıştır ve backend 0 döndürür; bu "ölçülemez" demektir.
 */
export function isCohortMature(weekStart: string, days: number, today: Date = new Date()): boolean {
  const [y, m, d] = weekStart.split('-').map(Number);
  const start = new Date(y, m - 1, d);
  const t = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const diffDays = Math.round((t.getTime() - start.getTime()) / 86_400_000);
  return diffDays >= days;
}

/** Dakikayı kısa süreye çevirir: 90 dk → 1,5 sa. */
export function humanizeMinutes(min: number): { unit: 'minutes' | 'hours'; value: number } {
  if (min >= 120) return { unit: 'hours', value: Math.round((min / 60) * 10) / 10 };
  return { unit: 'minutes', value: Math.round(min) };
}

/** Backend'in tek istekte kabul ettiği en uzun aralık (docs/ADMIN_API.md "Analitik"). */
export const MAX_RANGE_DAYS = 366;

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** İki gün arası (uçlar dahil) gün sayısı; geçersiz tarihte 0. */
export function rangeDays(r: { from?: string; to?: string }): number {
  if (!r.from || !r.to || !DATE_RE.test(r.from) || !DATE_RE.test(r.to)) return 0;
  const [fy, fm, fd] = r.from.split('-').map(Number);
  const [ty, tm, td] = r.to.split('-').map(Number);
  const diff = Math.round((Date.UTC(ty, tm - 1, td) - Date.UTC(fy, fm - 1, fd)) / 86_400_000);
  return diff + 1;
}

export interface ClampedRange {
  from: string;
  to: string;
  /** Aralık ters girilmişti (başlangıç > bitiş) ve yer değiştirildi. */
  swapped: boolean;
  /** Aralık `MAX_RANGE_DAYS`'ten uzundu ve başlangıç ileri alındı. */
  clipped: boolean;
}

/** URL'den gelen aralığı güvenli hâle getirir: ters aralık çevrilir, 366 günden uzunsa başlangıç ileri alınır. */
export function clampRange(from: string, to: string): ClampedRange {
  let f = from;
  let t = to;
  let swapped = false;
  if (f > t) {
    [f, t] = [t, f];
    swapped = true;
  }
  let clipped = false;
  if (rangeDays({ from: f, to: t }) > MAX_RANGE_DAYS) {
    f = shiftDate(t, -(MAX_RANGE_DAYS - 1));
    clipped = true;
  }
  return { from: f, to: t, swapped, clipped };
}

/** Aynı uzunlukta, hemen önceki dönem ([from-n, from-1]). Geçersiz aralıkta null. */
export function previousRange(r: { from?: string; to?: string }): { from: string; to: string } | null {
  const n = rangeDays(r);
  if (n <= 0 || !r.from) return null;
  return { from: shiftDate(r.from, -n), to: shiftDate(r.from, -1) };
}

/**
 * Önceki dönem değerlerini gün sırasına göre (1. gün ile 1. gün) `prev` alanı olarak ekler.
 * Önceki dönem yoksa `prev` undefined kalır (grafik tek seriyle çizilir).
 */
export function mergePrevious<T extends { date: string }>(
  current: T[],
  previous: T[] | undefined,
  pick: (p: T) => number,
): (T & { prev: number | undefined })[] {
  return current.map((p, i) => ({ ...p, prev: previous && previous[i] ? pick(previous[i]) : undefined }));
}

export interface SeriesStats {
  total: number;
  avg: number;
  peakIndex: number;
  peak: number;
}

/** Toplam, günlük ortalama ve en yoğun gün (boş seride peakIndex -1). */
export function seriesStats(values: number[]): SeriesStats {
  const total = values.reduce((s, v) => s + v, 0);
  let peakIndex = -1;
  let peak = 0;
  values.forEach((v, i) => {
    if (peakIndex === -1 || v > peak) {
      peakIndex = i;
      peak = v;
    }
  });
  return { total, avg: values.length ? Math.round(total / values.length) : 0, peakIndex, peak };
}

/** Uzun etiketleri keser (tam metin tabloda durur). */
export function truncate(s: string, max = 18): string {
  return s.length > max ? `${s.slice(0, max - 1)}…` : s;
}
