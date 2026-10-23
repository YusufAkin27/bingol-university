import { useQuery } from '@tanstack/react-query';
import { getRetention } from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import { Card, EmptyState } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './analytics.module.css';
import { Async, CohortHeat } from './parts';

export default function RetentionTab() {
  const { t } = useI18n();
  const q = useQuery({ queryKey: qk.analytics.retention(), queryFn: getRetention });
  return (
    <div className={styles.panel}>
      <Card title={t('admin.analytics.retention.title')}>
        <p className={styles.muted} style={{ marginBlockEnd: 'var(--space-4)' }}>
          {t('admin.analytics.retention.desc')}
        </p>
        <Async query={q} height={320}>
          {(d) =>
            d.cohorts.length === 0 ? (
              <EmptyState compact icon="chart" title={t('admin.analytics.retention.empty')} description=" " />
            ) : (
              <CohortHeat cohorts={d.cohorts} />
            )
          }
        </Async>
      </Card>
    </div>
  );
}
