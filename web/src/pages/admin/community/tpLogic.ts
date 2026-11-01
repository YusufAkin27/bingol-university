// PANEL-topluluk: grafik/özet veri dönüşümleri (saf işlevler; arayüzden bağımsız, birim testli).
import type { RankedItem } from '../../../components/ui';

const DAY_MS = 24 * 3600 * 1000;

/** Bir kaydın kaç tam gündür beklediği (gelecek/bozuk tarih = 0). */
export function waitDays(createdAt: string, now: Date = new Date()): number {
  const t = new Date(createdAt).getTime();
  if (Number.isNaN(t)) return 0;
  return Math.max(0, Math.floor((now.getTime() - t) / DAY_MS));
}

/** En eski kaydın bekleme günü; liste boşsa null. */
export function oldestWaitDays(items: { createdAt: string }[], now: Date = new Date()): number | null {
  if (items.length === 0) return null;
  return Math.max(...items.map((i) => waitDays(i.createdAt, now)));
}

/** Bu kadar günden uzun bekleyen başvuru "yavaşladı" sayılır. */
export const STALE_DAYS = 3;

export interface OccupancyInput {
  id: number;
  title: string;
  capacity: number | null;
  goingCount: number;
}
export interface OccupancyRow {
  id: number;
  title: string;
  going: number;
  capacity: number;
  /** 0..n yüzde (kontenjan aşılmışsa 100'ü geçer). */
  pct: number;
}

/** Kontenjanlı etkinlikleri doluluğa göre azalan sırala; kontenjansız/0 olanlar dışarıda kalır. */
export function occupancyRows(events: OccupancyInput[]): OccupancyRow[] {
  return events
    .filter((e) => e.capacity !== null && e.capacity > 0)
    .map((e) => ({
      id: e.id,
      title: e.title,
      going: e.goingCount,
      capacity: e.capacity as number,
      pct: Math.round((e.goingCount / (e.capacity as number)) * 100),
    }))
    .sort((a, b) => b.pct - a.pct || b.going - a.going || a.id - b.id);
}

/** "Dolmak üzere" eşiği: kontenjanın bu oranı dolu. */
export const ALMOST_FULL_PCT = 85;

export function toOccupancyItems(
  rows: OccupancyRow[],
  hint: (r: OccupancyRow) => string,
): RankedItem[] {
  return rows.map((r) => ({ key: String(r.id), label: r.title, value: r.pct, hint: hint(r) }));
}

export interface AttendanceSummary {
  going: number;
  present: number;
  absent: number;
  unmarked: number;
  walkIns: number;
}

/** Gelme oranı (0..1): gelen / katılacak. Katılacak yoksa null (oran anlamsız). */
export function attendanceRatio(s: AttendanceSummary): number | null {
  if (s.going <= 0) return null;
  return Math.min(1, Math.max(0, s.present / s.going));
}

/** Yoklama hiç işaretlenmediyse (gelen ve gelmeyen sıfır) true. */
export function attendanceNotStarted(s: AttendanceSummary): boolean {
  return s.present === 0 && s.absent === 0;
}

export interface Tally {
  key: string;
  label: string;
  count: number;
}

/** Değerleri anahtara göre sayar, çoktan aza sıralar (eşitlikte etikete göre). */
export function tally<T>(rows: T[], keyOf: (r: T) => string | null, labelOf: (key: string, r: T) => string): Tally[] {
  const map = new Map<string, Tally>();
  for (const r of rows) {
    const k = keyOf(r);
    if (k === null) continue;
    const cur = map.get(k);
    if (cur) cur.count += 1;
    else map.set(k, { key: k, label: labelOf(k, r), count: 1 });
  }
  return [...map.values()].sort((a, b) => b.count - a.count || a.label.localeCompare(b.label, 'tr'));
}
