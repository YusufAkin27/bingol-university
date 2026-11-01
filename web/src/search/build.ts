/**
 * Kayıt defterini çözümler: menü sayfalarından otomatik `page` girdileri + sayfa ajanlarının yazdığı girdiler
 * (index/<grup>.ts) → yol, izin, kırıntı ve simge tamamlanmış `ResolvedEntry` listesi.
 */
import type { TranslationKey } from '../i18n';
import { adminNav } from '../layouts/adminNav';
import { pageInfo } from './pageInfo';
import { registeredEntries } from './registry';
import type { ResolvedEntry, SearchEntry } from './types';

type T = (key: TranslationKey) => string;

export function buildSearchEntries(t: T, extra: readonly SearchEntry[] = registeredEntries): ResolvedEntry[] {
  const pages = new Map<string, { groupId: string; groupLabel: string; label: string; item: (typeof adminNav)[number]['items'][number] }>();
  const out: ResolvedEntry[] = [];

  for (const g of adminNav) {
    const groupLabel = t(g.labelKey);
    for (const item of g.items) {
      const label = t(item.labelKey);
      pages.set(item.id, { groupId: g.id, groupLabel, label, item });
      const info = pageInfo[item.id];
      out.push({
        id: `page.${item.id}`,
        kind: 'page',
        title: label,
        keywords: info?.k ?? [],
        description: info?.d ?? '',
        crumbs: [groupLabel],
        pageId: item.id,
        groupId: g.id,
        path: item.to,
        to: item.to,
        perm: item.perm,
        icon: item.icon,
      });
    }
  }

  for (const e of extra) {
    const p = pages.get(e.page);
    if (!p) continue; // bilinmeyen sayfa: kapsam testi yakalar, çalışma zamanında sessizce atlanır
    const path = e.path ?? p.item.to;
    const crumbs = [p.groupLabel, p.label];
    if (e.section) crumbs.push(e.section);
    out.push({
      id: e.id,
      kind: e.kind,
      title: e.title,
      keywords: e.keywords ?? [],
      description: e.description ?? '',
      crumbs,
      pageId: e.page,
      groupId: p.groupId,
      path,
      anchor: e.anchor,
      to: e.anchor ? `${path}#${e.anchor}` : path,
      perm: e.perm ?? p.item.perm,
      icon: p.item.icon,
    });
  }
  return out;
}
