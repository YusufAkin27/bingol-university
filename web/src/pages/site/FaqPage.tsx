// SAYFA: Sık sorulan sorular (/faq)
// API: GET /api/faq (herkese açık, kategoriye göre gruplu, Accept-Language'e göre) → api/faq.ts `listFaq`, qk.faq.public(lang).
import { PlaceholderPage } from '../../components/PlaceholderPage';

export default function FaqPage() {
  return <PlaceholderPage layout="site" titleKey="site.faq.title" />;
}
