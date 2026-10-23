// SAYFA: Denetim kaydı (/admin/audit)
// API: GET /api/admin/audit?page=&size=&adminId=&method=&q= (sayfa tabanlı; <Pagination>) (api/audit.ts).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function AuditPage() {
  return <PlaceholderPage titleKey="admin.audit.title" descriptionKey="admin.audit.subtitle" />;
}
