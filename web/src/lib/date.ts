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
