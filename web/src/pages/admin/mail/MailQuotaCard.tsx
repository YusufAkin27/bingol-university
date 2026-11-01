// Günlük gönderim kotası kartı (P13; salt okunur). Yüzde >= 80 uyarı, >= 95 kritik: renge ek olarak METİN de gösterilir.
import { useQuery } from '@tanstack/react-query';
import { getQuota, mailOpsKeys, type OutboxStatus, type QuotaView } from '../../../api/adminMailOps';
import { ErrorState, Insight, Skeleton, StatusPill } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { QueueHealth } from '../iletisim/QueueHealth';
import { barPercent, quotaLevel, quotaTone } from './mailOpsLogic';
import styles from './mailops.module.css';

/** Kuyruk sağlığı şeridindeki satıra basınca liste süzgecini o duruma çeviren isteğe bağlı bağlantı. */
export interface QueueFilterProps {
  onPickStatus?: (s: OutboxStatus | '') => void;
  selectedStatus?: OutboxStatus | '';
}

export function MailQuotaCard(props: QueueFilterProps) {
  const i18n = useI18n();
  const { t } = i18n;
  const query = useQuery({
    queryKey: mailOpsKeys.quota,
    queryFn: getQuota,
    refetchInterval: 60_000,
  });
  if (query.isLoading) {
    return (
      <section className={styles.quota} aria-label={t('admin.p13.quota.title')} aria-busy="true">
        <Skeleton height={80} />
      </section>
    );
  }
  if (query.isError || !query.data) {
    return (
      <ErrorState
        onRetry={() => void query.refetch()}
        description={adminError(i18n, query.error, 'admin.p13.err', 'admin.err')}
      />
    );
  }
  return <QuotaBody q={query.data} {...props} />;
}

/** Son günlerin gönderimi: sütunlar kota çizgisine göre (sayı her sütunun altında yazılıdır). */
function QuotaHistory({ q }: { q: QuotaView }) {
  const { t, formatNumber, formatDate } = useI18n();
  const days = [...q.history].slice(0, 7).reverse();
  const top = Math.max(q.limit, ...days.map((d) => d.used), 1);
  return (
    <figure className={styles.history}>
      <figcaption className={styles.muted}>
        {t('admin.v2n.mq.history', { limit: formatNumber(q.limit) })}
      </figcaption>
      <ol className={styles.historyBars}>
        {days.map((d) => (
          <li key={d.date}>
            <span className={styles.historyCol} aria-hidden="true">
              <span
                className={`${styles.historyFill} ${d.used >= q.limit * 0.95 ? styles.fillCritical : d.used >= q.limit * 0.8 ? styles.fillWarn : ''}`}
                style={{ blockSize: `${Math.max(4, (d.used / top) * 100)}%` }}
              />
            </span>
            <span className={styles.historyNum}>{formatNumber(d.used)}</span>
            <span className={styles.muted}>{formatDate(d.date, { day: 'numeric', month: 'short' })}</span>
          </li>
        ))}
      </ol>
    </figure>
  );
}

export function QuotaBody({ q, onPickStatus, selectedStatus }: { q: QuotaView } & QueueFilterProps) {
  const { t, formatNumber, formatDateTime } = useI18n();
  // Sunucudan gelen düzeyle çelişmemesi için yüzdeden de türetilir (ikisi aynı eşikleri kullanır).
  const level = q.enabled ? quotaLevel(q.percent) : 'OFF';
  const p = barPercent(q.percent);
  const cls = [
    styles.quota,
    level === 'WARN' ? styles.quotaWarn : '',
    level === 'CRITICAL' ? styles.quotaCritical : '',
  ]
    .filter(Boolean)
    .join(' ');
  const fill = [
    styles.fill,
    level === 'WARN' ? styles.fillWarn : '',
    level === 'CRITICAL' ? styles.fillCritical : '',
  ]
    .filter(Boolean)
    .join(' ');
  const yesterday = q.history.length > 1 ? q.history[0] : null;

  return (
    <section className={cls} aria-label={t('admin.p13.quota.title')} data-search-anchor="quota">
      <div className={styles.quotaHead}>
        <h2 className={styles.quotaTitle}>{t('admin.p13.quota.title')}</h2>
        <StatusPill tone={quotaTone(level)}>{t(`admin.p13.quota.level.${level}`)}</StatusPill>
      </div>

      {!q.mailEnabled && (
        <p className={`${styles.callout} ${styles.calloutWarn}`} role="note">
          {t('admin.p13.quota.mailOff')}
        </p>
      )}

      {q.enabled ? (
        <>
          <div className={styles.bar}>
            <div
              className={styles.track}
              role="progressbar"
              aria-label={t('admin.p13.quota.bar')}
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={p}
              aria-valuetext={t('admin.p13.quota.barText', {
                used: formatNumber(q.used),
                limit: formatNumber(q.limit),
                p,
              })}
            >
              <div className={fill} style={{ inlineSize: `${p}%` }} />
            </div>
            <span className={`${styles.barText} ltr`}>%{p}</span>
          </div>
          {(level === 'WARN' || level === 'CRITICAL') && (
            <p className={styles.callout} role="alert">
              {level === 'WARN'
                ? t('admin.p13.quota.warn.WARN', { p })
                : t('admin.p13.quota.warn.CRITICAL', { p })}
            </p>
          )}
          <Insight
            tone={level === 'CRITICAL' ? 'bad' : level === 'WARN' ? 'warn' : 'good'}
            parts={t('admin.v2n.mq.summary', {
              limit: formatNumber(q.limit),
              used: formatNumber(q.used),
              p,
              remaining: formatNumber(Math.max(0, q.remaining)),
              ann: formatNumber(Math.max(0, q.announcementRemaining)),
            })}
          />
          {q.history.length > 1 && <QuotaHistory q={q} />}
          <details className={styles.moreDetails} data-search-anchor="quota-details">
            <summary>{t('admin.v2n.mq.showDetails')}</summary>
            <dl className={styles.quotaStats}>
              <div>
                <dt>{t('admin.p13.quota.used')}</dt>
                <dd>
                  {formatNumber(q.used)} / {formatNumber(q.limit)}
                </dd>
              </div>
              <div>
                <dt>{t('admin.p13.quota.remaining')}</dt>
                <dd>{formatNumber(q.remaining)}</dd>
              </div>
              <div>
                <dt>{t('admin.p13.quota.announcementRemaining')}</dt>
                <dd>
                  {formatNumber(q.announcementRemaining)}{' '}
                  <span className={styles.muted}>
                    ({t('admin.p13.quota.reserve', { n: formatNumber(q.reserve) })})
                  </span>
                </dd>
              </div>
              <div>
                <dt>{t('admin.p13.quota.reset')}</dt>
                <dd>
                  {formatDateTime(q.nextReset)}{' '}
                  <span className={styles.muted}>
                    ({t('admin.p13.quota.resetHour', { h: q.resetHourUtc })})
                  </span>
                </dd>
              </div>
              <div>
                <dt>{t('admin.p13.quota.publicCodes')}</dt>
                <dd>
                  {formatNumber(q.publicCodeUsed)} / {formatNumber(q.publicCodeCapRegistration)}{' '}
                  <span className={styles.muted}>
                    ({t('admin.p13.quota.publicCodesReset', { n: formatNumber(q.publicCodeCapReset) })})
                  </span>
                </dd>
              </div>
              {yesterday && (
                <div>
                  <dt>{t('admin.p13.quota.yesterday')}</dt>
                  <dd>{formatNumber(yesterday.used)}</dd>
                </div>
              )}
            </dl>
          </details>
        </>
      ) : (
        <p className={styles.muted}>{t('admin.p13.quota.unlimited', { n: formatNumber(q.used) })}</p>
      )}

      <div data-search-anchor="queue-health">
        <QueueHealth
          title={t('admin.p13.quota.queue')}
          ariaLabel={t('admin.p13.quota.queue')}
          counts={q.queue}
          labels={{
            pending: t('admin.p13.status.PENDING'),
            failed: t('admin.p13.status.FAILED'),
            dead: t('admin.p13.status.DEAD'),
            skipped: t('admin.p13.status.SKIPPED'),
          }}
          oldestAt={q.queue.oldestPendingAt}
          onSelect={onPickStatus ? (k) => onPickStatus(k.toUpperCase() as OutboxStatus) : undefined}
          selectedKey={selectedStatus ? selectedStatus.toLowerCase() : null}
        />
      </div>
      <p className={styles.muted}>{t('admin.p13.quota.note')}</p>
    </section>
  );
}
