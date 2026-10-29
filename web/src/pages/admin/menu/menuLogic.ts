// Menü fotoğrafı yönetimi için saf yardımcılar (ay aralığı, istemci tarafı dosya doğrulaması).
export const MENU_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
/** İstemci sınırı; sunucu da doğrular (nihai karar sunucuda). */
export const MENU_IMAGE_MAX_BYTES = 5 * 1024 * 1024;

export type ImageProblem = 'type' | 'size' | 'empty';

export function validateMenuImage(file: { type: string; size: number }): ImageProblem | null {
  if (!(MENU_IMAGE_TYPES as readonly string[]).includes(file.type)) return 'type';
  if (file.size <= 0) return 'empty';
  if (file.size > MENU_IMAGE_MAX_BYTES) return 'size';
  return null;
}

const MONTH_RE = /^(\d{4})-(0[1-9]|1[0-2])$/;

export function isMonth(v: string): boolean {
  return MONTH_RE.test(v);
}

/** 'yyyy-MM' -> ayın ilk ve son günü ('yyyy-MM-dd'). */
export function monthRange(month: string): { from: string; to: string } {
  const m = MONTH_RE.exec(month);
  if (!m) throw new Error('invalid month');
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const last = new Date(Date.UTC(y, mo, 0)).getUTCDate();
  return { from: `${month}-01`, to: `${month}-${String(last).padStart(2, '0')}` };
}

export function currentMonth(now: Date = new Date()): string {
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

// ---- Kalori ----
export const MAX_KCAL = 5000;

export interface DishLike {
  name: string;
  kcal: number | null;
}

/** Sunucu yanıtında `dishes` yoksa (eski sürüm) yemekleri kalorisiz üretir. */
export function dishesOf(day: { items: string[]; dishes?: DishLike[] }): DishLike[] {
  return day.dishes && day.dishes.length === day.items.length
    ? day.dishes
    : day.items.map((name) => ({ name, kcal: null }));
}

/** Alan metni -> kalori. Boş = null (sil); 0-5000 tam sayı dışı = geçersiz. */
export function parseKcal(raw: string): { ok: true; value: number | null } | { ok: false } {
  const v = raw.trim().replace(/\s*kcal$/i, '');
  if (v === '' || v === '-') return { ok: true, value: null };
  if (!/^\d{1,4}$/.test(v)) return { ok: false };
  const n = Number(v);
  return n <= MAX_KCAL ? { ok: true, value: n } : { ok: false };
}

export function sumKcal(values: (number | null)[]): { total: number | null; known: number; complete: boolean } {
  const known = values.filter((v): v is number => v !== null);
  return {
    total: known.length === 0 ? null : known.reduce((a, b) => a + b, 0),
    known: known.length,
    complete: values.length > 0 && known.length === values.length,
  };
}

/** 'yyyy-MM-dd' ya da 'd.M.yyyy' -> 'yyyy-MM-dd' (geçersiz takvim günü null). */
export function normalizeDate(raw: string): string | null {
  const v = raw.trim();
  let y: number, m: number, d: number;
  let x = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(v);
  if (x) {
    y = Number(x[1]);
    m = Number(x[2]);
    d = Number(x[3]);
  } else if ((x = /^(\d{1,2})\.(\d{1,2})\.(\d{4})$/.exec(v))) {
    d = Number(x[1]);
    m = Number(x[2]);
    y = Number(x[3]);
  } else {
    return null;
  }
  const dt = new Date(Date.UTC(y, m - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) return null;
  return `${String(y).padStart(4, '0')}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

export type CalorieLineError = 'format' | 'date' | 'kcal';

export interface ParsedCalories {
  days: { date: string; items: { name: string; kcal: number | null }[] }[];
  count: number;
  errors: { line: number; reason: CalorieLineError }[];
}

/**
 * Yapıştırılan metin: her satır `tarih;yemek adı;kcal` (ya da sekmeyle). Son sütun kalori (boş/-: sil), ilk sütun tarih,
 * aradaki her şey yemek adı. Boş satırlar ve ilk satırdaki "tarih..." başlığı atlanır. Aynı gün+yemek tekrarında sonuncu geçerli.
 */
export function parseCalorieText(text: string): ParsedCalories {
  const byDate = new Map<string, Map<string, { name: string; kcal: number | null }>>();
  const errors: ParsedCalories['errors'] = [];
  text.split(/\r?\n/).forEach((rawLine, idx) => {
    const line = rawLine.trim();
    if (line === '') return;
    if (idx === 0 && /^tarih/i.test(line)) return;
    const parts = line.includes('\t') ? line.split('\t') : line.split(';');
    if (parts.length < 3 || parts.slice(1, -1).join(';').trim() === '') {
      errors.push({ line: idx + 1, reason: 'format' });
      return;
    }
    const date = normalizeDate(parts[0]);
    if (!date) {
      errors.push({ line: idx + 1, reason: 'date' });
      return;
    }
    const k = parseKcal(parts[parts.length - 1]);
    if (!k.ok) {
      errors.push({ line: idx + 1, reason: 'kcal' });
      return;
    }
    const name = parts.slice(1, -1).join(';').trim();
    const day = byDate.get(date) ?? new Map();
    day.set(name.toLocaleLowerCase('tr'), { name, kcal: k.value });
    byDate.set(date, day);
  });
  const days = [...byDate.entries()].map(([date, m]) => ({ date, items: [...m.values()] }));
  return { days, count: days.reduce((n, d) => n + d.items.length, 0), errors };
}
