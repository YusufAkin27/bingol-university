// SAYFA: Raporlar (/admin/reports)
// API: GET /api/admin/reports?status=&cursor=&size= (imeç tabanlı; <LoadMore>), POST /api/admin/reports/{id}/resolve (api/reports.ts),
//      POST /api/admin/users/{id}/suspend (kullanıcı raporlarında).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function ReportsPage() {
  return <PlaceholderPage titleKey="admin.reports.title" descriptionKey="admin.reports.subtitle" />;
}
