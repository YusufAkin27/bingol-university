// DEAD (vazgeçilmiş) push kayıtlarının hata kodu dağılımı. Sunucuda bu kırılım yalnız actuator sağlık göstergesindedir;
// panel, en yeni DEAD kayıtların bir örnekleminden (listOutbox status=DEAD) istemci tarafında gruplar (A3-23).
import { useQuery } from '@tanstack/react-query';
import { listOutbox, pushOpsKeys } from '../../../api/adminPushOps';
import { Card, ErrorState, Skeleton, Table, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { codeKey, groupByErrorCode } from './lib';
import styles from './pushops.module.css';

/** Örneklem büyüklüğü (sunucu sayfa üst sınırı içinde). */
export const DEAD_SAMPLE = 100;

export function DeadCodes() {
  const i18n = useI18n();
  const { t, td, formatNumber } = i18n;
  const q = useQuery({
    queryKey: [...pushOpsKeys.outboxAll(), 'dead-codes'],
    queryFn: () => listOutbox({ status: 'DEAD', page: 0, size: DEAD_SAMPLE }),
    staleTime: 30_000,
  });
  if (q.isError) {
    return (
      <Card title={t('admin.p14.dead.title')}>
        <ErrorState compact onRetry={() => void q.refetch()} description={adminError(i18n, q.error, 'admin.p14.err')} />
      </Card>
    );
  }
  if (!q.data) {
    return (
      <Card title={t('admin.p14.dead.title')}>
        <Skeleton width="100%" height="5em" />
      </Card>
    );
  }
  const groups = groupByErrorCode(q.data.items);
  const cols: Column<{ code: string; count: number }>[] = [
    { key: 'code', header: t('admin.p14.dead.col.code'), render: (r) => <span className="ltr">{r.code}</span> },
    {
      key: 'meaning',
      header: t('admin.p14.dead.col.meaning'),
      render: (r) => {
        const k = codeKey(r.code);
        return k ? td(k, r.code) : <span className={styles.muted}>—</span>;
      },
    },
    { key: 'count', header: t('admin.p14.dead.col.count'), align: 'end', render: (r) => formatNumber(r.count) },
  ];
  return (
    <Card title={t('admin.p14.dead.title')}>
      <p className={styles.hint}>{t('admin.p14.dead.note', { n: formatNumber(Math.min(DEAD_SAMPLE, q.data.totalItems)) })}</p>
      <Table
        caption={t('admin.p14.dead.caption')}
        columns={cols}
        rows={groups}
        rowKey={(r) => r.code}
        empty={<p className={styles.hint}>{t('admin.p14.dead.empty')}</p>}
      />
    </Card>
  );
}
