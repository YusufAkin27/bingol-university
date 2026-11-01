/**
 * Son ziyaret edilen ve sık kullanılan (yıldızlı) panel sayfaları. Yalnız bu tarayıcıda tutulur (localStorage, hata toleranslı;
 * erişilemezse bellek yedeği). Menü sayfası kimliği (`adminNav` öğe `id`) saklanır, böylece sayfa adı/yolu değişse de bozulmaz.
 * Üst çubuk yıldızı, yan menü "Sık kullanılanlar" grubu ve Ctrl+K boş ekranı aynı kaynağı okur (`useSyncExternalStore`).
 */
import { useSyncExternalStore } from 'react';
import { readStorage, removeStorage, writeStorage } from '../lib/storage';

const RECENT_KEY = 'bu.admin.pages.recent';
const FAV_KEY = 'bu.admin.pages.fav';
export const MAX_RECENT = 6;
export const MAX_FAV = 8;

const listeners = new Set<() => void>();
let version = 0;
let cache: { recent: string[]; fav: string[] } | null = null;

function parse(raw: string | null, max: number): string[] {
  try {
    const v = JSON.parse(raw ?? '[]') as unknown;
    return Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string').slice(0, max) : [];
  } catch {
    return [];
  }
}

function load(): { recent: string[]; fav: string[] } {
  if (!cache) cache = { recent: parse(readStorage('local', RECENT_KEY), MAX_RECENT), fav: parse(readStorage('local', FAV_KEY), MAX_FAV) };
  return cache;
}

function commit(next: { recent: string[]; fav: string[] }) {
  cache = next;
  writeStorage('local', RECENT_KEY, JSON.stringify(next.recent));
  writeStorage('local', FAV_KEY, JSON.stringify(next.fav));
  version += 1;
  listeners.forEach((l) => l());
}

export function readRecentPages(): string[] {
  return load().recent;
}

export function readFavoritePages(): string[] {
  return load().fav;
}

/** Sayfa ziyaretini kaydeder: başa alır, tekrarı kaldırır. Aynı sayfa üst üste kaydedilmez (yenileme/sekme değişimi). */
export function recordPageVisit(id: string): void {
  const cur = load();
  if (cur.recent[0] === id) return;
  commit({ ...cur, recent: [id, ...cur.recent.filter((x) => x !== id)].slice(0, MAX_RECENT) });
}

/** Yıldızı açar/kapatır. Sınır aşılırsa en eski favori düşer. Dönüş: yeni durum (yıldızlı mı). */
export function toggleFavoritePage(id: string): boolean {
  const cur = load();
  if (cur.fav.includes(id)) {
    commit({ ...cur, fav: cur.fav.filter((x) => x !== id) });
    return false;
  }
  commit({ ...cur, fav: [id, ...cur.fav].slice(0, MAX_FAV) });
  return true;
}

/** Testler için: bellek önbelleğini (ve `clearStorage` ise depodaki kayıtları) sıfırlar. */
export function resetPageMemory(clearStorage = true): void {
  if (clearStorage) {
    removeStorage('local', RECENT_KEY);
    removeStorage('local', FAV_KEY);
  }
  cache = null;
  version += 1;
  listeners.forEach((l) => l());
}

function subscribe(cb: () => void) {
  listeners.add(cb);
  return () => listeners.delete(cb);
}

const snapshot = () => version;

/** Bileşenlerde canlı okuma: değişince yeniden çizer. */
export function usePageMemory(): { recent: string[]; fav: string[] } {
  useSyncExternalStore(subscribe, snapshot, snapshot);
  return load();
}
