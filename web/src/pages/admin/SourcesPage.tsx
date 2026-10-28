// SAYFA: Kaynak durumu (/admin/sources) — haber/duyuru/etkinlik ve yemek listesi kaynaklarının durumu + elle senkron.
// API: GET /api/admin/sources/status, POST /api/admin/sources/sync {source, reason} (api/adminBulk.ts).
// Scraper kuralı: kaynak siteye yalnız zamanlayıcı istek atar; elle senkron bir istisnadır ve saatte 3 ile sınırlıdır.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
  getSourcesStatus,
  sourcesKeys,
  syncSource,
  type MenuSourceStatus,
  type NewsSourceStatus,
  type SourceName,
  type SourceSyncResult,
} from '../../api/adminBulk';
import {
  Card,
  ErrorState,
  GuardedAction,
  PageHeader,
  Skeleton,
  StatusPill,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { bulkError } from './bulk/BulkParts';
import styles from './bulk/bulk.module.css';

type Status = NewsSourceStatus | MenuSourceStatus;

export default function SourcesPage() {
  const i18n = useI18n();
  const { t, formatNumber, formatDateTime } = i18n;
  usePageTitle(t('admin.p15.sources.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const q = useQuery({ queryKey: sourcesKeys.status, queryFn: getSourcesStatus, refetchInterval: 60_000 });
  const perHour = q.data?.syncPerHour ?? 3;

  const when = (v: string | null) => (v ? formatDateTime(v) : t('admin.p15.sources.never'));

  function doneText(r: SourceSyncResult): string {
    if (r.source === 'MENU') return t('admin.p15.sources.doneMenu', { n: formatNumber(r.changed) });
    const parts = Object.entries(r.detail)
      .filter(([, n]) => n > 0)
      .map(([k, n]) => `${k} ${n}`);
    return t('admin.p15.sources.doneNews', {
      summary: parts.length ? parts.join(', ') : t('admin.p15.sources.noNew'),
    });
  }

  function head(s: Status, title: string) {
    return (
      <div className={styles.head}>
        <strong>{title}</strong>
        <StatusPill tone={s.maintenance ? 'danger' : 'success'}>
          {t(s.maintenance ? 'admin.p15.sources.maintenance' : 'admin.p15.sources.ok')}
        </StatusPill>
      </div>
    );
  }

  function syncButton(source: SourceName) {
    return (
      <GuardedAction
        size="sm"
        variant="secondary"
        title={t(`admin.p15.sources.confirmTitle.${source}`)}
        message={t('admin.p15.sources.confirmMessage')}
        consequence={t('admin.p15.sources.confirmConsequence', { n: perHour })}
        irreversible={false}
        requireReason
        confirmLabel={t('admin.p15.sources.run')}
        errorMessage={(e) => bulkError(i18n, e)}
        successMessage={false}
        invalidateKeys={[[...sourcesKeys.status]]}
        onConfirm={async ({ reason, idempotencyKey }) => {
          const r = await syncSource(source, reason, { idempotencyKey });
          toast.success(doneText(r));
          void qc.invalidateQueries({ queryKey: ['news'] });
          return r;
        }}
      >
        {t('admin.p15.sources.run')}
      </GuardedAction>
    );
  }

  const n = q.data?.news;
  const m = q.data?.menu;

  return (
    <>
      <PageHeader title={t('admin.p15.sources.title')} description={t('admin.p15.sources.intro')} />
      <div className={styles.notice} role="note">
        <p>{t('admin.p15.sources.rule')}</p>
        <p>{t('admin.p15.sources.limit', { n: perHour })}</p>
      </div>
      {q.isError ? (
        <ErrorState description={bulkError(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : q.isLoading || !n || !m ? (
        <Skeleton height="10rem" width="100%" />
      ) : (
        <div className={styles.cards}>
          <Card className={styles.card} data-source="NEWS">
            {head(n, t('admin.p15.sources.news'))}
            <dl className={styles.facts}>
              <dt>{t('admin.p15.sources.lastSuccess')}</dt>
              <dd>{when(n.lastSuccess)}</dd>
              <dt>{t('admin.p15.sources.lastAttempt')}</dt>
              <dd>{when(n.lastAttempt)}</dd>
              {n.message && (
                <>
                  <dt>{t('admin.p15.sources.message')}</dt>
                  <dd dir="auto">{n.message}</dd>
                </>
              )}
              <dt>{t('admin.p15.sources.itemsLast7d')}</dt>
              <dd>{formatNumber(n.itemsLast7d)}</dd>
              <dt>{t('admin.p15.sources.total')}</dt>
              <dd>
                {formatNumber(n.total)} ·{' '}
                {Object.entries(n.byType)
                  .map(([k, v]) => `${i18n.td(`admin.news.type.${k}`, k)} ${formatNumber(v)}`)
                  .join(', ')}
              </dd>
              <dt>{t('admin.p15.sources.hidden')}</dt>
              <dd>{formatNumber(n.hidden)}</dd>
            </dl>
            <div className={styles.actionsRow}>{syncButton('NEWS')}</div>
          </Card>
          <Card className={styles.card} data-source="MENU">
            {head(m, t('admin.p15.sources.menu'))}
            <dl className={styles.facts}>
              <dt>{t('admin.p15.sources.lastSuccess')}</dt>
              <dd>{when(m.lastSuccess)}</dd>
              <dt>{t('admin.p15.sources.lastAttempt')}</dt>
              <dd>{when(m.lastAttempt)}</dd>
              {m.message && (
                <>
                  <dt>{t('admin.p15.sources.message')}</dt>
                  <dd dir="auto">{m.message}</dd>
                </>
              )}
              <dt>{t('admin.p15.sources.menuTotal')}</dt>
              <dd>{formatNumber(m.totalDays)}</dd>
              <dt>{t('admin.p15.sources.menuUpcoming')}</dt>
              <dd>{formatNumber(m.upcomingDays)}</dd>
              <dt>{t('admin.p15.sources.menuImages')}</dt>
              <dd>{formatNumber(m.withImage)}</dd>
            </dl>
            <div className={styles.actionsRow}>{syncButton('MENU')}</div>
          </Card>
        </div>
      )}
    </>
  );
}
