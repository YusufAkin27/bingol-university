// SAYFA: Yeni kampanya (/admin/campaigns/new)
// API: POST /api/admin/push/audience-count (önizleme), POST /api/admin/push/campaigns (api/campaigns.ts).
//      Metin tr zorunlu, en/ar isteğe bağlı; başlık ≤100, gövde ≤300 karakter.
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function CampaignComposePage() {
  return <PlaceholderPage titleKey="admin.campaigns.compose.title" />;
}
