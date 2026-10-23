// SAYFA: Analitik (/admin/analytics/:tab? — overview | growth | engagement | retention | demographics)
// API: GET /api/admin/analytics/overview | registrations | active-users | breakdown?dimension= | engagement | retention
//      | support | push | content (api/analytics.ts, anahtarlar qk.analytics.*). Tarih aralığı için <DateRangePicker>.
// Her sekmeyi ayrı bir bileşen dosyasına (pages/admin/analytics/*.tsx) bölmek serbesttir; bu dosyada yalnızca sekme yönlendirmesi kalsın.
import { useNavigate, useParams } from 'react-router-dom';
import { PlaceholderPage } from '../../components/PlaceholderPage';
import { Tabs } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';

const TABS = ['overview', 'growth', 'engagement', 'retention', 'demographics'] as const;
type Tab = (typeof TABS)[number];

export default function AnalyticsPage() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const { tab } = useParams();
  const current: Tab = (TABS as readonly string[]).includes(tab ?? '') ? (tab as Tab) : 'overview';
  return (
    <PlaceholderPage titleKey="admin.analytics.title" descriptionKey="admin.analytics.subtitle">
      <Tabs
        label={t('admin.analytics.title')}
        value={current}
        onChange={(id) => navigate(paths.admin.analytics(id as Tab))}
        tabs={TABS.map((id) => ({ id, label: t(`admin.analytics.tab.${id}`) }))}
      />
    </PlaceholderPage>
  );
}
