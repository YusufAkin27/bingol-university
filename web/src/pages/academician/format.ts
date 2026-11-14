// Tarih/saat/boyut biçimleri (yalnız Türkçe). Saat dilimi tarayıcınındır; sunucu zamanı ISO-8601 gelir.
const LOCALE = 'tr-TR';

const toDate = (v: string | number | Date | null | undefined): Date | null => {
  if (v === null || v === undefined || v === '') return null;
  // yyyy-MM-dd yerel gece yarısıdır (saat dilimi kayması olmasın)
  const d = typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v) ? new Date(`${v}T00:00:00`) : new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};

export function fmtDate(v: string | number | Date | null | undefined): string {
  const d = toDate(v);
  return d ? new Intl.DateTimeFormat(LOCALE, { day: 'numeric', month: 'long', year: 'numeric' }).format(d) : '—';
}
export function fmtDateShort(v: string | number | Date | null | undefined): string {
  const d = toDate(v);
  return d ? new Intl.DateTimeFormat(LOCALE, { day: '2-digit', month: '2-digit', year: 'numeric' }).format(d) : '—';
}
export function fmtDateTime(v: string | number | Date | null | undefined): string {
  const d = toDate(v);
  return d ? new Intl.DateTimeFormat(LOCALE, { dateStyle: 'medium', timeStyle: 'short' }).format(d) : '—';
}
export function fmtTime(v: string | number | Date | null | undefined): string {
  const d = toDate(v);
  return d ? new Intl.DateTimeFormat(LOCALE, { hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(d) : '—';
}

/** 1536 -> "1,5 KB". */
export function fmtSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  const kb = bytes / 1024;
  if (kb < 1024) return `${new Intl.NumberFormat(LOCALE, { maximumFractionDigits: 1 }).format(kb)} KB`;
  return `${new Intl.NumberFormat(LOCALE, { maximumFractionDigits: 1 }).format(kb / 1024)} MB`;
}

/** `<input type="datetime-local">` değeri ("2026-11-20T10:30", yerel) -> ISO-8601 anı. */
export function localInputToIso(v: string): string | undefined {
  if (!v) return undefined;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? undefined : d.toISOString();
}

/** Yerel bugün (yyyy-MM-dd). */
export function todayLocal(now: Date = new Date()): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${now.getFullYear()}-${p(now.getMonth() + 1)}-${p(now.getDate())}`;
}

/** JS getDay (0 = Pazar) -> ISO gün (1 = Pazartesi ... 7 = Pazar). */
export const isoDay = (d: Date): number => (d.getDay() === 0 ? 7 : d.getDay());

/** "HH:mm" -> dakika. */
export function toMinutes(hhmm: string): number {
  const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm.trim());
  return m ? Number(m[1]) * 60 + Number(m[2]) : NaN;
}
