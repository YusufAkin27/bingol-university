// SAYFA: Talep ayrıntısı (/admin/support/tickets/:id)
// API: GET /api/admin/support/tickets/{id}, POST .../{id}/reply {text}, POST .../{id}/close (api/support.ts).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function TicketDetailPage() {
  return <PlaceholderPage titleKey="admin.tickets.detail.title" />;
}
