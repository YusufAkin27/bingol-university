// Yemek menüsü kalori grafiği için saf mantık: günlük toplam çubukları, kapsama, eksik gün özeti.
import { dishesOf, type DishLike } from './menuLogic';

export type KcalBarState = 'full' | 'partial' | 'none';

export interface KcalBar {
  date: string;
  /** Ayın günü (1-31). */
  day: number;
  state: KcalBarState;
  /** Kalorisi bilinen yemeklerin toplamı. */
  kcal: number;
  /** Kalorisi girilmemiş yemek sayısı. */
  missing: number;
  dishes: number;
  /** Çubuk yüksekliği: ayın en yüksek günü 100 (bilinen kısım üzerinden). */
  pct: number;
}

export interface KcalSeries {
  bars: KcalBar[];
  maxKcal: number;
  /** Tamamı girilmiş günlerin ortalaması; hiç tam gün yoksa null. */
  avgFull: number | null;
  maxBar: KcalBar | null;
  dishTotal: number;
  dishKnown: number;
  /** En az bir yemeği kalorisiz gün sayısı. */
  daysMissing: number;
  firstMissingDate: string | null;
}

interface DayLike {
  date: string;
  items: string[];
  dishes?: DishLike[];
}

export function kcalSeries(days: DayLike[]): KcalSeries {
  const sorted = [...days].sort((a, b) => a.date.localeCompare(b.date));
  const raw = sorted.map((d) => {
    const dishes = dishesOf(d);
    const known = dishes.filter((x) => x.kcal !== null);
    const kcal = known.reduce((s, x) => s + (x.kcal ?? 0), 0);
    const missing = dishes.length - known.length;
    const state: KcalBarState = known.length === 0 ? 'none' : missing === 0 ? 'full' : 'partial';
    return { date: d.date, day: Number(d.date.slice(8, 10)), state, kcal, missing, dishes: dishes.length };
  });
  const maxKcal = Math.max(0, ...raw.map((r) => r.kcal));
  const bars: KcalBar[] = raw.map((r) => ({ ...r, pct: maxKcal > 0 ? Math.round((r.kcal / maxKcal) * 100) : 0 }));
  const full = bars.filter((b) => b.state === 'full');
  const maxBar = bars.reduce<KcalBar | null>((m, b) => (b.kcal > 0 && (!m || b.kcal > m.kcal) ? b : m), null);
  const dishTotal = bars.reduce((s, b) => s + b.dishes, 0);
  const dishMissing = bars.reduce((s, b) => s + b.missing, 0);
  const missingDays = bars.filter((b) => b.missing > 0 || (b.state === 'none' && b.dishes > 0));
  return {
    bars,
    maxKcal,
    avgFull: full.length ? Math.round(full.reduce((s, b) => s + b.kcal, 0) / full.length) : null,
    maxBar,
    dishTotal,
    dishKnown: dishTotal - dishMissing,
    daysMissing: missingDays.length,
    firstMissingDate: missingDays[0]?.date ?? null,
  };
}
