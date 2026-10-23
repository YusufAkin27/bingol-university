// SAYFA: Geri bildirim ve öneriler (/admin/support/feedback)
// API: GET /api/admin/feedback?status=&category=&cursor=&size=, PATCH /api/admin/feedback/{id} {status, adminResponse, publicVisible} (api/feedback.ts).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function FeedbackPage() {
  return <PlaceholderPage titleKey="admin.feedback.title" descriptionKey="admin.feedback.subtitle" />;
}
