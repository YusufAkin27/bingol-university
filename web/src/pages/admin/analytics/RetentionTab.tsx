import { useQuery } from '@tanstack/react-query';
import { getRetention } from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import { Card, EmptyState, Insight, ProgressRing } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './analytics.module.css';
import { Async, CohortHeat } from './parts';

export default function RetentionTab() {
  const { t, formatNumber } = useI18n();
  const q = useQuery({ queryKey: qk.analytics.retention(), queryFn: getRetention });
  return (
    <div className={styles.panel}>
      <Card title={t('admin.v2p.anl.retention.title')} data-search-anchor="anl-retention">
        <p className={styles.muted} style={{ marginBlockEnd: 'var(--space-4)' }}>
          {t('admin.analytics.retention.desc')} {t('admin.v2p.anl.retention.example')}
        </p>
        <Async query={q} height={320} title={t('admin.v2p.anl.retention.title')}>
          {(d) => {
            if (d.cohorts.length === 0) {
              return (
                <EmptyState
                  compact
                  icon="chart"
                  title={t('admin.analytics.retention.empty')}
                  description={t('admin.v2p.anl.retention.emptyHint')}
                />
              );
            }
            const mature = d.cohorts.filter((c) => c.size > 0);
            const avg = (k: 'd1' | 'd7' | 'd30') =>
              mature.length ? mature.reduce((s, c) => s + c[k], 0) / mature.length : 0;
            return (
              <>
                {mature.length > 0 && (
                  <>
                    <Insight
                      tone="info"
                      parts={t('admin.v2p.anl.retention.sentence', {
                        d1: formatNumber(Math.round(avg('d1'))),
                        d7: formatNumber(Math.round(avg('d7'))),
                        d30: formatNumber(Math.round(avg('d30'))),
                      })}
                    />
                    <div className={styles.ringRow}>
                      <ProgressRing value={avg('d1')} label={t('admin.analytics.retention.d1')} size={96} thickness={9} />
                      <ProgressRing value={avg('d7')} label={t('admin.analytics.retention.d7')} size={96} thickness={9} tone="info" />
                      <ProgressRing value={avg('d30')} label={t('admin.analytics.retention.d30')} size={96} thickness={9} tone="success" />
                    </div>
                  </>
                )}
                <CohortHeat cohorts={d.cohorts} />
              </>
            );
          }}
        </Async>
      </Card>
    </div>
  );
}
