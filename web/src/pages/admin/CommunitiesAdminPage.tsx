// SAYFA: Topluluk onayı (/admin/communities)
// API: GET /api/admin/communities?status=&cursor=&size=, POST /api/admin/communities/{id}/approve | reject {reason} (api/approvals.ts).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function CommunitiesAdminPage() {
  return <PlaceholderPage titleKey="admin.communities.title" descriptionKey="admin.communities.subtitle" />;
}
