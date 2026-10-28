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
