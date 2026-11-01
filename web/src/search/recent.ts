/** Son aramalar (yalnız bu tarayıcıda; localStorage hata verirse bellek yedeği). */
import { readStorage, removeStorage, writeStorage } from '../lib/storage';

const KEY = 'bu.admin.search.recent';
const MAX = 6;

export function readRecent(): string[] {
  try {
    const v = JSON.parse(readStorage('local', KEY) ?? '[]') as unknown;
    return Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string').slice(0, MAX) : [];
  } catch {
    return [];
  }
}

/** Sorguyu başa ekler (tekrarı kaldırır). 2 karakterden kısa sorgular saklanmaz. */
export function pushRecent(query: string): string[] {
  const q = query.trim().replace(/\s+/g, ' ');
  if (q.length < 2) return readRecent();
  const next = [q, ...readRecent().filter((x) => x.toLocaleLowerCase('tr') !== q.toLocaleLowerCase('tr'))].slice(0, MAX);
  writeStorage('local', KEY, JSON.stringify(next));
  return next;
}

export function clearRecent(): void {
  removeStorage('local', KEY);
}
