// SAYFA: Haber yönetimi (/admin/content/news)
// API: GET /api/admin/news?q=&type=&hidden=&page=&size=, PATCH /api/admin/news/{id} {hidden} (api/news.ts),
//      POST /api/admin/sync, POST /api/admin/sync-menu, GET /api/status (api/settings.ts: triggerNewsSync, getSyncStatus).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function NewsAdminPage() {
  return <PlaceholderPage titleKey="admin.news.title" descriptionKey="admin.news.subtitle" />;
}
