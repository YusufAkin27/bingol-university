// SAYFA: Kullanıcılar (/admin/users)
// API: GET /api/admin/users (filtre/sayfa/sıralama; api/users.ts `listUsers`), GET /api/admin/users/export.csv (`exportUsersCsv`),
//      GET /api/faculties (fakülte filtresi; api/appInfo.ts `getFaculties`).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function UsersPage() {
  return <PlaceholderPage titleKey="admin.users.title" descriptionKey="admin.users.subtitle" />;
}
