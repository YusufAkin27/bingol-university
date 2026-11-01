// Genel bakış: grafik veri dönüşümleri (saf işlevler; test: transform.test.ts).
import type { AnalyticsOverview } from '../../../api/types';
import { istanbulDaysAgo } from '../../../lib/date';

/** `yyyy-MM-dd` gününü `days` gün kaydırır (saat dilimi/yaz saati kaymasız salt tarih aritmetiği). */
export function shiftDate(iso: string, days: number): string {
  const [y, m, d] = iso.split('-').map(Number);
  const t = new Date(Date.UTC(y, m - 1, d + days));
  return `${t.getUTCFullYear()}-${String(t.getUTCMonth() + 1).padStart(2, '0')}-${String(t.getUTCDate()).padStart(2, '0')}`;
}

export interface WeekRow {
  /** Bu haftanın günü (yyyy-MM-dd); eksenin etiketi bundan üretilir. */
  date: string;
  thisWeek: number;
  lastWeek: number;
}

export interface WeekCompare {
  rows: WeekRow[];
  thisTotal: number;
  lastTotal: number;
  /** Her iki hafta için de seride gün bulundu mu (yoksa karşılaştırma yazılmaz: uydurma yüzde yok). */
  hasData: boolean;
}

/**
 * Son 7 TAMAMLANMIŞ gün (dün dahil, bugün hariç: bugün bitmedi) ile ondan önceki 7 günü gün gün eşler.
 * Seride olmayan gün 0 sayılır ama `hasData` yalnız her iki pencerede de en az bir gerçek nokta varsa true olur.
 */
export function weekCompare(points: { date: string; value: number }[], now = new Date()): WeekCompare {
  const byDate = new Map(points.map((p) => [p.date, p.value]));
  const end = istanbulDaysAgo(1, now);
  const rows: WeekRow[] = [];
  let foundThis = false;
  let foundLast = false;
  for (let i = 0; i < 7; i++) {
    const date = shiftDate(end, i - 6);
    const prev = shiftDate(date, -7);
    if (byDate.has(date)) foundThis = true;
    if (byDate.has(prev)) foundLast = true;
    rows.push({ date, thisWeek: byDate.get(date) ?? 0, lastWeek: byDate.get(prev) ?? 0 });
  }
  return {
    rows,
    thisTotal: rows.reduce((s, r) => s + r.thisWeek, 0),
    lastTotal: rows.reduce((s, r) => s + r.lastWeek, 0),
    hasData: foundThis && foundLast,
  };
}

export interface AudienceLevel {
  key: 'total' | 'month' | 'week' | 'day';
  value: number;
}

/**
 * "Kitlenin ne kadarı aktif": kayıtlı > bu ay giren > bu hafta giren > bugün giren. Sayılar iç içe kümelerdir; çubuk uzunlukları
 * doğrudan karşılaştırılabilir. Sunucu tutarsız dönerse (örn. haftalık > aylık) sıralama bozulmaz, değer olduğu gibi gösterilir.
 */
export function audienceLevels(o: Pick<AnalyticsOverview, 'totalUsers' | 'activeUsers'>): AudienceLevel[] {
  return [
    { key: 'total', value: o.totalUsers },
    { key: 'month', value: o.activeUsers.mau },
    { key: 'week', value: o.activeUsers.wau },
    { key: 'day', value: o.activeUsers.dau },
  ];
}

/** Toplamın yüzdesi (0-100, tam sayı); toplam 0 ise null. */
export function sharePercent(part: number, total: number): number | null {
  if (total <= 0) return null;
  return Math.round((part / total) * 100);
}

/** Son `days` günün toplamı (bugün dahil değil) için nokta toplamı. */
export function sumWindow(points: { date: string; value: number }[], endDate: string, days: number): { total: number; found: boolean } {
  const start = shiftDate(endDate, -(days - 1));
  let total = 0;
  let found = false;
  for (const p of points) {
    if (p.date >= start && p.date <= endDate) {
      total += p.value;
      found = true;
    }
  }
  return { total, found };
}
