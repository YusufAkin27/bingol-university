/**
 * Rota önyükleme: menü bağlantısının üzerine gelinince (fare/odak/dokunma) sayfa parçası arka planda indirilir, tıklayınca
 * beklenmez. Yükleyiciler `routes.admin.tsx` içindeki `lazy(() => import(...))` ile AYNI modülleri gösterir (aynı parça paylaşılır,
 * ek indirme olmaz). Paket bütçesi için yalnız en çok açılan sayfalar listelenir (her `import()` derlemede bağımlılık listesi
 * taşır: 50 sayfa ~5 KB gzip); az kullanılan sayfalar tıklanınca yüklenir. Bu dosya ayrı tembel parçadır (ilk hover'da inip yüklenir).
 */
type Loader = () => Promise<unknown>;

export const PAGE_LOADERS: Record<string, Loader> = {
  analytics: () => import('../pages/admin/AnalyticsPage'),
  users: () => import('../pages/admin/UsersPage'),
  reports: () => import('../pages/admin/ReportsPage'),
  chatFeed: () => import('../pages/admin/ChatFeedPage'),
  posts: () => import('../pages/admin/PostsAdminPage'),
  communities: () => import('../pages/admin/ClubsManagePage'),
  events: () => import('../pages/admin/EventsAdminPage'),
  tickets: () => import('../pages/admin/TicketsPage'),
  campaigns: () => import('../pages/admin/CampaignsPage'),
  settings: () => import('../pages/admin/SettingsPage'),
};

const started = new Set<string>();

/** Sayfa parçasını arka planda indirir (kimlik başına bir kez; hata sessizce yok sayılır, tıklayınca normal yükleme dener). */
export function prefetchPage(id: string): void {
  if (started.has(id)) return;
  const load = PAGE_LOADERS[id];
  if (!load) return;
  started.add(id);
  // yavaş/kısıtlı bağlantıda (veri tasarrufu) önyükleme yapılmaz
  const conn = (navigator as Navigator & { connection?: { saveData?: boolean } }).connection;
  if (conn?.saveData) {
    started.delete(id);
    return;
  }
  load().catch(() => started.delete(id));
}
