// Ayarlar sayfası içi arama: ayarları (ve kartları) ad, günlük dil ve eş anlamlılarla bulur; yazım hatasına dayanıklıdır.
// Motor (search/engine) ve dizin (search/registry) YENİDEN KULLANILIR, değiştirilmez.
import { createSearcher, type Searchable, type Searcher } from '../../../search/engine';
import type { SearchEntry } from '../../../search/types';

export interface SettingsSearchItem extends Searchable {
  /** Sayfadaki data-search-anchor değeri (ayar anahtarı ya da kart kimliği) */
  anchor: string;
  /** Kırıntıdaki bölüm adı ("Mağaza ve sürümler") */
  section: string;
}

/** Ayarlar sayfasına ait kayıtlı girdilerden (action hariç) aranabilir liste üretir. */
export function settingsItems(all: readonly SearchEntry[]): SettingsSearchItem[] {
  return all
    // kutunun kendisi ve "son değişiklikler" kartı ayar değildir; eylemler (düğmeler) sonuçta yer almaz
    .filter(
      (e) =>
        e.page === 'settings' &&
        e.anchor &&
        !e.anchor.startsWith('settings-') &&
        e.kind !== 'action' &&
        e.kind !== 'page',
    )
    .map((e) => ({
      id: e.id,
      kind: e.kind,
      title: e.title,
      anchor: e.anchor as string,
      section: e.section ?? '',
      keywords: e.keywords ?? [],
      description: e.description,
      crumbs: e.section ? [e.section] : [],
    }));
}

/** Dizin bir kez kurulur (bileşen useMemo ile saklar). */
export function createSettingsSearcher(items: readonly SettingsSearchItem[]): Searcher<SettingsSearchItem> {
  return createSearcher(items);
}

/** Sorguyu çalıştırır: aynı anchor'a düşen kopyalar elenir, en çok `limit` sonuç. Boş sorgu: boş liste. */
export function searchSettings(searcher: Searcher<SettingsSearchItem>, query: string, limit = 8): SettingsSearchItem[] {
  const q = query.trim();
  if (!q) return [];
  const hits = searcher.search(q, { limit: limit * 2 });
  const seen = new Set<string>();
  const out: SettingsSearchItem[] = [];
  for (const h of hits) {
    if (seen.has(h.item.anchor)) continue;
    seen.add(h.item.anchor);
    out.push(h.item);
    if (out.length >= limit) break;
  }
  return out;
}

/** Değer kısa özeti: boş "—", mantıksal Açık/Kapalı çağıranda çevrilir; uzun metin kırpılır. */
export function valueExcerpt(v: string | undefined, max = 48): string {
  const s = (v ?? '').trim().replace(/\s+/g, ' ');
  if (!s) return '';
  return s.length > max ? `${s.slice(0, max - 1)}…` : s;
}
