// SAYFA: Etkinlik onayı (/admin/events)
// API: GET /api/admin/events?status=&cursor=&size=, POST /api/admin/events/{id}/approve | reject {reason} (api/approvals.ts).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function EventsAdminPage() {
  return <PlaceholderPage titleKey="admin.events.title" descriptionKey="admin.events.subtitle" />;
}
