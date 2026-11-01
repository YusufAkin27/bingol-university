/**
 * Arama motoruna React köprüsü: ÜST ÇUBUK araması (QuickNav) ile YAN MENÜ süzgeci aynı kancayı kullanır, böylece
 * aynı dizin, aynı sonuç sırası, aynı RBAC kuralı. Dizin `t` değişmedikçe bir kez kurulur (modül düzeyi önbellek).
 */
import { useCallback, useMemo } from 'react';
import { usePermissions } from '../auth/permissions';
import { useI18n } from '../i18n/I18nProvider';
import { buildSearchEntries } from './build';
import { createSearcher, groupHits, type Hit, type HitGroup, type Searcher } from './engine';
import type { ResolvedEntry } from './types';

type TFn = Parameters<typeof buildSearchEntries>[0];

interface Index {
  t: TFn;
  entries: ResolvedEntry[];
  searcher: Searcher<ResolvedEntry>;
}

let cached: Index | null = null;

export function getSearchIndex(t: TFn): Index {
  if (cached && cached.t === t) return cached;
  const entries = buildSearchEntries(t);
  cached = { t, entries, searcher: createSearcher(entries) };
  return cached;
}

export interface MenuMatch {
  /** Sayfa girdisi (menü öğesi) kimliği → eşleşen girdiler (puana göre). */
  pageId: string;
  groupId: string;
  best: number;
  hits: Hit<ResolvedEntry>[];
}

/** Sonuçları menü sayfasına göre toplar (yan menü süzgeci): en iyi puanlı sayfa üstte. */
export function groupByPage(hits: Hit<ResolvedEntry>[]): MenuMatch[] {
  const map = new Map<string, MenuMatch>();
  for (const h of hits) {
    const m = map.get(h.item.pageId);
    if (m) m.hits.push(h);
    else map.set(h.item.pageId, { pageId: h.item.pageId, groupId: h.item.groupId, best: h.score, hits: [h] });
  }
  return [...map.values()].sort((a, b) => b.best - a.best);
}

export interface AdminSearch {
  entries: ResolvedEntry[];
  search: (query: string, limit?: number) => Hit<ResolvedEntry>[];
  groups: (query: string, limit?: number, perGroup?: number) => HitGroup<ResolvedEntry>[];
  suggest: (query: string) => string | null;
}

export function useAdminSearch(): AdminSearch {
  const { t } = useI18n();
  const perms = usePermissions();
  const idx = useMemo(() => getSearchIndex(t), [t]);
  // RBAC: yetkisiz girdi puanlanmadan elenir (sonuçta da öneride de görünmez)
  const filter = useCallback((e: ResolvedEntry) => perms.can(e.perm), [perms]);
  const search = useCallback(
    (query: string, limit = 60) => idx.searcher.search(query, { limit, filter }),
    [idx, filter],
  );
  const groups = useCallback(
    (query: string, limit = 60, perGroup = 12) => groupHits(idx.searcher.search(query, { limit, filter }), perGroup),
    [idx, filter],
  );
  const suggest = useCallback((query: string) => idx.searcher.suggest(query, { filter }), [idx, filter]);
  return useMemo(() => ({ entries: idx.entries, search, groups, suggest }), [idx, search, groups, suggest]);
}
