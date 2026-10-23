// SAYFA: Genel bakış (/admin)
// API: GET /api/admin/analytics/overview, /registrations, /active-users (api/analytics.ts), GET /api/status, GET /api/admin/audit?size=5.
// Her kart kendi sorgusunu yapar ve bağımsız hata verir; mini grafikler (recharts) tembel yüklenir.
import { useQuery } from '@tanstack/react-query';
import { lazy, Suspense, useMemo, type ReactNode } from 'react';
import { getActiveUsers, getOverview, getRegistrations } from '../../api/analytics';
import { qk } from '../../api/queryKeys';
import { ErrorState, PageHeader, Skeleton, StatCard } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { lastDays } from '../../lib/date';
import { usePageTitle } from '../../lib/hooks';
import styles from './dashboard/dashboard.module.css';
import { AttentionPanel, DevicePanel, RecentAudit, SourcesPanel } from './dashboard/panels';

const Trends = lazy(() => import('./dashboard/Trends'));

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className={styles.section} aria-label={title}>
      <h2 className={styles.sectionTitle}>{title}</h2>
      <div className={styles.kpis}>{children}</div>
    </section>
  );
}

export default function DashboardPage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  usePageTitle(t('admin.dashboard.title'));

  const range = useMemo(() => lastDays(30), []);
  const overview = useQuery({ queryKey: qk.analytics.overview(), queryFn: getOverview });
  const registrations = useQuery({
    queryKey: qk.analytics.registrations(range),
    queryFn: () => getRegistrations(range),
  });
  const activeUsers = useQuery({
    queryKey: qk.analytics.activeUsers(range),
    queryFn: () => getActiveUsers(range),
  });

  const o = overview.data;
  const loading = overview.isLoading;
  const n = (v: number | undefined) => (v === undefined ? '' : formatNumber(v));
  const pct = (ratio: number) => formatNumber(Math.round(ratio * 100));

  return (
    <div>
      <PageHeader title={t('admin.dashboard.title')} description={t('admin.dashboard.subtitle')} />

      <div className={styles.top}>
        <AttentionPanel overview={overview} />
        <SourcesPanel />
      </div>

      {overview.isError ? (
        <ErrorState
          title={t('common.state.errorTitle')}
          description={errorMessage(i18n, overview.error)}
          onRetry={() => void overview.refetch()}
        />
      ) : (
        <>
          <Section title={t('admin.dashboard.section.users')}>
            <StatCard title={t('admin.dashboard.kpi.users')} value={n(o?.totalUsers)} loading={loading} />
            <StatCard
              title={t('admin.dashboard.kpi.verified')}
              value={n(o?.verifiedUsers)}
              loading={loading}
              hint={
                o && o.totalUsers > 0
                  ? t('admin.dashboard.kpi.verifiedHint', { pct: pct(o.verifiedUsers / o.totalUsers) })
                  : undefined
              }
            />
            <StatCard
              title={t('admin.dashboard.kpi.suspended')}
              value={n(o?.suspendedUsers)}
              loading={loading}
            />
          </Section>

          <Section title={t('admin.dashboard.section.signups')}>
            <StatCard title={t('admin.dashboard.kpi.newToday')} value={n(o?.newUsers.today)} loading={loading} />
            <StatCard title={t('admin.dashboard.kpi.new7')} value={n(o?.newUsers.last7d)} loading={loading} />
            <StatCard
              title={t('admin.dashboard.kpi.new30')}
              value={n(o?.newUsers.last30d)}
              loading={loading}
              sparkline={registrations.data?.points.map((p) => p.count)}
            />
          </Section>

          <Section title={t('admin.dashboard.section.activity')}>
            <StatCard
              title={t('admin.dashboard.kpi.activeUsers')}
              value={n(o?.activeUsers.dau)}
              loading={loading}
              sparkline={activeUsers.data?.points.map((p) => p.dau)}
            />
            <StatCard title={t('admin.dashboard.kpi.wau')} value={n(o?.activeUsers.wau)} loading={loading} />
            <StatCard title={t('admin.dashboard.kpi.mau')} value={n(o?.activeUsers.mau)} loading={loading} />
            <StatCard
              title={t('admin.dashboard.kpi.stickiness')}
              value={o ? `${pct(o.stickiness)}%` : ''}
              loading={loading}
              hint={t('admin.dashboard.kpi.stickinessHint')}
            />
          </Section>

          <Section title={t('admin.dashboard.section.content')}>
            <StatCard
              title={t('admin.dashboard.kpi.messages')}
              value={n(o?.messages.total)}
              loading={loading}
              hint={o ? t('admin.dashboard.kpi.messages24', { n: formatNumber(o.messages.last24h) }) : undefined}
            />
            <StatCard
              title={t('admin.dashboard.kpi.communities')}
              value={n(o?.communities.active)}
              loading={loading}
              hint={
                o && o.communities.pending > 0
                  ? t('admin.dashboard.kpi.communitiesPending', { n: formatNumber(o.communities.pending) })
                  : undefined
              }
            />
            <StatCard
              title={t('admin.dashboard.kpi.events')}
              value={n(o?.events.upcoming)}
              loading={loading}
              hint={
                o && o.events.pending > 0
                  ? t('admin.dashboard.kpi.eventsPending', { n: formatNumber(o.events.pending) })
                  : undefined
              }
            />
            <StatCard title={t('admin.dashboard.kpi.bookmarks')} value={n(o?.bookmarks)} loading={loading} />
            <StatCard
              title={t('admin.dashboard.kpi.push')}
              value={n(o?.pushCampaignsSent30d)}
              loading={loading}
              hint={t('admin.dashboard.kpi.pushHint')}
            />
          </Section>

          <Section title={t('admin.dashboard.section.support')}>
            <StatCard
              title={t('admin.dashboard.kpi.openReports')}
              value={n(o?.openReports)}
              loading={loading}
            />
            <StatCard
              title={t('admin.dashboard.kpi.openTickets')}
              value={n(o?.openTickets)}
              loading={loading}
            />
            <StatCard title={t('admin.dashboard.kpi.newFeedback')} value={n(o?.newFeedback)} loading={loading} />
          </Section>
        </>
      )}

      <Suspense fallback={<Skeleton height={260} width="100%" radius="var(--radius-md)" />}>
        <Trends registrations={registrations} activeUsers={activeUsers} />
      </Suspense>

      <div className={styles.bottom}>
        <DevicePanel overview={overview} />
        <RecentAudit />
      </div>
    </div>
  );
}
