/**
 * Sözlük kayıt defteri (çalışma zamanı). Sözlükler dil başına ve kapsam başına (site | admin) AYRI parçalardır
 * (`bundles/*`); ziyaretçi yalnız kendi dilinin site parçasını, yönetici ayrıca `admin.tr` parçasını indirir.
 * Burada statik sözlük içe aktarımı YOKTUR: eski `index.ts` gibi hepsini ana pakete çekmemek için.
 * Testler ve önrender hepsini eşzamanlı yükleyen `all.ts` kullanır (kaydı orası yapar).
 */
import type { Lang } from './lang';

export type DictScope = 'site' | 'admin';
export type TParams = Record<string, string | number>;
type Entries = Record<string, string>;

const store: Partial<Record<Lang, Entries>> = {};
const done = new Set<string>();
const inflight = new Map<string, Promise<void>>();

type Loader = () => Promise<{ default: Entries }>;
const loaders: Record<string, Loader> = {
  'site.tr': () => import('./bundles/site.tr'),
  'site.en': () => import('./bundles/site.en'),
  'site.ar': () => import('./bundles/site.ar'),
  // Yönetim paneli yalnız Türkçedir: tek admin parçası var
  'admin.tr': () => import('./bundles/admin.tr'),
};

/** Kapsam + dil → parça anahtarı. Yönetim kapsamı dile bakmaz (yalnız tr). */
const partKey = (scope: DictScope, lang: Lang): string => (scope === 'admin' ? 'admin.tr' : `site.${lang}`);

/** Sözlük girdilerini kaydeder (eşzamanlı yol: testler, önrender). */
export function registerDictionary(scope: DictScope, lang: Lang, entries: Entries): void {
  store[lang] = { ...store[lang], ...entries };
  done.add(`${scope}.${lang}`);
}

export function isLoaded(lang: Lang, scope: DictScope = 'site'): boolean {
  return done.has(partKey(scope, lang));
}

/** Parçayı yükler (aynı anda tek istek); hata durumunda reddeder, sonraki çağrı yeniden dener. */
export function loadDictionary(lang: Lang, scope: DictScope = 'site'): Promise<void> {
  const key = partKey(scope, lang);
  if (done.has(key)) return Promise.resolve();
  const running = inflight.get(key);
  if (running) return running;
  const loader = loaders[key];
  if (!loader) return Promise.reject(new Error(`bilinmeyen sözlük parçası: ${key}`));
  const p = loader()
    .then((m) => {
      const target = scope === 'admin' ? 'tr' : lang;
      store[target] = { ...store[target], ...m.default };
      done.add(key);
    })
    .finally(() => {
      inflight.delete(key);
    });
  inflight.set(key, p);
  return p;
}

/** Dinamik (çalışma zamanında üretilen) anahtar, ilgili dilin ya da Türkçe yedeğin yüklü sözlüğünde var mı. */
export function hasKey(key: string, lang?: Lang): boolean {
  const has = (l: Lang) => Object.prototype.hasOwnProperty.call(store[l] ?? {}, key);
  return (lang ? has(lang) : false) || has('tr');
}

/** `{ad}` yer tutucularını doldurur. Eksik anahtarda yüklüyse Türkçeye, o da yoksa anahtarın kendisine düşer. */
export function translate(lang: Lang, key: string, params?: TParams): string {
  const raw = store[lang]?.[key] ?? store.tr?.[key] ?? key;
  if (!params) return raw;
  return raw.replace(/\{(\w+)\}/g, (m, name: string) => (name in params ? String(params[name]) : m));
}

/** Test yardımcıları: kayıt defterini boşaltır / bir parçanın yükleyicisini değiştirir. */
export function __resetDictionariesForTests(): void {
  for (const k of Object.keys(store)) delete store[k as Lang];
  done.clear();
  inflight.clear();
}
export function __setDictionaryLoaderForTests(key: string, loader: Loader | null): () => void {
  const prev = loaders[key];
  if (loader) loaders[key] = loader;
  else delete loaders[key];
  return () => {
    if (prev) loaders[key] = prev;
    else delete loaders[key];
  };
}
