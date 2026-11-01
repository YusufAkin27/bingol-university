/** Yerel takvim gününü `yyyy-MM-dd` olarak yazar (UTC kayması olmadan). */
export function isoDate(d: Date): string {
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
}

/** Bugün dahil son `days` günlük aralık (örn. 7 → bugün ve önceki 6 gün). */
export function lastDays(days: number, now = new Date()): { from: string; to: string } {
  const from = new Date(now);
  from.setDate(from.getDate() - (days - 1));
  return { from: isoDate(from), to: isoDate(now) };
}

/** Yönetim panelinin iş günü saat dilimi (sunucu analitik gün sınırları da bu dilimdedir). */
export const PANEL_TIME_ZONE = 'Europe/Istanbul';

/** Verilen anın Europe/Istanbul takvim gününü `yyyy-MM-dd` yazar (tarayıcı yerel saatinden bağımsız). */
export function istanbulDate(now = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: PANEL_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

/** İstanbul gününden `days` gün önceki takvim günü (saat dilimi/yaz saati kaymasız: salt tarih aritmetiği). */
export function istanbulDaysAgo(days: number, now = new Date()): string {
  const [y, m, d] = istanbulDate(now).split('-').map(Number);
  const t = new Date(Date.UTC(y, m - 1, d - days));
  return `${t.getUTCFullYear()}-${String(t.getUTCMonth() + 1).padStart(2, '0')}-${String(t.getUTCDate()).padStart(2, '0')}`;
}

/** İstanbul gününe göre dün. */
export function istanbulYesterday(now = new Date()): string {
  return istanbulDaysAgo(1, now);
}

/** Bugün dahil son `days` günlük aralık, İstanbul gününe göre. */
export function lastDaysIstanbul(days: number, now = new Date()): { from: string; to: string } {
  return { from: istanbulDaysAgo(days - 1, now), to: istanbulDate(now) };
}
