// Günlük gönderim kotası kartı (P13; salt okunur). Yüzde >= 80 uyarı, >= 95 kritik: renge ek olarak METİN de gösterilir.
import { useQuery } from '@tanstack/react-query';
import { getQuota, mailOpsKeys, type QuotaView } from '../../../api/adminMailOps';
import { ErrorState, Skeleton, StatusPill } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { barPercent, quotaLevel, quotaTone } from './mailOpsLogic';
import styles from './mailops.module.css';

export function MailQuotaCard() {
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
  return <QuotaBody q={query.data} />;
}

export function QuotaBody({ q }: { q: QuotaView }) {
  const { t, formatNumber, formatDateTime } = useI18n();
  // Sunucudan gelen düzeyle çelişmemesi için yüzdeden de türetilir (ikisi aynı eşikleri kullanır).
  const level = q.enabled ? quotaLevel(q.percent) : 'OFF';
  const p = barPercent(q.percent);
  const cls = [styles.quota, level === 'WARN' ? styles.quotaWarn : '', level === 'CRITICAL' ? styles.quotaCritical : '']
    .filter(Boolean)
    .join(' ');
  const fill = [styles.fill, level === 'WARN' ? styles.fillWarn : '', level === 'CRITICAL' ? styles.fillCritical : '']
    .filter(Boolean)
    .join(' ');
  const yesterday = q.history.length > 1 ? q.history[0] : null;

  return (
    <section className={cls} aria-label={t('admin.p13.quota.title')}>
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
              aria-valuetext={t('admin.p13.quota.barText', { used: formatNumber(q.used), limit: formatNumber(q.limit), p })}
            >
              <div className={fill} style={{ inlineSize: `${p}%` }} />
            </div>
            <span className={`${styles.barText} ltr`}>%{p}</span>
          </div>
          {(level === 'WARN' || level === 'CRITICAL') && (
            <p className={styles.callout} role="alert">
              {level === 'WARN' ? t('admin.p13.quota.warn.WARN', { p }) : t('admin.p13.quota.warn.CRITICAL', { p })}
            </p>
          )}
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
                {formatNumber(q.announcementRemaining)} <span className={styles.muted}>({t('admin.p13.quota.reserve', { n: formatNumber(q.reserve) })})</span>
              </dd>
            </div>
            <div>
              <dt>{t('admin.p13.quota.reset')}</dt>
              <dd>
                {formatDateTime(q.nextReset)} <span className={styles.muted}>({t('admin.p13.quota.resetHour', { h: q.resetHourUtc })})</span>
              </dd>
            </div>
            <div>
              <dt>{t('admin.p13.quota.publicCodes')}</dt>
              <dd>
                {formatNumber(q.publicCodeUsed)} / {formatNumber(q.publicCodeCapRegistration)}{' '}
                <span className={styles.muted}>({t('admin.p13.quota.publicCodesReset', { n: formatNumber(q.publicCodeCapReset) })})</span>
              </dd>
            </div>
            {yesterday && (
              <div>
                <dt>{t('admin.p13.quota.yesterday')}</dt>
                <dd>{formatNumber(yesterday.used)}</dd>
              </div>
            )}
          </dl>
        </>
      ) : (
        <p className={styles.muted}>{t('admin.p13.quota.unlimited', { n: formatNumber(q.used) })}</p>
      )}

      <dl className={styles.quotaStats} aria-label={t('admin.p13.quota.queue')}>
        <div>
          <dt>{t('admin.p13.status.PENDING')}</dt>
          <dd>{formatNumber(q.queue.pending)}</dd>
        </div>
        <div>
          <dt>{t('admin.p13.status.FAILED')}</dt>
          <dd>{formatNumber(q.queue.failed)}</dd>
        </div>
        <div>
          <dt>{t('admin.p13.status.DEAD')}</dt>
          <dd>{formatNumber(q.queue.dead)}</dd>
        </div>
        <div>
          <dt>{t('admin.p13.status.SKIPPED')}</dt>
          <dd>{formatNumber(q.queue.skipped)}</dd>
        </div>
        {q.queue.oldestPendingAt && (
          <div>
            <dt>{t('admin.p13.quota.oldest')}</dt>
            <dd>{formatDateTime(q.queue.oldestPendingAt)}</dd>
          </div>
        )}
      </dl>
      <p className={styles.muted}>{t('admin.p13.quota.note')}</p>
    </section>
  );
}
