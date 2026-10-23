// SAYFA: Kullanıcı ayrıntısı (/admin/users/:id)
// API: GET /api/admin/users/{id}, PATCH /api/admin/users/{id}/role, DELETE /api/admin/users/{id},
//      POST /api/admin/users/{id}/suspend | unsuspend (hepsi api/users.ts). KVKK: yalnızca günlük açılış sayıları gösterilir.
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function UserDetailPage() {
  return <PlaceholderPage titleKey="admin.users.detail.title" />;
}
