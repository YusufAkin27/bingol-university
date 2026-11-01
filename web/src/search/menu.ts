/**
 * Yan menü süzgecinin yükleme sınırı: AdminLayout bu modülü ilk yazışta dinamik içe aktarır (motor + dizin + vurgulama
 * ana yönetim paketine girmez). Aynı motor/dizin/RBAC kuralı QuickNav ile ortaktır.
 */
import type { Permission } from '../api/rbac';
import { getSearchIndex, groupByPage, type MenuMatch } from './useAdminSearch';

export { Highlight } from './Highlight';
export type { MenuMatch };

type TFn = Parameters<typeof getSearchIndex>[0];

export function searchMenu(t: TFn, can: (perm?: Permission | string | null) => boolean, query: string, limit = 80): MenuMatch[] {
  const idx = getSearchIndex(t);
  return groupByPage(idx.searcher.search(query, { limit, filter: (e) => can(e.perm) }));
}
