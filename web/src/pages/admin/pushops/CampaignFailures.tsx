// Kampanya çekmecesi "Hatalar" bölümü: GET /api/admin/push/campaigns/{id}/failures (FCM hata koduna göre gruplu sayılar;
// alıcı kimliği yok). Kuyruk kayıtları 7-30 gün saklandığından eski kampanyalarda bağlı kayıt olmayabilir.
import { useQuery } from '@tanstack/react-query';
import { getCampaignFailures, OUTBOX_STATUSES, pushOpsKeys, type FailureGroup } from '../../../api/adminPushOps';
import { Skeleton, StatusPill, Table, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { Callout } from '../campaigns/shared';
import { codeKey, STATUS_TONE } from './lib';
import styles from './pushops.module.css';

export function CampaignFailures({ campaignId }: { campaignId: number }) {
  const { t, td, formatNumber, formatDateTime } = useI18n();
  const q = useQuery({
    queryKey: pushOpsKeys.failures(campaignId),
    queryFn: () => getCampaignFailures(campaignId),
    retry: false,
  });
  const d = q.data;

  const columns: Column<FailureGroup>[] = [
    {
      key: 'code',
      header: t('admin.p14.failures.col.code'),
      render: (g) => {
        const k = codeKey(g.errorCode);
        return (
          <span className={styles.cellStack}>
            <span className="ltr">{g.errorCode}</span>
            {k && <span className={styles.muted}>{td(k, g.errorCode)}</span>}
          </span>
        );
      },
    },
    {
      key: 'status',
      header: t('admin.p14.queue.col.status'),
      render: (g) => <StatusPill tone={STATUS_TONE[g.status]}>{t(`admin.p14.status.${g.status}`)}</StatusPill>,
    },
    { key: 'count', header: t('admin.p14.failures.col.count'), align: 'end', render: (g) => formatNumber(g.count) },
    { key: 'last', header: t('admin.p14.failures.col.last'), render: (g) => (g.lastAt ? formatDateTime(g.lastAt) : '—') },
  ];

  return (
    <section aria-labelledby={`pf-${campaignId}`}>
      <h3 id={`pf-${campaignId}`} className={styles.sectionTitle}>
        {t('admin.p14.failures.title')}
      </h3>
      {q.isLoading ? (
        <Skeleton width="100%" height="4em" />
      ) : q.isError || !d ? (
        <p className={styles.hint}>{t('admin.p14.failures.unavailable')}</p>
      ) : !d.linked ? (
        <p className={styles.hint}>{t('admin.p14.failures.notLinked')}</p>
      ) : (
        <div className={styles.stack}>
          <p className={styles.hint} data-testid="push-failure-totals">
            {OUTBOX_STATUSES.filter((s) => (d.totals[s] ?? 0) > 0)
              .map((s) => `${t(`admin.p14.status.${s}`)}: ${formatNumber(d.totals[s] ?? 0)}`)
              .join(' · ')}
          </p>
          {d.groups.length === 0 ? (
            <Callout tone="success">{t('admin.p14.failures.none')}</Callout>
          ) : (
            <>
              <Table
                caption={t('admin.p14.failures.table')}
                columns={columns}
                rows={d.groups}
                rowKey={(g) => `${g.status}:${g.errorCode}`}
              />
              {d.truncated && <p className={styles.hint}>{t('admin.p14.failures.truncated')}</p>}
            </>
          )}
        </div>
      )}
    </section>
  );
}
