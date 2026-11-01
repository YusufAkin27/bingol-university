// SAYFA: Genel bakış (/admin)
// API: GET /api/admin/moderation/appeals + suspend-recommendations (açık sayaçlar), GET /api/admin/analytics/overview, /registrations, /active-users (api/analytics.ts), GET /api/status, GET /api/admin/audit?size=5.
// PEOPLE: önce tek cümlelik özet ("Bugün 120 kişi girdi, dün 98 idi: %22 fazla"), sonra 4 büyük kutu (giren, yeni üye, geri dönen,
// bekleyen iş), halkalar ve dikkat gerektirenler; 20 sayılık eski yığın "Ayrıntılı sayılar" altında katlanır.
// Genel bakış (overview) hata verirse tek bir üst bant gösterilir; trend/denetim/kaynak kartları bağımsız kalır.
import { useQuery } from '@tanstack/react-query';
import { lazy, Suspense, useMemo } from 'react';
import { getActiveUsers, getOverview, getRegistrations } from '../../api/analytics';
import { qk } from '../../api/queryKeys';
import { usePermissions } from '../../auth/permissions';
import {
  Card,
  ErrorState,
  Insight,
  PageHeader,
  ProgressRing,
  Skeleton,
  StatTile,
  percentChange,
  useCompareSentence,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { istanbulYesterday, lastDaysIstanbul } from '../../lib/date';
import { usePageTitle } from '../../lib/hooks';
import styles from './dashboard/dashboard.module.css';
import { ModerationCounters } from './dashboard/ModerationCounters';
import { AttentionPanel, DevicePanel, RecentAudit, SourcesPanel } from './dashboard/panels';

const Trends = lazy(() => import('./dashboard/Trends'));

export default function DashboardPage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  usePageTitle(t('admin.dashboard.title'));
  const perms = usePermissions();
  const sentence = useCompareSentence();

  const range = useMemo(() => lastDaysIstanbul(30), []);
  // Dün, panelin iş günü olan Europe/Istanbul gününe göre (tarayıcı saat diliminden bağımsız)
  const yesterday = useMemo(() => istanbulYesterday(), []);
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

  // Dünün değerleri günlük serilerden okunur; seri yoksa karşılaştırma yazılmaz (uydurma yüzde yok).
  const yDau = activeUsers.data?.points.find((p) => p.date === yesterday)?.dau;
  const yNew = registrations.data?.points.find((p) => p.date === yesterday)?.count;
  const dau = o?.activeUsers.dau;
  const newToday = o?.newUsers.today;
  const returning = dau !== undefined && newToday !== undefined ? Math.max(0, dau - newToday) : undefined;
  const yReturning = yDau !== undefined && yNew !== undefined ? Math.max(0, yDau - yNew) : undefined;
  const waiting = o
    ? o.openReports + o.openTickets + o.newFeedback + o.communities.pending + o.events.pending
    : undefined;
  const dauSpark = activeUsers.data?.points.map((p) => p.dau);
  const regSpark = registrations.data?.points.map((p) => p.count);
  const pct = (ratio: number) => Math.round(ratio * 100);

  const hero = o
    ? o.totalUsers === 0
      ? { parts: [t('admin.v2p.dash.emptyAll')], tone: 'info' as const }
      : sentence({
          nowLabel: t('admin.v2p.dash.today'),
          current: o.activeUsers.dau,
          thenLabel: t('admin.v2p.dash.yesterday'),
          previous: yDau,
          unit: t('admin.v2p.unit.person'),
          verb: t('admin.v2p.dash.verbEntered'),
          partial: true, // bugün henüz bitmedi: dünün tamamıyla kıyas nötr ve "şu ana kadar" diye yazılır
        })
    : null;

  return (
    <div>
      <PageHeader title={t('admin.dashboard.title')} />

      {overview.isError ? (
        <ErrorState
          title={t('admin.v2p.dash.errorTitle')}
          description={`${t('admin.v2p.dash.errorHint')} ${errorMessage(i18n, overview.error)}`}
          onRetry={() => void overview.refetch()}
        />
      ) : (
        <>
          <section className={styles.hero} aria-label={t('admin.v2p.dash.heroLabel')} data-search-anchor="dash-hero">
            {hero ? <Insight parts={hero.parts} tone={hero.tone} /> : <Skeleton height="2.6rem" width="100%" />}
            {o && waiting !== undefined && waiting > 0 && (
              <Insight tone="warn" parts={t('admin.v2p.dash.waitingSentence', { n: formatNumber(waiting) })} />
            )}
            {o && waiting === 0 && <Insight tone="good" parts={t('admin.v2p.dash.waitingNone')} />}
          </section>

          <section className={styles.tiles} aria-label={t('admin.v2p.dash.tilesLabel')} data-search-anchor="dash-tiles">
            <StatTile
              label={t('admin.v2p.dash.tile.entered')}
              value={dau}
              unit={t('admin.v2p.unit.person')}
              icon="users"
              change={dau !== undefined ? percentChange(dau, yDau) : null}
              goodWhen="neutral"
              compareLabel={t('admin.v2p.dash.fromYesterdayWhole')}
              spark={dauSpark}
              caption={t('admin.v2p.dash.tile.enteredHint')}
              loading={loading}
            />
            <StatTile
              label={t('admin.v2p.dash.tile.new')}
              value={newToday}
              unit={t('admin.v2p.unit.person')}
              icon="plus"
              change={newToday !== undefined ? percentChange(newToday, yNew) : null}
              goodWhen="neutral"
              compareLabel={t('admin.v2p.dash.fromYesterdayWhole')}
              spark={regSpark}
              caption={t('admin.v2p.dash.tile.newHint')}
              loading={loading}
            />
            <StatTile
              label={t('admin.v2p.dash.tile.returning')}
              value={returning}
              unit={t('admin.v2p.unit.person')}
              icon="home"
              change={returning !== undefined ? percentChange(returning, yReturning) : null}
              goodWhen="neutral"
              compareLabel={t('admin.v2p.dash.fromYesterdayWhole')}
              caption={t('admin.v2p.dash.tile.returningHint')}
              loading={loading}
            />
            <StatTile
              label={t('admin.v2p.dash.tile.waiting')}
              value={waiting}
              unit={t('admin.v2p.dash.unit.task')}
              icon="flag"
              goodWhen="down"
              caption={t('admin.v2p.dash.tile.waitingHint')}
              loading={loading}
            />
          </section>

          <div className={styles.top}>
            <AttentionPanel overview={overview} />
            <SourcesPanel />
          </div>

          <div className={styles.rings} data-search-anchor="dash-rings">
            <Card title={t('admin.v2p.dash.verified.title')}>
              <ProgressRing
                value={o?.verifiedUsers}
                max={o?.totalUsers || 1}
                label={t('admin.v2p.dash.verified.label')}
                tone="success"
                loading={loading}
              />
              {o && (
                <p className={styles.ringNote}>
                  {t('admin.v2p.dash.verified.note', {
                    total: formatNumber(o.totalUsers),
                    verified: formatNumber(o.verifiedUsers),
                    missing: formatNumber(Math.max(0, o.totalUsers - o.verifiedUsers)),
                  })}
                </p>
              )}
            </Card>
            <Card title={t('admin.v2p.dash.sticky.title')}>
              <ProgressRing
                value={o ? pct(o.stickiness) : undefined}
                max={100}
                label={t('admin.v2p.dash.sticky.label')}
                tone="primary"
                loading={loading}
              />
              {o && (
                <p className={styles.ringNote}>
                  {t('admin.v2p.dash.sticky.note', {
                    week: formatNumber(o.activeUsers.wau),
                    month: formatNumber(o.activeUsers.mau),
                  })}
                </p>
              )}
            </Card>
            <DevicePanel overview={overview} />
          </div>
        </>
      )}

      <Suspense fallback={<Skeleton height={260} width="100%" radius="var(--radius-md)" />}>
        <Trends registrations={registrations} activeUsers={activeUsers} />
      </Suspense>

      {o && !overview.isError && (
        <details className={styles.more} data-search-anchor="dash-details">
          <summary>{t('admin.v2p.dash.details')}</summary>
          <div className={styles.kpis}>
            <StatTile
              label={t('admin.dashboard.kpi.suspended')}
              value={o.suspendedUsers}
              unit={t('admin.v2p.unit.person')}
              goodWhen="down"
            />
            <StatTile
              label={t('admin.dashboard.kpi.new7')}
              value={o.newUsers.last7d}
              unit={t('admin.v2p.unit.person')}
            />
            <StatTile
              label={t('admin.dashboard.kpi.new30')}
              value={o.newUsers.last30d}
              unit={t('admin.v2p.unit.person')}
              spark={regSpark}
            />
            <StatTile
              label={t('admin.v2p.dash.kpi.week')}
              value={o.activeUsers.wau}
              unit={t('admin.v2p.unit.person')}
            />
            <StatTile
              label={t('admin.v2p.dash.kpi.month')}
              value={o.activeUsers.mau}
              unit={t('admin.v2p.unit.person')}
            />
            <StatTile
              label={t('admin.dashboard.kpi.messages')}
              value={o.messages.total}
              unit={t('admin.v2p.dash.unit.message')}
              caption={t('admin.dashboard.kpi.messages24', { n: formatNumber(o.messages.last24h) })}
            />
            <StatTile
              label={t('admin.dashboard.kpi.communities')}
              value={o.communities.active}
              caption={
                o.communities.pending > 0
                  ? t('admin.dashboard.kpi.communitiesPending', { n: formatNumber(o.communities.pending) })
                  : undefined
              }
            />
            <StatTile
              label={t('admin.dashboard.kpi.events')}
              value={o.events.upcoming}
              caption={
                o.events.pending > 0
                  ? t('admin.dashboard.kpi.eventsPending', { n: formatNumber(o.events.pending) })
                  : undefined
              }
            />
            <StatTile label={t('admin.dashboard.kpi.bookmarks')} value={o.bookmarks} />
            <StatTile label={t('admin.dashboard.kpi.push')} value={o.pushCampaignsSent30d} />
            <StatTile label={t('admin.dashboard.kpi.openReports')} value={o.openReports} goodWhen="down" />
            <StatTile label={t('admin.dashboard.kpi.openTickets')} value={o.openTickets} goodWhen="down" />
            <StatTile label={t('admin.dashboard.kpi.newFeedback')} value={o.newFeedback} />
            {perms.can('moderation.read') && <ModerationCounters />}
          </div>
        </details>
      )}

      {perms.can('audit.read') && (
        <div className={styles.audit1}>
          <RecentAudit />
        </div>
      )}
    </div>
  );
}
