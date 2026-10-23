// SAYFA: Yasal metinler (/legal/:type — terms | privacy | kvkk | community-rules)
// API: GET /api/legal/{type} (herkese açık; Accept-Language'e göre, yoksa tr) → api/legal.ts `getLegal`, `parseLegalType`.
// Metni <MarkdownText> ile göster (HTML enjekte edilmez).
import { useParams } from 'react-router-dom';
import { parseLegalType } from '../../api/legal';
import { PlaceholderPage } from '../../components/PlaceholderPage';
import { useI18n } from '../../i18n/I18nProvider';
import NotFoundPage from './NotFoundPage';

export default function LegalPage() {
  const { t } = useI18n();
  const { type } = useParams();
  const parsed = parseLegalType(type);
  if (!parsed) return <NotFoundPage />;
  return <PlaceholderPage layout="site" titleKey="site.nav.home" title={t(`legal.title.${parsed}`)} />;
}
