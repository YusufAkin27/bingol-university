export type EventTiming = 'past' | 'soon' | 'later';
export const SOON_HOURS = 48;

/** Başlangıcı geçmiş = 'past'; 48 saat içinde = 'soon'; aksi 'later'. */
export function eventTiming(startsAt: string, now: Date = new Date()): EventTiming {
  const start = new Date(startsAt).getTime();
  if (Number.isNaN(start)) return 'later';
  const diff = start - now.getTime();
  if (diff < 0) return 'past';
  return diff <= SOON_HOURS * 3600 * 1000 ? 'soon' : 'later';
}

/** Başlangıca kalan süreyi (saat/gün) yerel dilde yazar: "3 saat sonra". */
export function relativeStart(startsAt: string, locale: string, now: Date = new Date()): string {
  const diffMin = Math.round((new Date(startsAt).getTime() - now.getTime()) / 60000);
  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' });
  const abs = Math.abs(diffMin);
  if (abs < 60) return rtf.format(diffMin, 'minute');
  if (abs < 60 * 24) return rtf.format(Math.round(diffMin / 60), 'hour');
  return rtf.format(Math.round(diffMin / (60 * 24)), 'day');
}
