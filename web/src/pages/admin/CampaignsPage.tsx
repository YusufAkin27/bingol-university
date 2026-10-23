// SAYFA: Kampanyalar (/admin/campaigns)
// API: GET /api/admin/push/campaigns?cursor=&size=, GET .../{id}, POST .../{id}/cancel (api/campaigns.ts); GET /api/admin/analytics/push.
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function CampaignsPage() {
  return <PlaceholderPage titleKey="admin.campaigns.title" descriptionKey="admin.campaigns.subtitle" />;
}
