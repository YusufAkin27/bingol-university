/**
 * Dil önekli URL yardımcıları (saf işlevler; React/DOM'a bağlı değildir, önrender betiği de kullanır).
 * Tanıtım sitesi `/tr/...`, `/en/...`, `/ar/...` altında yaşar; yönetim paneli (`/admin/**`) önekten muaftır.
 */
import { ADMIN_BASE } from '../adminBase';
import { isLang, type Lang } from './lang';

/** `/en/news/3` → `{ lang: 'en', rest: '/news/3' }`; önek yoksa `lang: null`. */
export function splitLangPath(pathname: string): { lang: Lang | null; rest: string } {
  const m = /^\/([A-Za-z]{2})(?=\/|$)(.*)$/.exec(pathname);
  if (m && isLang(m[1])) return { lang: m[1], rest: m[2] || '/' };
  return { lang: null, rest: pathname };
}

/** Yönetim paneli yolu mu (dil öneki almaz). */
export function isAdminPath(pathname: string): boolean {
  return [ADMIN_BASE, '/admin'].some((b) => pathname === b || pathname.startsWith(`${b}/`));
}

function splitTail(to: string): [string, string] {
  const i = to.search(/[?#]/);
  return i < 0 ? [to, ''] : [to.slice(0, i), to.slice(i)];
}

/**
 * Mantıksal site yoluna (`/privacy`) dil öneki ekler (`/tr/privacy`). Dış bağlantı, göreli yol,
 * yönetim yolu ve zaten önekli yol değişmeden döner. `/` → `/<lang>`.
 */
export function localizePath(to: string, lang: Lang): string {
  if (!to.startsWith('/') || to.startsWith('//')) return to;
  const [path, tail] = splitTail(to);
  if (isAdminPath(path) || splitLangPath(path).lang) return to;
  return `/${lang}${path === '/' ? '' : path}${tail}`;
}

/** Aynı sayfanın başka dildeki adresi (`/tr/news/3?x=1` → `/en/news/3?x=1`); önek yoksa önek eklenir. */
export function switchLangPath(pathWithTail: string, lang: Lang): string {
  const [path, tail] = splitTail(pathWithTail);
  const { rest } = splitLangPath(path);
  return `/${lang}${rest === '/' ? '' : rest}${tail}`;
}
