// SAYFA: Genel bakış (/admin)
// API: GET /api/admin/analytics/overview, /registrations, /active-users, /support, /content (api/analytics.ts), GET /api/admin/stats.
//      Grafikler için components/charts kullan (recharts yalnızca bu sayfa import edince yüklenir).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function DashboardPage() {
  return <PlaceholderPage titleKey="admin.dashboard.title" descriptionKey="admin.dashboard.subtitle" />;
}
