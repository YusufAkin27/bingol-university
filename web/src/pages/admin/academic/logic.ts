// Akademik yönetim sayfalarının saf mantığı (test edilebilir): tarih dönüşümü, doğrulama, ay ızgarası.
import type { AcademicEvent } from '../../../api/academic';

/** Sunucu yanıtı daima +03:00 ofsetlidir; form için "YYYY-MM-DDTHH:mm" (saat dilimsiz) alınır. */
export function toDateTimeInput(iso: string | null | undefined): string {
  return iso ? iso.slice(0, 16) : '';
}
export function toDateInput(iso: string | null | undefined): string {
  return iso ? iso.slice(0, 10) : '';
}
/** Boş metin null olur (PATCH'te alanı temizlemek için). */
export function emptyToNull(v: string): string | null {
  const s = v.trim();
  return s ? s : null;
}

/** Tüm gün olayı: tarih alanları "T00:00" / "T23:59" ile gönderilir. */
export function allDayRange(start: string, end: string): { startsAt: string; endsAt: string | null } {
  return { startsAt: `${start}T00:00`, endsAt: end ? `${end}T23:59` : null };
}

export function isHttps(url: string): boolean {
  return /^https:\/\/\S+$/i.test(url.trim());
}

/** Bitiş başlangıçtan sonra olmalı (ikisi de aynı biçimde, sözlüksel karşılaştırma yeterli). */
export function endAfterStart(start: string, end: string): boolean {
  return !end || !start || end > start;
}

export interface ImportSummary {
  lines: number;
  tooMany: boolean;
}
export const IMPORT_MAX_LINES = 200;
/** Boş satırlar ve # yorumları sayılmaz. */
export function summarizeImport(text: string): ImportSummary {
  const lines = text.split(/\r?\n/).filter((l) => l.trim() && !l.trim().startsWith('#')).length;
  return { lines, tooMany: lines > IMPORT_MAX_LINES };
}

export interface MonthCell {
  date: string; // YYYY-MM-DD
  day: number;
  inMonth: boolean;
}
const pad = (n: number) => String(n).padStart(2, '0');
export const ymd = (y: number, m0: number, d: number) => `${y}-${pad(m0 + 1)}-${pad(d)}`;

/** Pazartesi başlangıçlı ay ızgarası (6 hafta değil, gereken hafta sayısı). */
export function monthGrid(year: number, month0: number): MonthCell[][] {
  const first = new Date(Date.UTC(year, month0, 1));
  const lead = (first.getUTCDay() + 6) % 7;
  const days = new Date(Date.UTC(year, month0 + 1, 0)).getUTCDate();
  const total = Math.ceil((lead + days) / 7) * 7;
  const cells: MonthCell[] = [];
  for (let i = 0; i < total; i++) {
    const d = new Date(Date.UTC(year, month0, 1 - lead + i));
    cells.push({
      date: ymd(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()),
      day: d.getUTCDate(),
      inMonth: d.getUTCMonth() === month0,
    });
  }
  const weeks: MonthCell[][] = [];
  for (let i = 0; i < cells.length; i += 7) weeks.push(cells.slice(i, i + 7));
  return weeks;
}

/** Olayın kapsadığı günlere göre dizin (aralık olayları her güne eklenir; en çok 366 gün). */
export function eventsByDay(events: AcademicEvent[]): Map<string, AcademicEvent[]> {
  const map = new Map<string, AcademicEvent[]>();
  for (const ev of events) {
    const start = ev.startsAt.slice(0, 10);
    const end = (ev.endsAt ?? ev.startsAt).slice(0, 10);
    const cur = new Date(`${start}T00:00:00Z`);
    const last = new Date(`${end >= start ? end : start}T00:00:00Z`);
    for (let n = 0; cur <= last && n < 366; n++) {
      const key = ymd(cur.getUTCFullYear(), cur.getUTCMonth(), cur.getUTCDate());
      const arr = map.get(key) ?? [];
      arr.push(ev);
      map.set(key, arr);
      cur.setUTCDate(cur.getUTCDate() + 1);
    }
  }
  return map;
}

export function shiftMonth(year: number, month0: number, delta: number): { year: number; month0: number } {
  const d = new Date(Date.UTC(year, month0 + delta, 1));
  return { year: d.getUTCFullYear(), month0: d.getUTCMonth() };
}

export function totalPages(total: number, size: number): number {
  return Math.max(1, Math.ceil(total / size));
}

export type AnnouncementState = 'draft' | 'scheduled' | 'active' | 'expired';
/** Yönetici listesindeki durum (sunucu süzgeciyle aynı kurallar). */
export function announcementState(
  a: { published: boolean; publishAt: string | null; expiresAt: string | null },
  now: number = Date.now(),
): AnnouncementState {
  if (!a.published) return 'draft';
  if (a.expiresAt && Date.parse(a.expiresAt) <= now) return 'expired';
  if (a.publishAt && Date.parse(a.publishAt) > now) return 'scheduled';
  return 'active';
}

/** Okunma yüzdesi (hedef kitle 0 ise null). */
export function readPercent(read: number, audience: number | undefined): number | null {
  if (!audience || audience <= 0) return null;
  return Math.min(100, Math.round((read / audience) * 100));
}
