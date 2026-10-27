import { useMutation, useQuery } from '@tanstack/react-query';
import { adminPollsApi, qk } from '../../../api';
import type { AdminPoll } from '../../../api/adminPolls';
import { Button, Drawer, EmptyState, ErrorState, Skeleton, StatCard } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import { downloadBlob } from '../users/filters';
import styles from './polls.module.css';

/** Sonuç görünümü: GET /admin/polls/{id}/results, CSV: /export.csv. Gizli ankette kimlik gösterilmez. */
export function PollResultsDrawer({ poll, onClose }: { poll: AdminPoll; onClose: () => void }) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const q = useQuery({ queryKey: qk.adminPolls.results(poll.id), queryFn: () => adminPollsApi.pollResults(poll.id) });
  const csv = useMutation({
    mutationFn: () => adminPollsApi.exportPollCsv(poll.id),
    onSuccess: (b) => downloadBlob(b, `poll-${poll.id}.csv`),
  });
  const r = q.data;
  const pct = (v: number) => `${formatNumber(Math.round(v * 10) / 10)}%`;
  return (
    <Drawer
      open
      onClose={onClose}
      title={poll.title}
      size="lg"
      footer={
        <>
          <Button variant="secondary" loading={csv.isPending} disabled={!r} onClick={() => csv.mutate()}>
            {t('admin.polls.exportCsv')}
          </Button>
          <Button onClick={onClose}>{t('common.close')}</Button>
        </>
      }
    >
      {q.isError ? (
        <ErrorState description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : q.isLoading || !r ? (
        <Skeleton height="10rem" width="100%" />
      ) : (
        <div className={styles.form} data-testid="poll-results">
          <div className={styles.grid2}>
            <StatCard title={t('admin.polls.res.votes')} value={formatNumber(r.totalVotes)} />
            <StatCard title={t('admin.polls.res.eligible')} value={formatNumber(r.eligibleCount)} />
            <StatCard title={t('admin.polls.res.participation')} value={pct(r.participationRate * 100)} />
            {r.type === 'RATING' && r.average != null && (
              <StatCard title={t('admin.polls.res.average')} value={formatNumber(Math.round(r.average * 100) / 100)} />
            )}
          </div>
          {r.anonymous && <p className={styles.muted}>{t('admin.polls.res.anonymousNote')}</p>}
          {r.options.length === 0 ? (
            <EmptyState icon="chart" title={t('admin.polls.res.empty')} description=" " />
          ) : (
            <ul className={styles.bars} aria-label={t('admin.polls.res.chart')}>
              {r.options.map((o) => (
                <li key={o.id} className={styles.bar}>
                  <div className={styles.barHead}>
                    <span dir="auto">{o.text}</span>
                    <span className="ltr">
                      {formatNumber(o.votes)} · {pct(o.percent)}
                    </span>
                  </div>
                  <div className={styles.track} role="img" aria-label={`${o.text}: ${pct(o.percent)}`}>
                    <span className={styles.fill} style={{ inlineSize: `${Math.min(100, Math.max(0, o.percent))}%` }} />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </Drawer>
  );
}
