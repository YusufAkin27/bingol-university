// Genel bakış: moderasyon sayaçları. API: GET /api/admin/moderation/appeals?status=OPEN&size=50 ve
// GET /api/admin/moderation/suspend-recommendations?status=OPEN&size=50 (api/moderation.ts). Genel bakış (analytics/overview) ucunda
// bu sayılar yok; ilk sayfa sayılır, sonraki sayfa varsa "50+" gösterilir. Hata veren sayaç "—" gösterir, diğerlerini bozmaz.
import { useQuery } from '@tanstack/react-query';
import { moderationApi, qk } from '../../../api';
import { StatCard } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { countLabel } from '../moderation/modLogic';

const SIZE = 50;

export function ModerationCounters() {
  const { t } = useI18n();
  const appeals = useQuery({
    queryKey: [...qk.moderation.appeals('OPEN'), 'count'],
    queryFn: () => moderationApi.listAppeals({ status: 'OPEN', size: SIZE }),
    retry: false,
  });
  const recs = useQuery({
    queryKey: [...qk.moderation.recommendations('OPEN'), 'count'],
    queryFn: () => moderationApi.listSuspendRecommendations({ status: 'OPEN', size: SIZE }),
    retry: false,
  });
  const label = (q: { data?: { items: unknown[]; nextCursor: number | null } }) =>
    q.data ? countLabel(q.data.items.length, q.data.nextCursor !== null) : '—';
  return (
    <>
      <StatCard
        title={t('admin.dashboard.kpi.openAppeals')}
        value={label(appeals)}
        loading={appeals.isLoading}
      />
      <StatCard
        title={t('admin.dashboard.kpi.openSuspend')}
        value={label(recs)}
        loading={recs.isLoading}
      />
    </>
  );
}
