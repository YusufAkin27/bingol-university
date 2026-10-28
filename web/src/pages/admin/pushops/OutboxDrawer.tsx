// Kuyruk kaydı ayrıntı çekmecesi: GET /api/admin/push/outbox/{id} (yük ve ham token YOK), tek kayıt yeniden dene / iptal.
import { useQuery } from '@tanstack/react-query';
import { cancelOutbox, getOutboxDetail, pushOpsKeys, retryOutbox } from '../../../api/adminPushOps';
import { Badge, Drawer, ErrorState, GuardedAction, Skeleton, StatusPill } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { Callout } from '../campaigns/shared';
import { codeKey, STATUS_TONE } from './lib';
import styles from './pushops.module.css';

export function OutboxDrawer({ id, onClose }: { id: number | null; onClose: () => void }) {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  const q = useQuery({
    queryKey: pushOpsKeys.detail(id ?? 0),
    queryFn: () => getOutboxDetail(id ?? 0),
    enabled: id !== null,
  });
  const d = q.data;
  const invalidate = [pushOpsKeys.all];
  const dash = '—';

  const codeText = (code: string | null) => {
    if (!code) return dash;
    const k = codeKey(code);
    return k ? `${td(k, code)} (${code})` : code;
  };

  return (
    <Drawer
      open={id !== null}
      onClose={onClose}
      size="md"
      title={t('admin.p14.queue.detail.title', { id: id ?? 0 })}
      footer={
        d && (d.canRetry || d.canCancel) ? (
          <>
            {d.canRetry && (
              <GuardedAction
                variant="secondary"
                irreversible={false}
                title={t('admin.p14.queue.retry.title', { id: d.id })}
                message={t('admin.p14.queue.retry.message')}
                consequence={t('admin.p14.queue.retry.consequence')}
                confirmLabel={t('admin.p14.queue.retry.confirm')}
                successMessage={t('admin.p14.queue.retry.done')}
                errorMessage={(e) => adminError(i18n, e, 'admin.p14.err')}
                invalidateKeys={invalidate}
                onConfirm={({ idempotencyKey }) => retryOutbox(d.id, { idempotencyKey })}
              >
                {t('admin.p14.queue.retry.button')}
              </GuardedAction>
            )}
            {d.canCancel && (
              <GuardedAction
                variant="danger"
                danger
                requireReason
                irreversible={false}
                title={t('admin.p14.queue.cancel.title', { id: d.id })}
                message={t('admin.p14.queue.cancel.message')}
                consequence={t('admin.p14.queue.cancel.consequence')}
                confirmLabel={t('admin.p14.queue.cancel.confirm')}
                successMessage={t('admin.p14.queue.cancel.done')}
                errorMessage={(e) => adminError(i18n, e, 'admin.p14.err')}
                invalidateKeys={invalidate}
                onConfirm={({ reason, idempotencyKey }) => cancelOutbox(d.id, { reason, idempotencyKey })}
              >
                {t('admin.p14.queue.cancel.button')}
              </GuardedAction>
            )}
          </>
        ) : undefined
      }
    >
      {q.isError ? (
        <ErrorState onRetry={() => void q.refetch()} description={adminError(i18n, q.error, 'admin.p14.err')} />
      ) : !d ? (
        <Skeleton width="100%" height="10em" />
      ) : (
        <div className={styles.stack}>
          <div className={styles.row}>
            <StatusPill tone={STATUS_TONE[d.status]}>{t(`admin.p14.status.${d.status}`)}</StatusPill>
            {d.type && <Badge tone="neutral">{d.type}</Badge>}
          </div>
          <Callout tone="info">{t('admin.p14.queue.detail.noPayload')}</Callout>
          <dl className={styles.kv}>
            <dt>{t('admin.p14.queue.col.target')}</dt>
            <dd className="ltr">
              {d.targetRef ?? dash} · {d.userRef ?? dash}
            </dd>
            <dt>{t('admin.p14.queue.col.campaign')}</dt>
            <dd>{d.campaignId ? `#${d.campaignId}` : dash}</dd>
            <dt>{t('admin.p14.queue.detail.attempts')}</dt>
            <dd>{t('admin.p14.queue.detail.attemptsOf', { n: formatNumber(d.attempts), max: formatNumber(d.maxAttempts) })}</dd>
            <dt>{t('admin.p14.queue.col.code')}</dt>
            <dd>{codeText(d.errorCode)}</dd>
            <dt>{t('admin.p14.queue.detail.lastError')}</dt>
            <dd className="ltr">{d.lastError ?? dash}</dd>
            <dt>{t('admin.p14.queue.detail.priority')}</dt>
            <dd>{d.priority > 0 ? t('admin.p14.queue.detail.high') : t('admin.p14.queue.detail.normal')}</dd>
            <dt>{t('admin.p14.queue.col.next')}</dt>
            <dd>{d.nextAttemptAt ? formatDateTime(d.nextAttemptAt) : dash}</dd>
            <dt>{t('admin.p14.queue.detail.lease')}</dt>
            <dd>{d.leaseUntil ? formatDateTime(d.leaseUntil) : dash}</dd>
            <dt>{t('admin.p14.queue.col.created')}</dt>
            <dd>{formatDateTime(d.createdAt)}</dd>
            <dt>{t('admin.p14.queue.detail.sentAt')}</dt>
            <dd>{d.sentAt ? formatDateTime(d.sentAt) : dash}</dd>
          </dl>
          {d.status === 'SENDING' && <Callout tone="warning">{t('admin.p14.queue.detail.sendingNote')}</Callout>}
        </div>
      )}
    </Drawer>
  );
}
