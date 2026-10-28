import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { adminPollsApi, qk } from '../../../api';
import type { PollDetail } from '../../../api/adminPolls';
import { Badge, Button, Drawer, EmptyState, ErrorState, GuardedAction, Skeleton, StatCard, useToast } from '../../../components/ui';
import { useI18n, type I18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import { downloadBlob } from '../users/filters';
import { canCancel, canClose, canEdit, clampPercent, stateTone } from './pollsLogic';
import styles from './polls.module.css';

/** Seçenek metni + sonuç satırı (sonuç seçenek kimliğiyle eşleşir; kimlik/oy veren bilgisi yoktur). */
function OptionBars({ poll, i18n }: { poll: PollDetail; i18n: I18n }) {
  const { t, formatNumber } = i18n;
  const results = new Map((poll.results ?? []).map((r) => [r.optionId, r]));
  const pct = (v: number) => `${formatNumber(Math.round(v * 10) / 10)}%`;
  if (poll.options.length === 0) return <EmptyState icon="chart" title={t('admin.p03.res.empty')} description=" " />;
  return (
    <ul className={styles.bars} aria-label={t('admin.p03.res.chart')} data-testid="poll-bars">
      {poll.options.map((o) => {
        const r = results.get(o.id);
        const count = r?.count ?? 0;
        const percent = r?.percent ?? 0;
        return (
          <li key={o.id} className={styles.bar}>
            <div className={styles.barHead}>
              <span dir="auto">{poll.type === 'RATING' ? t('admin.p03.res.stars', { n: o.position }) : o.text}</span>
              <span className="ltr">
                {formatNumber(count)} · {pct(percent)}
                {r?.score != null && ` · ${t('admin.p03.res.score', { n: formatNumber(r.score) })}`}
              </span>
            </div>
            <div className={styles.track} role="img" aria-label={`${o.text}: ${pct(percent)}`}>
              <span className={styles.fill} style={{ inlineSize: `${clampPercent(percent)}%` }} />
            </div>
          </li>
        );
      })}
    </ul>
  );
}

/** Anket ayrıntısı + sonuçlar (GET /admin/polls/{id}); kapat/iptal/sil eylemleri sebep ister. */
export function PollDetailDrawer({
  id,
  onClose,
  onEdit,
}: {
  id: number;
  onClose: () => void;
  onEdit: (poll: PollDetail) => void;
}) {
  const i18n = useI18n();
  const { t, formatNumber, formatDateTime, formatDate } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const q = useQuery({ queryKey: qk.adminPolls.detail(id), queryFn: () => adminPollsApi.getPoll(id) });
  const p = q.data;
  const csv = useMutation({
    mutationFn: () => adminPollsApi.exportPollCsv(id),
    onSuccess: (b) => downloadBlob(b, `poll-${id}.csv`),
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  const refresh = () => void qc.invalidateQueries({ queryKey: ['adminPolls'] });
  const pctNum = (v: number | null | undefined) => (v == null ? '—' : `${formatNumber(Math.round(v * 10) / 10)}%`);

  return (
    <Drawer
      open
      onClose={onClose}
      title={p?.title ?? t('admin.p03.detail.title')}
      size="lg"
      footer={
        <>
          <Button variant="secondary" loading={csv.isPending} disabled={!p} onClick={() => csv.mutate()}>
            {t('admin.p03.exportCsv')}
          </Button>
          <Button onClick={onClose}>{t('common.close')}</Button>
        </>
      }
    >
      {q.isError ? (
        <ErrorState description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : q.isLoading || !p ? (
        <Skeleton height="10rem" width="100%" />
      ) : (
        <div className={styles.form} data-testid="poll-detail">
          <div className={styles.rowHead}>
            <Badge tone={stateTone(p.state)}>{i18n.td(`admin.p03.state.${p.state}`, p.state)}</Badge>
            <Badge>{i18n.td(`admin.p03.type.${p.type}`, p.type)}</Badge>
            <Badge>{i18n.td(`admin.p03.scope.${p.scope}`, p.scope)}</Badge>
            {p.anonymous && <Badge tone="info">{t('admin.p03.anonymous')}</Badge>}
          </div>
          {p.description && (
            <p className={styles.desc} dir="auto">
              {p.description}
            </p>
          )}
          <dl className={styles.meta}>
            {p.opensAt && (
              <>
                <dt>{t('admin.p03.field.opensAt')}</dt>
                <dd>{formatDateTime(p.opensAt)}</dd>
              </>
            )}
            <dt>{t('admin.p03.field.closesAt')}</dt>
            <dd>{p.closesAt ? formatDateTime(p.closesAt) : t('admin.p03.noClose')}</dd>
            <dt>{t('admin.p03.field.showResults')}</dt>
            <dd>{i18n.td(`admin.p03.showResults.${p.showResults}`, p.showResults)}</dd>
            {p.communityId !== null && (
              <>
                <dt>{t('admin.p03.club')}</dt>
                <dd dir="auto">{p.communityName ?? `#${p.communityId}`}</dd>
              </>
            )}
            {p.menuDate && (
              <>
                <dt>{t('admin.p03.menuDate')}</dt>
                <dd>{formatDate(p.menuDate)}</dd>
              </>
            )}
            {p.audience && (
              <>
                <dt>{t('admin.p03.field.audience')}</dt>
                <dd dir="auto">{[p.audience.faculty, p.audience.department, p.audience.grade].filter(Boolean).join(' · ')}</dd>
              </>
            )}
            {p.createdBy && (
              <>
                <dt>{t('admin.p03.createdBy')}</dt>
                <dd dir="auto">{p.createdBy.displayName ?? `#${p.createdBy.id}`}</dd>
              </>
            )}
          </dl>
          {p.menuItems && p.menuItems.length > 0 && (
            <p className={styles.muted} dir="auto">
              {p.menuItems.join(' · ')}
            </p>
          )}

          <div className={styles.grid2} data-testid="poll-results">
            <StatCard title={t('admin.p03.res.votes')} value={formatNumber(p.turnout?.voted ?? p.totalVotes ?? 0)} />
            <StatCard title={t('admin.p03.res.eligible')} value={p.turnout?.eligible == null ? '—' : formatNumber(p.turnout.eligible)} />
            <StatCard title={t('admin.p03.res.participation')} value={pctNum(p.turnout?.percent)} />
            {p.type === 'RATING' && (
              <StatCard title={t('admin.p03.res.average')} value={p.average == null ? '—' : formatNumber(p.average)} />
            )}
          </div>
          <p className={styles.muted}>{t(p.anonymous ? 'admin.p03.res.anonymousNote' : 'admin.p03.res.noIdentityNote')}</p>
          <OptionBars poll={p} i18n={i18n} />

          <div className={styles.actions}>
            {canEdit(p) && (
              <Button variant="secondary" size="sm" onClick={() => onEdit(p)}>
                {t('admin.p03.edit')}
              </Button>
            )}
            {canClose(p.state) && (
              <GuardedAction
                size="sm"
                variant="secondary"
                title={t('admin.p03.close.title')}
                message={t('admin.p03.close.message', { title: p.title })}
                consequence={t('admin.p03.close.consequence')}
                irreversible={false}
                requireReason
                confirmLabel={t('admin.p03.close')}
                successMessage={t('admin.p03.updated')}
                invalidateKeys={[['adminPolls']]}
                onConfirm={({ reason, idempotencyKey }) => adminPollsApi.closePoll(p.id, { reason, idempotencyKey })}
              >
                {t('admin.p03.close')}
              </GuardedAction>
            )}
            {canCancel(p.state) && (
              <GuardedAction
                size="sm"
                variant="danger"
                danger
                title={t('admin.p03.cancel.title')}
                message={t('admin.p03.cancel.message', { title: p.title })}
                consequence={t('admin.p03.cancel.consequence')}
                irreversible
                requireReason
                confirmLabel={t('admin.p03.cancel')}
                successMessage={t('admin.p03.updated')}
                invalidateKeys={[['adminPolls']]}
                onConfirm={({ reason, idempotencyKey }) => adminPollsApi.cancelPoll(p.id, { reason, idempotencyKey })}
              >
                {t('admin.p03.cancel')}
              </GuardedAction>
            )}
            <GuardedAction
              size="sm"
              variant="danger"
              danger
              title={t('admin.p03.delete.title')}
              message={t('admin.p03.delete.message', { title: p.title })}
              consequence={t('admin.p03.delete.consequence')}
              irreversible
              requireReason
              typeToConfirm={t('admin.p03.delete.confirmWord')}
              confirmLabel={t('admin.p03.delete')}
              successMessage={t('admin.p03.deleted')}
              invalidateKeys={[['adminPolls']]}
              onConfirm={({ reason, idempotencyKey }) => adminPollsApi.deletePoll(p.id, { reason, idempotencyKey })}
              onSuccess={() => {
                refresh();
                onClose();
              }}
            >
              {t('admin.p03.delete')}
            </GuardedAction>
          </div>
        </div>
      )}
    </Drawer>
  );
}
