/** Erişim engeli girdi doğrulama yardımcıları (saf işlevler). */
import type { BanKind } from '../../../api/accessBans';

export function isIPv4(s: string): boolean {
  const parts = s.split('.');
  return parts.length === 4 && parts.every((p) => /^\d{1,3}$/.test(p) && Number(p) <= 255 && String(Number(p)) === p);
}

export function isIPv6(s: string): boolean {
  if (!/^[0-9a-fA-F:.]+$/.test(s) || s.includes(':::')) return false;
  const dbl = s.split('::');
  if (dbl.length > 2) return false;
  const groups = (part: string) => (part === '' ? [] : part.split(':'));
  const head = groups(dbl[0]);
  const tail = dbl.length === 2 ? groups(dbl[1]) : [];
  const all = [...head, ...tail];
  let units = 0;
  for (let i = 0; i < all.length; i++) {
    const g = all[i];
    if (g.includes('.')) {
      // gömülü IPv4 yalnız sonda
      if (i !== all.length - 1 || !isIPv4(g)) return false;
      units += 2;
    } else {
      if (!/^[0-9a-fA-F]{1,4}$/.test(g)) return false;
      units += 1;
    }
  }
  return dbl.length === 2 ? units < 8 : units === 8;
}

export const isIp = (s: string) => isIPv4(s) || isIPv6(s);

export function isCidr(s: string): boolean {
  const i = s.indexOf('/');
  if (i < 0) return false;
  const addr = s.slice(0, i);
  const bits = s.slice(i + 1);
  if (!/^\d{1,3}$/.test(bits)) return false;
  const n = Number(bits);
  if (isIPv4(addr)) return n <= 32;
  if (isIPv6(addr)) return n <= 128;
  return false;
}

export const isDeviceId = (s: string) => s.length >= 8 && s.length <= 128 && !/\s/.test(s);

/** Türe göre değer geçerli mi (USER için değer kullanıcı kimliğidir). */
export function isValidBanValue(kind: BanKind, raw: string): boolean {
  const v = raw.trim();
  switch (kind) {
    case 'IP':
      return isIp(v);
    case 'CIDR':
      return isCidr(v);
    case 'DEVICE':
      return isDeviceId(v);
    case 'USER':
      return /^\d+$/.test(v);
  }
}

/** Satır satır liste: boşlukları atar, `#` yorumlarını yoksayar. */
export function parseLines(text: string): string[] {
  return text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
}

export const isIpOrCidr = (s: string) => isIp(s) || isCidr(s);

/** Tarih (yyyy-mm-dd) -> günün sonu ISO; geçmişse null. */
export function endOfDayIso(date: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return null;
  const d = new Date(`${date}T23:59:59`);
  return Number.isNaN(d.getTime()) || d.getTime() <= Date.now() ? null : d.toISOString();
}

/** Cihaz özetini kısaltır (ilk 8 + … + son 4). */
export function shortDevice(v: string): string {
  return v.length <= 16 ? v : `${v.slice(0, 8)}…${v.slice(-4)}`;
}
