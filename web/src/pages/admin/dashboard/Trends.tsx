import type { UseQueryResult } from '@tanstack/react-query';
import { Card, ErrorState, Skeleton } from '../../../components/ui';
import { LineAreaChart } from '../../../components/charts';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import type { ActiveUsersResponse, RegistrationsResponse } from '../../../api/types';
import styles from './dashboard.module.css';

interface Props {
  registrations: UseQueryResult<RegistrationsResponse>;
  activeUsers: UseQueryResult<ActiveUsersResponse>;
}

/** Son 30 gün kayıt ve DAU mini grafikleri (recharts bu bileşenle birlikte tembel yüklenir). Her kart bağımsız hata verir. */
export default function Trends({ registrations, activeUsers }: Props) {
  const i18n = useI18n();
  const { t, formatDate } = i18n;
  const fmt = (v: string | number) => formatDate(String(v), { day: 'numeric', month: 'short' });

  return (
    <div className={styles.charts}>
      <Card title={t('admin.dashboard.trends.signups')}>
        {registrations.isError ? (
          <ErrorState
            compact
            description={errorMessage(i18n, registrations.error)}
            onRetry={() => void registrations.refetch()}
          />
        ) : registrations.data ? (
          <LineAreaChart
            data={registrations.data.points}
            xKey="date"
            series={[{ key: 'count', label: t('admin.dashboard.trends.signupsSeries') }]}
            ariaLabel={t('admin.dashboard.trends.signups')}
            height={200}
            formatX={fmt}
            emptyLabel={t('admin.analytics.chart.noData')}
          />
        ) : (
          <Skeleton height={200} width="100%" radius="var(--radius-sm)" />
        )}
      </Card>
      <Card title={t('admin.dashboard.trends.dau')}>
        {activeUsers.isError ? (
          <ErrorState
            compact
            description={errorMessage(i18n, activeUsers.error)}
            onRetry={() => void activeUsers.refetch()}
          />
        ) : activeUsers.data ? (
          <LineAreaChart
            data={activeUsers.data.points}
            xKey="date"
            series={[{ key: 'dau', label: t('admin.dashboard.trends.dauSeries'), color: 'var(--chart-3)' }]}
            ariaLabel={t('admin.dashboard.trends.dau')}
            height={200}
            formatX={fmt}
            emptyLabel={t('admin.analytics.chart.noData')}
          />
        ) : (
          <Skeleton height={200} width="100%" radius="var(--radius-sm)" />
        )}
      </Card>
    </div>
  );
}
