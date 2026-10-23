// SAYFA: Ayarlar (/admin/settings)
// API: GET /api/admin/settings, PUT /api/admin/settings/{key} {value} (api/settings.ts). Anahtarlar: mağaza bağlantıları (store_url_*),
//      iletişim, banner_text_*, maintenance_mode, min/latest_version_*, faculties (`;` ile ayrılmış).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function SettingsPage() {
  return <PlaceholderPage titleKey="admin.settings.title" descriptionKey="admin.settings.subtitle" />;
}
