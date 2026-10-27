// SAYFA: Anketler (/admin/polls) — anket listesi, oluşturma/düzenleme, sonuçlar, kapatma/iptal, CSV, menü puanları.
// API: GET/POST /api/admin/polls, PUT /{id}, POST /{id}/close|cancel, GET /{id}/results, GET /{id}/export.csv,
//      GET /api/admin/polls/menu-ratings (api/adminPolls.ts). Gizli ankette kimlik hiçbir yerde gösterilmez.
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { adminPollsApi, qk } from '../../api';
import type { AdminPoll, PollScope, PollStatus } from '../../api/adminPolls';
import {
  Badge,
  Button,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FormField,
  LoadMore,
  PageHeader,
  Select,
  Skeleton,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import { PollFormModal } from './polls/PollForm';
import { PollResultsDrawer } from './polls/PollResults';
import { canCancel, canClose, canEdit, statusTone } from './polls/pollsLogic';
import styles from './polls/polls.module.css';

const STATUSES: PollStatus[] = ['DRAFT', 'SCHEDULED', 'ACTIVE', 'CLOSED', 'CANCELLED'];
const SCOPES: PollScope[] = ['GENERAL', 'COMMUNITY', 'EVENT', 'MENU'];

function MenuRatings() {
  const i18n = useI18n();
  const { t, formatNumber, formatDate } = i18n;
  const q = useQuery({ queryKey: qk.adminPolls.menuRatings(), queryFn: adminPollsApi.menuRatings, staleTime: 60_000 });
  const items = q.data?.items ?? [];
  return (
    <section className={styles.section} aria-labelledby="menu-ratings-h">
      <h2 id="menu-ratings-h">{t('admin.polls.menu.title')}</h2>
      {q.isError ? (
        <ErrorState description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : q.isLoading ? (
        <Skeleton height="6rem" width="100%" />
      ) : items.length === 0 ? (
        <EmptyState icon="chart" title={t('admin.polls.menu.empty')} description=" " />
      ) : (
        <ul className={styles.list} data-testid="menu-ratings">
          {items.map((m) => (
            <li key={`${m.date}-${m.meal}`} className={styles.row}>
              <div className={styles.rowHead}>
                <strong>{formatDate(m.date)}</strong>
                <span className={styles.muted}>{m.meal}</span>
                <span className={styles.spacer} />
                <Badge tone="primary">{formatNumber(Math.round(m.average * 100) / 100)} / 5</Badge>
                <span className={styles.muted}>{t('admin.polls.menu.count', { n: formatNumber(m.count) })}</span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default function PollsAdminPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.polls.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [status, setStatus] = useState<PollStatus | ''>('');
  const [scope, setScope] = useState<PollScope | ''>('');
  const [form, setForm] = useState<{ poll: AdminPoll | null } | null>(null);
  const [results, setResults] = useState<AdminPoll | null>(null);
  const [confirm, setConfirm] = useState<{ poll: AdminPoll; kind: 'close' | 'cancel' } | null>(null);
  const f = useMemo(() => ({ status, scope }), [status, scope]);

  const list = useInfiniteQuery({
    queryKey: qk.adminPolls.list(f),
    queryFn: ({ pageParam }) => adminPollsApi.listPolls(f, pageParam, 20),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    staleTime: 15_000,
  });
  const rows = useMemo(() => list.data?.pages.flatMap((p) => p.items) ?? [], [list.data]);

  const act = useMutation({
    mutationFn: ({ poll, kind }: { poll: AdminPoll; kind: 'close' | 'cancel' }) =>
      kind === 'close' ? adminPollsApi.closePoll(poll.id) : adminPollsApi.cancelPoll(poll.id),
    onSuccess: () => {
      toast.success(t('admin.polls.updated'));
      setConfirm(null);
      void qc.invalidateQueries({ queryKey: ['adminPolls'] });
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });

  return (
    <>
      <PageHeader
        title={t('admin.polls.title')}
        description={t('admin.polls.subtitle')}
        actions={
          <Button onClick={() => setForm({ poll: null })} data-testid="poll-new">
            {t('admin.polls.create')}
          </Button>
        }
      />
      <div className={styles.filters} role="search" aria-label={t('admin.polls.filters')}>
        <FormField label={t('admin.polls.filter.status')}>
          <Select value={status} onChange={(e) => setStatus(e.target.value as PollStatus | '')}>
            <option value="">{t('admin.polls.filter.all')}</option>
            {STATUSES.map((s) => (
              <option key={s} value={s}>
                {t(`admin.polls.status.${s}` as 'admin.polls.status.DRAFT')}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.polls.filter.scope')}>
          <Select value={scope} onChange={(e) => setScope(e.target.value as PollScope | '')}>
            <option value="">{t('admin.polls.filter.all')}</option>
            {SCOPES.map((s) => (
              <option key={s} value={s}>
                {t(`admin.polls.scope.${s}` as 'admin.polls.scope.GENERAL')}
              </option>
            ))}
          </Select>
        </FormField>
      </div>

      {list.isError ? (
        <ErrorState description={adminErrorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : list.isLoading ? (
        <Skeleton height="12rem" width="100%" />
      ) : rows.length === 0 ? (
        <EmptyState icon="chart" title={t('admin.polls.empty')} description=" " />
      ) : (
        <>
          <ul className={styles.list} data-testid="poll-list">
            {rows.map((p) => (
              <li key={p.id} className={styles.row} data-testid="poll-row">
                <div className={styles.rowHead}>
                  <h3 className={styles.title} dir="auto">
                    {p.title}
                  </h3>
                  <Badge tone={statusTone(p.status)}>{t(`admin.polls.status.${p.status}` as 'admin.polls.status.DRAFT')}</Badge>
                  <Badge>{t(`admin.polls.type.${p.type}` as 'admin.polls.type.SINGLE')}</Badge>
                  <Badge>{t(`admin.polls.scope.${p.scope}` as 'admin.polls.scope.GENERAL')}</Badge>
                  {p.anonymous && <Badge tone="info">{t('admin.polls.anonymous')}</Badge>}
                </div>
                <div className={styles.muted}>
                  {t('admin.polls.votes', { n: formatNumber(p.voteCount) })}
                  {p.startsAt && ` · ${t('admin.polls.starts')}: ${formatDateTime(p.startsAt)}`}
                  {p.endsAt && ` · ${t('admin.polls.ends')}: ${formatDateTime(p.endsAt)}`}
                </div>
                <div className={styles.actions}>
                  <Button size="sm" variant="secondary" onClick={() => setResults(p)}>
                    {t('admin.polls.results')}
                  </Button>
                  {canEdit(p) && (
                    <Button size="sm" variant="secondary" onClick={() => setForm({ poll: p })}>
                      {t('admin.polls.edit')}
                    </Button>
                  )}
                  {canClose(p) && (
                    <Button size="sm" variant="secondary" onClick={() => setConfirm({ poll: p, kind: 'close' })}>
                      {t('admin.polls.close')}
                    </Button>
                  )}
                  {canCancel(p) && (
                    <Button size="sm" variant="danger" onClick={() => setConfirm({ poll: p, kind: 'cancel' })}>
                      {t('admin.polls.cancel')}
                    </Button>
                  )}
                </div>
              </li>
            ))}
          </ul>
          <LoadMore hasMore={!!list.hasNextPage} loading={list.isFetchingNextPage} onLoadMore={() => void list.fetchNextPage()} />
        </>
      )}

      <MenuRatings />

      {form && <PollFormModal poll={form.poll} onClose={() => setForm(null)} />}
      {results && <PollResultsDrawer poll={results} onClose={() => setResults(null)} />}
      <ConfirmDialog
        open={confirm !== null}
        onClose={() => setConfirm(null)}
        onConfirm={() => confirm && act.mutate(confirm)}
        title={confirm?.kind === 'close' ? t('admin.polls.close') : t('admin.polls.cancel')}
        message={confirm?.kind === 'close' ? t('admin.polls.closeMessage') : t('admin.polls.cancelMessage')}
        confirmLabel={confirm?.kind === 'close' ? t('admin.polls.close') : t('admin.polls.cancel')}
        danger={confirm?.kind === 'cancel'}
        loading={act.isPending}
      />
    </>
  );
}
