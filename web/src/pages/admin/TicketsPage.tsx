// SAYFA: Destek talepleri (/admin/support/tickets)
// API: GET /api/admin/support/tickets?status=&cursor=&size= (api/support.ts `listTickets`; imeç tabanlı).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function TicketsPage() {
  return <PlaceholderPage titleKey="admin.tickets.title" descriptionKey="admin.tickets.subtitle" />;
}
