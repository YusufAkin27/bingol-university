// Genel bakış: "Kitlenin ne kadarı aktif?" Kayıtlı > bu ay > bu hafta > bugün giren kişi: tek bakışta çubuklar (eski 4 ayrı sayı kutusunun yerine).
import type { UseQueryResult } from '@tanstack/react-query';
import type { AnalyticsOverview } from '../../../api/types';
import { Card, ErrorState, Insight, RankedBars } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import styles from './dashboard.module.css';
import { audienceLevels, sharePercent } from './transform';

export function AudiencePanel({ overview }: { overview: UseQueryResult<AnalyticsOverview> }) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const o = overview.data;
  const levels = o ? audienceLevels(o) : undefined;
  const month = o ? sharePercent(o.activeUsers.mau, o.totalUsers) : null;

  return (
    <Card title={t('admin.genel.audience.title')} data-testid="audience-panel" data-search-anchor="dash-audience">
      {overview.isError ? (
        <ErrorState compact description={errorMessage(i18n, overview.error)} onRetry={() => void overview.refetch()} />
      ) : (
        <div className={styles.audienceBody}>
          {o && o.totalUsers > 0 && month !== null && (
            <Insight
              tone="info"
              parts={t('admin.genel.audience.sentence', {
                total: formatNumber(o.totalUsers),
                pct: formatNumber(month),
                week: formatNumber(o.activeUsers.wau),
              })}
            />
          )}
          <RankedBars
            ariaLabel={t('admin.genel.audience.title')}
            loading={!o}
            limit={0}
            order="desc"
            emptyLabel={t('admin.genel.audience.empty')}
            items={levels?.map((l) => {
              const share = o ? sharePercent(l.value, o.totalUsers) : null;
              return {
                key: l.key,
                label: t(`admin.genel.audience.${l.key}`),
                value: l.value,
                hint: l.key !== 'total' && share !== null ? t('admin.genel.audience.share', { pct: formatNumber(share) }) : undefined,
              };
            })}
          />
        </div>
      )}
    </Card>
  );
}
