// SAYFA: Sözleşme yönetimi (/admin/content/legal)
// API: GET /api/legal (güncel özet), GET /api/admin/legal/{type}/versions, POST /api/admin/legal/{type} {tr,en?,ar?,requireReaccept},
//      GET /api/admin/legal/acceptance-stats (api/legal.ts). Önizleme için <MarkdownText>.
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function LegalAdminPage() {
  return <PlaceholderPage titleKey="admin.legal.title" descriptionKey="admin.legal.subtitle" />;
}
