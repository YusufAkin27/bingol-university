// Kampanya hedef kitlesi, tüm doğrulanmış kullanıcıların kaçı? "1.240 kişi" tek başına anlamsızdır; oran ölçü verir.
// API: GET /api/admin/analytics/overview (verifiedUsers; 5 dk önbellek).
import { useQuery } from '@tanstack/react-query';
import { analyticsApi, qk } from '../../../api';
import { ProgressBar } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useIl } from './il';
import styles from './iletisim.module.css';

export function AudienceShare({ count }: { count: number | null }) {
  const { formatNumber } = useI18n();
  const il = useIl();
  const q = useQuery({
    queryKey: qk.analytics.overview(),
    queryFn: analyticsApi.getOverview,
    staleTime: 5 * 60_000,
  });
  const total = q.data?.verifiedUsers ?? 0;
  // Veri yoksa ya da sayı bilinmiyorsa hiçbir şey çizilmez (uydurma oran yok)
  if (count === null || !q.data || total <= 0) return null;
  const shown = Math.min(count, total);
  const pct = Math.round((shown / total) * 100);
  return (
    <div className={styles.audienceShare} data-search-anchor="compose-audience-share">
      <ProgressBar
        value={shown}
        max={total}
        label={il('admin.il.ca.share', { pct: formatNumber(pct) })}
        tone="info"
        showLabel
      />
      <p className={styles.panelNote}>
        {il('admin.il.ca.shareNote', { n: formatNumber(count), total: formatNumber(total) })}
      </p>
    </div>
  );
}
