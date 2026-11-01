import { useQuery, type UseQueryResult } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { listAudit } from '../../../api/audit';
import { qk } from '../../../api/queryKeys';
import { getSyncStatus } from '../../../api/settings';
import type { AnalyticsOverview } from '../../../api/types';
import { Card, EmptyState, ErrorState, Icon, Skeleton, StatusDot, StatusPill, useKitFormat } from '../../../components/ui';
import { describeAction } from '../audit/auditLogic';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import { paths } from '../../../paths';
import styles from './dashboard.module.css';

/** "Dikkat gerektirenler": ilgili sayfalara bağlanan bekleyen iş listesi. */
export function AttentionPanel({ overview }: { overview: UseQueryResult<AnalyticsOverview> }) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const o = overview.data;
  const items = o
    ? [
        { id: 'reports', n: o.openReports, to: paths.admin.reports, key: 'admin.dashboard.attention.reports' },
        { id: 'tickets', n: o.openTickets, to: paths.admin.tickets, key: 'admin.dashboard.attention.tickets' },
        {
          id: 'communities',
          n: o.communities.pending,
          to: `${paths.admin.communities}?tab=queue`, // onay bekleyenler: Kulüpler > Onay kuyruğu sekmesi
          key: 'admin.dashboard.attention.communities',
        },
        { id: 'events', n: o.events.pending, to: paths.admin.events, key: 'admin.dashboard.attention.events' },
        {
          id: 'feedback',
          n: o.newFeedback,
          to: paths.admin.feedback,
          key: 'admin.dashboard.attention.feedback',
        },
      ].filter((i) => i.n > 0)
    : [];
  return (
    <Card title={t('admin.dashboard.attention.title')} data-testid="attention-panel" data-search-anchor="dash-attention">
      {overview.isError ? (
        <ErrorState compact description={errorMessage(i18n, overview.error)} onRetry={() => void overview.refetch()} />
      ) : !o ? (
        <Skeleton height="6rem" width="100%" />
      ) : items.length === 0 ? (
        <EmptyState
          compact
          icon="check"
          title={t('admin.dashboard.attention.clearTitle')}
          description={t('admin.dashboard.attention.clearHint')}
        />
      ) : (
        <ul className={styles.attn}>
          {items.map((i) => (
            <li key={i.id}>
              <Link to={i.to} className={styles.attnLink}>
                <span className={styles.attnCount}>{formatNumber(i.n)}</span>
                <span className={styles.attnText}>
                  {t(i.key as 'admin.dashboard.attention.reports', { n: formatNumber(i.n) })}
                </span>
                <span className={styles.attnGo}>{t('admin.dashboard.attention.open')}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}

/** Haber ve menü kaynaklarının bakım durumu (`GET /api/status`). */
export function SourcesPanel() {
  const i18n = useI18n();
  const { t, td, formatDateTime } = i18n;
  const q = useQuery({ queryKey: qk.settings.sync(), queryFn: getSyncStatus, refetchInterval: 60_000 });
  const names = ['NEWS', 'MENU'];
  return (
    <Card title={t('admin.dashboard.sources.title')} data-testid="sources-panel" data-search-anchor="dash-sources">
      {q.isError ? (
        <ErrorState compact description={errorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : !q.data ? (
        <Skeleton height="5rem" width="100%" />
      ) : (
        <ul className={styles.sources}>
          {names.map((n) => {
            const s = q.data[n];
            if (!s) return null;
            return (
              <li key={n} className={styles.sourceRow}>
                <div className={styles.sourceHead}>
                  <span>{td(`admin.dashboard.sources.${n}`, n)}</span>
                  <StatusPill tone={s.maintenance ? 'warning' : 'success'}>
                    {s.maintenance ? t('admin.dashboard.sources.maintenance') : t('admin.dashboard.sources.ok')}
                  </StatusPill>
                </div>
                <span className={styles.sourceMeta}>
                  {s.lastSuccessAt
                    ? t('admin.dashboard.sources.last', { time: formatDateTime(s.lastSuccessAt) })
                    : t('admin.dashboard.sources.never')}
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </Card>
  );
}

const DEVICE_COLORS = ['var(--chart-1)', 'var(--chart-3)', 'var(--chart-4)'];

/** Android / iOS / web cihaz dağılımı: yığılı çubuk + sayı listesi. */
export function DevicePanel({ overview }: { overview: UseQueryResult<AnalyticsOverview> }) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const d = overview.data?.devices;
  const parts = d
    ? [
        { id: 'android', n: d.android },
        { id: 'ios', n: d.ios },
        { id: 'web', n: d.web },
      ]
    : [];
  const total = parts.reduce((s, p) => s + p.n, 0);
  return (
    <Card title={t('admin.dashboard.devices.title')} data-testid="device-panel">
      {overview.isError ? (
        <ErrorState compact description={errorMessage(i18n, overview.error)} onRetry={() => void overview.refetch()} />
      ) : !d ? (
        <Skeleton height="5rem" width="100%" />
      ) : total === 0 ? (
        <p>{t('admin.dashboard.devices.empty')}</p>
      ) : (
        <>
          <div className={styles.split} aria-hidden="true">
            {parts.map((p, i) =>
              p.n > 0 ? (
                <span
                  key={p.id}
                  className={styles.splitPart}
                  style={{ flexGrow: p.n, background: DEVICE_COLORS[i] }}
                />
              ) : null,
            )}
          </div>
          <ul className={styles.legend}>
            {parts.map((p, i) => (
              <li key={p.id}>
                <span className={styles.swatch} style={{ background: DEVICE_COLORS[i] }} aria-hidden="true" />
                {t(`admin.dashboard.devices.${p.id as 'android' | 'ios' | 'web'}`)}
                <span className={styles.legendValue}>
                  <span className={styles.legendPct}>%{formatNumber(Math.round((p.n / total) * 100))}</span>
                  <span style={{ color: 'var(--text-muted)', fontWeight: 400 }}> ({formatNumber(p.n)})</span>
                </span>
              </li>
            ))}
          </ul>
        </>
      )}
    </Card>
  );
}

/** Son 5 yönetici işlemi: "Ayşe · Kullanıcıyı askıya aldı · 3 dk önce" (ham HTTP yolu gösterilmez). */
export function RecentAudit() {
  const i18n = useI18n();
  const { t, td } = i18n;
  const kit = useKitFormat();
  const q = useQuery({
    queryKey: qk.audit.list({ page: 0, size: 5 }),
    queryFn: () => listAudit({ page: 0, size: 5 }),
  });
  return (
    <Card title={t('admin.dashboard.audit.title')} data-testid="recent-audit" data-search-anchor="dash-audit">
      {q.isError ? (
        <ErrorState compact description={errorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : !q.data ? (
        <Skeleton height="8rem" width="100%" />
      ) : q.data.items.length === 0 ? (
        <p>{t('admin.dashboard.audit.empty')}</p>
      ) : (
        <>
          <ul className={styles.audit}>
            {q.data.items.map((r) => {
              const a = describeAction(td, r.method, r.path);
              const denied = r.status === 403;
              const failed = r.status >= 400;
              return (
                <li key={r.id}>
                  <span className={styles.auditText}>
                    <strong className="ltr">{r.adminEmail ? r.adminEmail.split('@')[0] : t('admin.audit.noAdmin')}</strong>
                    {' · '}
                    {a.label}
                  </span>
                  <span className={styles.auditMeta}>
                    <StatusDot tone={denied ? 'warning' : failed ? 'danger' : 'success'} announceTone={false}>
                      {denied
                        ? t('admin.v2p.dash.audit.denied')
                        : failed
                          ? t('admin.v2p.dash.audit.failed')
                          : t('admin.v2p.dash.audit.done')}
                    </StatusDot>
                    {' · '}
                    <span title={r.at}>{kit.relative(r.at)}</span>
                  </span>
                </li>
              );
            })}
          </ul>
          <Link to={paths.admin.audit} className={styles.moreLink}>
            {t('admin.dashboard.audit.all')} <Icon name="external" size={14} />
          </Link>
        </>
      )}
    </Card>
  );
}
