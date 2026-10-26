// Yemek listesi yardımcıları: kaynak düz metin satırlarını öğün bölümlerine, kalori ve alerjen bilgisine ayırır.
// Kaynak yalnızca string[] verir; başlık/kalori/alerjen satırı yoksa tek "Menü" bölümü gösterilir.

export type MealKey = 'breakfast' | 'lunch' | 'dinner' | 'menu';

export interface Dish {
  text: string;
  kcal: number | null;
}

export interface MealSection {
  key: MealKey;
  dishes: Dish[];
}

export interface ParsedDay {
  sections: MealSection[];
  totalKcal: number | null;
  allergens: string[];
  dishCount: number;
}

const HEADING = /^(kahvaltı|kahvalti|breakfast|öğle(?:\s+yemeği)?|ogle(?:\s+yemegi)?|lunch|akşam(?:\s+yemeği)?|aksam(?:\s+yemegi)?|dinner)\s*:?\s*$/i;
const TOTAL = /^(?:toplam\s*)?(?:kalori|kcal)\s*[:-]?\s*(\d{2,5})(?:\s*kcal)?$/i;
const KCAL = /\(?\s*(\d{2,4})\s*(?:kcal|kalori)\s*\)?/i;
const ALLERGEN = /^alerjen(?:ler)?\s*[:-]\s*(.+)$/i;

function mealOf(heading: string): MealKey {
  const h = heading.toLocaleLowerCase('tr').replace(/\s*:\s*$/, '');
  if (h.startsWith('kahvalt') || h === 'breakfast') return 'breakfast';
  if (h.startsWith('öğle') || h.startsWith('ogle') || h === 'lunch') return 'lunch';
  return 'dinner';
}

export function parseDay(items: string[]): ParsedDay {
  const sections: MealSection[] = [];
  const allergens: string[] = [];
  let totalKcal: number | null = null;
  let current: MealSection | null = null;
  let dishCount = 0;

  for (const raw of items) {
    const line = raw.trim();
    if (!line) continue;
    if (HEADING.test(line)) {
      current = { key: mealOf(line), dishes: [] };
      sections.push(current);
      continue;
    }
    const total = TOTAL.exec(line);
    if (total) {
      totalKcal = Number(total[1]);
      continue;
    }
    const al = ALLERGEN.exec(line);
    if (al) {
      for (const a of al[1].split(/[,/;]/)) {
        const v = a.trim();
        if (v && !allergens.includes(v)) allergens.push(v);
      }
      continue;
    }
    const k = KCAL.exec(line);
    const dish: Dish = { text: (k ? line.replace(KCAL, '') : line).replace(/\s{2,}/g, ' ').trim(), kcal: k ? Number(k[1]) : null };
    if (!dish.text) continue;
    if (!current) {
      current = { key: 'menu', dishes: [] };
      sections.push(current);
    }
    current.dishes.push(dish);
    dishCount += 1;
  }
  return { sections: sections.filter((s) => s.dishes.length > 0), totalKcal, allergens, dishCount };
}

/** Verilen günün haftasını (Pazartesi–Pazar) yyyy-MM-dd olarak döndürür. */
export function weekDates(iso: string): string[] {
  const [y, m, d] = iso.split('-').map(Number);
  const base = new Date(y, m - 1, d);
  const monday = new Date(base);
  monday.setDate(base.getDate() - ((base.getDay() + 6) % 7));
  return Array.from({ length: 7 }, (_, i) => {
    const x = new Date(monday);
    x.setDate(monday.getDate() + i);
    return `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, '0')}-${String(x.getDate()).padStart(2, '0')}`;
  });
}

/** Ayın tüm günleri (yyyy-MM-dd). */
export function daysOfMonth(month: string): string[] {
  const [y, m] = month.split('-').map(Number);
  const n = new Date(y, m, 0).getDate();
  return Array.from({ length: n }, (_, i) => `${month}-${String(i + 1).padStart(2, '0')}`);
}
