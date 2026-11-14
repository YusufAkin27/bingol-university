// Haftalık program satırı doğrulaması (saf işlevler; sunucu kuralıyla aynı: bitiş > başlangıç, en çok 30 satır).
import { toMinutes } from '../format';

export interface SlotRow {
  key: string;
  dayOfWeek: number;
  startTime: string;
  endTime: string;
  room: string;
}

export const MAX_SLOTS = 30;
const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

export type SlotError = 'start' | 'end' | 'order';

/** Satır hatası: geçersiz saat biçimi ya da bitiş <= başlangıç. Hata yoksa null. */
export function slotError(r: Pick<SlotRow, 'startTime' | 'endTime'>): SlotError | null {
  if (!HHMM.test(r.startTime)) return 'start';
  if (!HHMM.test(r.endTime)) return 'end';
  return toMinutes(r.endTime) > toMinutes(r.startTime) ? null : 'order';
}

/** Aynı gün zaman aralığı çakışan satır çiftleri (anahtar çiftleri). Çakışma engel değil, uyarıdır. */
export function overlaps(rows: SlotRow[]): [string, string][] {
  const out: [string, string][] = [];
  for (let i = 0; i < rows.length; i++) {
    for (let j = i + 1; j < rows.length; j++) {
      const a = rows[i];
      const b = rows[j];
      if (a.dayOfWeek !== b.dayOfWeek || slotError(a) || slotError(b)) continue;
      if (toMinutes(a.startTime) < toMinutes(b.endTime) && toMinutes(b.startTime) < toMinutes(a.endTime)) out.push([a.key, b.key]);
    }
  }
  return out;
}

export const hasErrors = (rows: SlotRow[]): boolean => rows.some((r) => slotError(r) !== null);
