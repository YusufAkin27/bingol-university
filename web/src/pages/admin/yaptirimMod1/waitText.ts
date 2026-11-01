import type { GT } from './dict';
import { DAY_MS, HOUR_MS } from './queueLogic';

/** Bekleme süresini düz Türkçe yazar: "1 saatten az", "5 saat", "3 gün". */
export function waitText(ms: number | null, gt: GT, formatNumber: (n: number) => string): string {
  if (ms === null) return '–';
  if (ms < HOUR_MS) return gt('admin.mod1.wait.lessHour');
  if (ms < DAY_MS) return gt('admin.mod1.wait.hours', { n: formatNumber(Math.floor(ms / HOUR_MS)) });
  return gt('admin.mod1.wait.days', { n: formatNumber(Math.floor(ms / DAY_MS)) });
}
