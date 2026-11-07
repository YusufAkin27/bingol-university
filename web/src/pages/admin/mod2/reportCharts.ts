// Rapor kuyruğu grafiklerinin veri dönüşümleri (saf işlevler, testlidir).
import type { ReportView } from '../../../api/types';

export type PriorityLevel = 'URGENT' | 'HIGH' | 'NORMAL';
export type AgeBucket = 'fresh' | 'd1_3' | 'd3_7' | 'old';

export const AGE_BUCKETS: AgeBucket[] = ['fresh', 'd1_3', 'd3_7', 'old'];
export const LEVELS: PriorityLevel[] = ['URGENT', 'HIGH', 'NORMAL'];

const DAY = 86_400_000;

/** Öncelik puanı (açık raporlayan x10, gizliyse +100) yerine düz seviye: Acil / Yüksek / Normal. */
export function priorityLevel(p: number): PriorityLevel {
  return p >= 100 ? 'URGENT' : p >= 30 ? 'HIGH' : 'NORMAL';
}

/** Bir raporun bekleme süresine göre kovası. Geçersiz tarih "bugün" sayılır (uydurma uyarı üretilmez). */
export function ageBucket(createdAt: string, now: number): AgeBucket {
  const t = Date.parse(createdAt);
  if (!Number.isFinite(t)) return 'fresh';
  const age = now - t;
  if (age < DAY) return 'fresh';
  if (age < 3 * DAY) return 'd1_3';
  if (age < 7 * DAY) return 'd3_7';
  return 'old';
}

export function ageCounts(items: Pick<ReportView, 'createdAt'>[], now: number): Record<AgeBucket, number> {
  const out: Record<AgeBucket, number> = { fresh: 0, d1_3: 0, d3_7: 0, old: 0 };
  for (const r of items) out[ageBucket(r.createdAt, now)] += 1;
  return out;
}

export function levelCounts(items: Pick<ReportView, 'priority'>[]): Record<PriorityLevel, number> {
  const out: Record<PriorityLevel, number> = { URGENT: 0, HIGH: 0, NORMAL: 0 };
  for (const r of items) out[priorityLevel(r.priority ?? 0)] += 1;
  return out;
}
