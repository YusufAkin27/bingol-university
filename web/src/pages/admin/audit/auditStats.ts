// Denetim kaydı özeti (sistem2): son işlemlerin örneğinden zaman çizelgesi kovaları, eylem türü dağılımı ve alan sıralaması.
// Saf fonksiyonlar (React'siz); gün/saat sınırları Europe/Istanbul. Sunucuya yeni uç gerekmez: mevcut liste ucunun ilk sayfası örnek alınır.
import type { AuditRowV2 } from '../../../api/audit';
import { pathSegments } from './auditLogic';

/** Özet grafiklerinin örneklediği en yeni işlem sayısı (sunucu sayfa üst sınırı 100). */
export const AUDIT_SAMPLE_SIZE = 100;

/** Eylem türü: okuma / ekleme / değiştirme / silme. */
export type VerbClass = 'READ' | 'CREATE' | 'CHANGE' | 'DELETE';
export const VERB_CLASSES: VerbClass[] = ['CREATE', 'CHANGE', 'DELETE', 'READ'];

export function verbClass(method: string): VerbClass {
  switch (method.toUpperCase()) {
    case 'POST':
      return 'CREATE';
    case 'PUT':
    case 'PATCH':
      return 'CHANGE';
    case 'DELETE':
      return 'DELETE';
    default:
      return 'READ';
  }
}

/** Yoldaki ilk anlamlı parça ("/api/admin/users/3/role" -> "users"); yoksa "other". */
export function resourceOf(path: string): string {
  return pathSegments(path)[0] ?? 'other';
}

const FMT = new Intl.DateTimeFormat('sv-SE', {
  timeZone: 'Europe/Istanbul',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  hour12: false,
});

/** İstanbul saatiyle "yyyy-MM-dd" ve "HH" (geçersiz tarih: null). */
export function istanbulParts(iso: string): { day: string; hour: string } | null {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  const s = FMT.format(d); // "2026-10-28 09"
  return { day: s.slice(0, 10), hour: s.slice(11, 13) };
}

/** Bugünün İstanbul günü ("yyyy-MM-dd"); `now` testte verilir. */
export function istanbulToday(now: Date = new Date()): string {
  return FMT.format(now).slice(0, 10);
}

/** "yyyy-MM-dd" gününe `delta` gün ekler (takvim günü; saat dilimi kaymasından etkilenmez). */
export function addDays(day: string, delta: number): string {
  const [y, m, d] = day.split('-').map(Number);
  const t = new Date(Date.UTC(y, m - 1, d + delta));
  return t.toISOString().slice(0, 10);
}

export interface TimeBucket {
  /** "2026-10-28" ya da "2026-10-28T09" */
  key: string;
  /** Eksen yazısı: gün için "28.10", saat için "09:00" */
  label: string;
  total: number;
  denied: number;
}

export interface TimeBuckets {
  unit: 'hour' | 'day';
  buckets: TimeBucket[];
}

function dayLabel(day: string): string {
  return `${day.slice(8, 10)}.${day.slice(5, 7)}`;
}

/**
 * Satırları zaman kovalarına böler. Örnek 48 saate sığıyorsa saatlik, değilse günlük; aradaki boş kovalar 0 ile doldurulur
 * (en çok 62 kova; daha uzun aralıkta yalnız dolu kovalar). En eskiden en yeniye sıralıdır.
 */
export function bucketRows(rows: readonly AuditRowV2[]): TimeBuckets {
  const stamped = rows
    .map((r) => ({ r, p: istanbulParts(r.at) }))
    .filter((x): x is { r: AuditRowV2; p: { day: string; hour: string } } => x.p !== null);
  if (stamped.length === 0) return { unit: 'day', buckets: [] };
  const times = stamped.map((x) => new Date(x.r.at).getTime());
  const spanHours = (Math.max(...times) - Math.min(...times)) / 3_600_000;
  const unit: 'hour' | 'day' = spanHours <= 48 ? 'hour' : 'day';
  const keyOf = (p: { day: string; hour: string }) => (unit === 'hour' ? `${p.day}T${p.hour}` : p.day);
  const map = new Map<string, TimeBucket>();
  for (const { r, p } of stamped) {
    const key = keyOf(p);
    const b = map.get(key) ?? {
      key,
      label: unit === 'hour' ? `${p.hour}:00` : dayLabel(p.day),
      total: 0,
      denied: 0,
    };
    b.total += 1;
    if (r.status === 403) b.denied += 1;
    map.set(key, b);
  }
  const keys = [...map.keys()].sort();
  if (unit === 'day') {
    const first = keys[0];
    const last = keys[keys.length - 1];
    const out: TimeBucket[] = [];
    let cur = first;
    let guard = 0;
    while (cur <= last && guard++ < 62) {
      out.push(map.get(cur) ?? { key: cur, label: dayLabel(cur), total: 0, denied: 0 });
      cur = addDays(cur, 1);
    }
    if (cur > last) return { unit, buckets: out };
    return { unit, buckets: keys.map((k) => map.get(k)!) };
  }
  // saatlik: ilk ve son kova arasını doldur (en çok 49 kova)
  const out: TimeBucket[] = [];
  let [day, hour] = keys[0].split('T');
  const lastKey = keys[keys.length - 1];
  let guard = 0;
  while (`${day}T${hour}` <= lastKey && guard++ < 62) {
    const k = `${day}T${hour}`;
    out.push(map.get(k) ?? { key: k, label: `${hour}:00`, total: 0, denied: 0 });
    const h = Number(hour) + 1;
    if (h > 23) {
      day = addDays(day, 1);
      hour = '00';
    } else {
      hour = String(h).padStart(2, '0');
    }
  }
  return { unit, buckets: out };
}

export interface AuditSummary {
  total: number;
  denied: number;
  failed: number;
  byVerb: Record<VerbClass, number>;
  /** Alan (yolun ilk parçası) -> sayı, çoktan aza. */
  byResource: { resource: string; count: number }[];
  /** En çok işlem yapan yönetici (yoksa null). */
  topAdmin: { admin: string; count: number } | null;
  busiest: TimeBucket | null;
}

export function summarize(rows: readonly AuditRowV2[], buckets: TimeBuckets): AuditSummary {
  const byVerb: Record<VerbClass, number> = { READ: 0, CREATE: 0, CHANGE: 0, DELETE: 0 };
  const res = new Map<string, number>();
  const admins = new Map<string, number>();
  let denied = 0;
  let failed = 0;
  for (const r of rows) {
    byVerb[verbClass(r.method)] += 1;
    const k = resourceOf(r.path);
    res.set(k, (res.get(k) ?? 0) + 1);
    if (r.status === 403) denied += 1;
    else if (r.status >= 400) failed += 1;
    const a = r.adminEmail ?? '';
    if (a) admins.set(a, (admins.get(a) ?? 0) + 1);
  }
  const byResource = [...res.entries()].map(([resource, count]) => ({ resource, count })).sort((a, b) => b.count - a.count);
  const topAdminEntry = [...admins.entries()].sort((a, b) => b[1] - a[1])[0];
  const busiest = buckets.buckets.reduce<TimeBucket | null>((m, b) => (b.total > (m?.total ?? 0) ? b : m), null);
  return {
    total: rows.length,
    denied,
    failed,
    byVerb,
    byResource,
    topAdmin: topAdminEntry ? { admin: topAdminEntry[0], count: topAdminEntry[1] } : null,
    busiest,
  };
}

/** Çizelge için satırları İstanbul gününe göre gruplar (en yeni gün üstte; gün içi sıra korunur). */
export function groupByDay(rows: readonly AuditRowV2[]): { day: string; rows: AuditRowV2[] }[] {
  const map = new Map<string, AuditRowV2[]>();
  for (const r of rows) {
    const p = istanbulParts(r.at);
    const day = p?.day ?? '—';
    const list = map.get(day) ?? [];
    list.push(r);
    map.set(day, list);
  }
  return [...map.entries()]
    .sort((a, b) => (a[0] < b[0] ? 1 : a[0] > b[0] ? -1 : 0))
    .map(([day, list]) => ({ day, rows: list }));
}
