import { useMemo } from 'react';
import { useI18n, type I18n } from '../../i18n/I18nProvider';

/** Biçimlendirme için gereken en küçük i18n yüzeyi (test ve sunucu tarafında kolay taklit). */
export type FormatCtx = Pick<I18n, 't' | 'formatNumber' | 'formatDate'>;

const NBSP = '\u00a0';
const DASH = '–';

const COMPACT_UNITS = [
  { div: 1e3, key: 'admin.kit.unit.k' },
  { div: 1e6, key: 'admin.kit.unit.m' },
  { div: 1e9, key: 'admin.kit.unit.b' },
  { div: 1e12, key: 'admin.kit.unit.t' },
] as const;

const round1 = (v: number) => Math.round(v * 10) / 10;

/** Kısa sayı: 12400 -> "12,4 B", 1200000 -> "1,2 Mn". 1000'den küçük sayılar olduğu gibi yazılır. */
export function formatCompact(n: number | null | undefined, ctx: FormatCtx): string {
  if (n === null || n === undefined || !Number.isFinite(n)) return DASH;
  const abs = Math.abs(n);
  if (abs < 1000) return ctx.formatNumber(n, { maximumFractionDigits: Number.isInteger(n) ? 0 : 1 });
  let idx = 0;
  for (let i = 0; i < COMPACT_UNITS.length; i++) if (abs >= COMPACT_UNITS[i].div) idx = i;
  let r = round1(n / COMPACT_UNITS[idx].div);
  // 999,96 B -> "1000 B" olmasın: bir üst birime çık
  if (Math.abs(r) >= 1000 && idx < COMPACT_UNITS.length - 1) {
    idx += 1;
    r = round1(n / COMPACT_UNITS[idx].div);
  }
  return `${ctx.formatNumber(r, { maximumFractionDigits: 1 })}${NBSP}${ctx.t(COMPACT_UNITS[idx].key)}`;
}

/** Yüzde: 0-100 aralığındaki değeri yazar ("%12", "%12,5"). Yerel ayar işaretin yerini belirler. */
export function formatPercent(value: number | null | undefined, ctx: FormatCtx, digits = 0): string {
  if (value === null || value === undefined || !Number.isFinite(value)) return DASH;
  return ctx.formatNumber(value / 100, { style: 'percent', maximumFractionDigits: digits });
}

/** Önceki değere göre yüzde değişim; önceki 0 ya da bilinmiyorsa null (uydurma oran yazılmaz). */
export function percentChange(current: number, previous: number | null | undefined): number | null {
  if (previous === null || previous === undefined || !Number.isFinite(previous) || previous === 0) return null;
  if (!Number.isFinite(current)) return null;
  return ((current - previous) / Math.abs(previous)) * 100;
}

/** Göreli süre: "Az önce", "3 dk önce", "2 sa önce", "Dün", "5 gün önce"; 30 günden eskisi tarih olarak yazılır. */
export function relativeTime(
  value: string | number | Date | null | undefined,
  ctx: FormatCtx,
  now: number = Date.now(),
): string {
  if (value === null || value === undefined || value === '') return DASH;
  const at = value instanceof Date ? value.getTime() : new Date(value).getTime();
  if (Number.isNaN(at)) return DASH;
  const diffSec = Math.round((now - at) / 1000);
  const abs = Math.abs(diffSec);
  const future = diffSec < 0;
  if (abs < 45) return ctx.t(future ? 'admin.kit.time.soon' : 'admin.kit.time.now');
  const minutes = Math.max(1, Math.round(abs / 60));
  if (abs < 3600) {
    return ctx.t(future ? 'admin.kit.time.inMinutes' : 'admin.kit.time.minutes', { n: ctx.formatNumber(minutes) });
  }
  const hours = Math.floor(abs / 3600);
  if (hours < 24) {
    return ctx.t(future ? 'admin.kit.time.inHours' : 'admin.kit.time.hours', { n: ctx.formatNumber(hours) });
  }
  const days = Math.floor(hours / 24);
  if (days === 1) return ctx.t(future ? 'admin.kit.time.tomorrow' : 'admin.kit.time.yesterday');
  if (days <= 30) {
    return ctx.t(future ? 'admin.kit.time.inDays' : 'admin.kit.time.days', { n: ctx.formatNumber(days) });
  }
  return ctx.formatDate(at);
}

/** Bileşenler ve sayfalar için hazır biçimlendiriciler (dil değişince yenilenir). */
export function useKitFormat() {
  const { t, formatNumber, formatDate } = useI18n();
  return useMemo(() => {
    const ctx: FormatCtx = { t, formatNumber, formatDate };
    return {
      compact: (n: number | null | undefined) => formatCompact(n, ctx),
      percent: (v: number | null | undefined, digits = 0) => formatPercent(v, ctx, digits),
      relative: (v: string | number | Date | null | undefined, now?: number) => relativeTime(v, ctx, now),
      number: (n: number) => formatNumber(n),
    };
  }, [t, formatNumber, formatDate]);
}
