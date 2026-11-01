// SAYFA: İtirazlar (/admin/moderation/appeals)
// API: GET /api/admin/moderation/appeals?status=OPEN|ACCEPTED|REJECTED&cursor=&size= , POST /api/admin/moderation/appeals/{id}/decide {accept, note} (api/moderation.ts).
// Kabul = içerik geri açılır ve ihlal iptal edilir; hata kodları ALREADY_RESOLVED / TARGET_NOT_REVERSIBLE çevrilmiş gösterilir.
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { modAdminApi, moderationApi, qk } from '../../api';
import type { AppealStatus, AppealView } from '../../api/types';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  Insight,
  LoadMore,
  Modal,
  PageHeader,
  Skeleton,
  StatusPill,
  Tabs,
  Textarea,
  useKitFormat,
  useToast,
} from '../../components/ui';
import { ReasonField } from '../../components/admin/guard/ReasonField';
import { ADMIN_REASON_MIN, isReasonValid } from '../../components/admin/guard/match';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminErrorMessage } from './campaigns/shared';
import { CsvButton } from './moderation/CsvButton';
import { csvName } from './moderation/p11Logic';
import { UserLabel } from './people/UserLabel';
import people from './people/people.module.css';
import styles from './moderation/moderation.module.css';

const STATUSES: AppealStatus[] = ['OPEN', 'ACCEPTED', 'REJECTED'];
const NOTE_MAX = 500;

export default function AppealsPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const kit = useKitFormat();
  usePageTitle(t('admin.appeals.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [status, setStatus] = useState<AppealStatus>('OPEN');
  const [deciding, setDeciding] = useState<{ appeal: AppealView; accept: boolean } | null>(null);
  const [note, setNote] = useState('');
  // W1-B (T-013): karar islem gerekcesi ister (X-Admin-Reason); `note` kullaniciya giden istege bagli nottan ayridir.
  const [why, setWhy] = useState('');

  const query = useInfiniteQuery({
    queryKey: [...qk.moderation.appeals(status), 'pages'],
    queryFn: ({ pageParam }) => moderationApi.listAppeals({ status, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
  });
  const items = query.data?.pages.flatMap((p) => p.items) ?? [];
  const openCount = useQuery({
    queryKey: [...qk.moderation.appeals('OPEN'), 'count'],
    queryFn: () => moderationApi.listAppeals({ status: 'OPEN', size: 50 }),
    retry: false,
  });
  const openN = openCount.data?.items.length;

  const decide = useMutation({
    mutationFn: (v: { id: number; accept: boolean; note: string; why: string }) =>
      moderationApi.decideAppeal(v.id, v.accept, v.note.trim(), { reason: v.why }),
    onSuccess: (_d, v) => {
      toast.success(t(v.accept ? 'admin.appeals.toast.accepted' : 'admin.appeals.toast.rejected'));
      setDeciding(null);
      setNote('');
      setWhy('');
      void qc.invalidateQueries({ queryKey: qk.moderation.all });
    },
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      setDeciding(null);
      void qc.invalidateQueries({ queryKey: qk.moderation.all });
    },
  });

  return (
    <>
      <PageHeader
        title={t('admin.appeals.title')}
        actions={
          <CsvButton filename={csvName('itirazlar')} fetcher={() => modAdminApi.exportAppealsCsv({ status })} />
        }
      />
      <p className={people.hint} style={{ marginBlockEnd: 'var(--space-3)' }} data-search-anchor="apl-explain">
        {t('admin.v2p.apl.explain')}
      </p>
      {status === 'OPEN' && items.length > 0 && (
        <Insight tone="warn" parts={t('admin.v2p.apl.sentence', { n: formatNumber(items.length) })} />
      )}
      <div data-search-anchor="apl-tabs">
        <Tabs
          label={t('admin.appeals.tabs')}
          value={status}
          onChange={(id) => setStatus(id as AppealStatus)}
          tabs={STATUSES.map((s) => ({
            id: s,
            label:
              s === 'OPEN' && openN !== undefined
                ? t('admin.v2p.sus.tabCount', { label: t(`admin.appeals.status.${s}`), n: formatNumber(openN) })
                : t(`admin.appeals.status.${s}`),
          }))}
        />
      </div>
      <div className={styles.stack}>
        {query.isError ? (
          <ErrorState description={adminErrorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
        ) : query.isLoading ? (
          <Skeleton height="6rem" width="100%" />
        ) : items.length === 0 ? (
          <EmptyState icon="flag" title={t('admin.appeals.empty.title')} description={t('admin.appeals.empty.hint')} />
        ) : (
          <>
            <ul className={styles.rowList}>
              {items.map((a) => (
                <li key={a.id} className={styles.item}>
                  <div className={styles.itemHead}>
                    <Badge tone="primary">{t(`admin.reports.targetType.${a.targetType}`)}</Badge>
                    <span className={`${styles.mono} ltr`}>#{a.targetId}</span>
                    <UserLabel userId={a.userId} fallback={t('admin.appeals.user', { id: a.userId })} />
                    <span className={styles.spacer} />
                    {a.status !== 'OPEN' && (
                      <StatusPill tone={a.status === 'ACCEPTED' ? 'success' : 'danger'}>
                        {t(`admin.appeals.status.${a.status}`)}
                      </StatusPill>
                    )}
                  </div>
                  <p className={people.hint}>
                    {t('admin.v2p.apl.about', { type: t(`admin.reports.targetType.${a.targetType}`) })}{' '}
                    <Link to={paths.admin.hiddenContent}>{t('admin.v2p.apl.seeHidden')}</Link>
                  </p>
                  <p className={styles.body} dir="auto">
                    {a.message}
                  </p>
                  <p className={styles.muted}>
                    {a.status === 'OPEN' ? `${t('admin.v2p.sus.waiting', { when: kit.relative(a.createdAt) })} · ` : ''}
                    {t('admin.appeals.createdAt', { at: formatDateTime(a.createdAt) })}
                    {a.decidedAt ? ` · ${t('admin.appeals.decidedAt', { at: formatDateTime(a.decidedAt) })}` : ''}
                  </p>
                  {a.adminNote && (
                    <p className={styles.muted} dir="auto">
                      {t('admin.appeals.adminNote', { note: a.adminNote })}
                    </p>
                  )}
                  {a.status === 'OPEN' && (
                    <div className={styles.actions}>
                      <p className={people.hint} style={{ flex: '1 1 100%' }}>{t('admin.v2p.apl.outcomes')}</p>
                      <Button variant="secondary" onClick={() => {
                          setWhy('');
                          setDeciding({ appeal: a, accept: false });
                        }}>
                        {t('admin.appeals.reject')}
                      </Button>
                      <Button onClick={() => {
                          setWhy('');
                          setDeciding({ appeal: a, accept: true });
                        }}>{t('admin.appeals.accept')}</Button>
                    </div>
                  )}
                </li>
              ))}
            </ul>
            <LoadMore
              hasMore={!!query.hasNextPage}
              loading={query.isFetchingNextPage}
              onLoadMore={() => void query.fetchNextPage()}
            />
          </>
        )}
      </div>

      <Modal
        open={!!deciding}
        onClose={() => setDeciding(null)}
        title={t(deciding?.accept ? 'admin.appeals.acceptTitle' : 'admin.appeals.rejectTitle')}
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setDeciding(null)}>
              {t('common.cancel')}
            </Button>
            <Button
              variant={deciding?.accept ? 'primary' : 'danger'}
              loading={decide.isPending}
              disabled={note.length > NOTE_MAX || !isReasonValid(why, ADMIN_REASON_MIN)}
              onClick={() => deciding && decide.mutate({ id: deciding.appeal.id, accept: deciding.accept, note, why })}
            >
              {t(deciding?.accept ? 'admin.appeals.accept' : 'admin.appeals.reject')}
            </Button>
          </>
        }
      >
        <p>{t(deciding?.accept ? 'admin.appeals.acceptBody' : 'admin.appeals.rejectBody')}</p>
        <FormField label={t('admin.appeals.noteLabel')} hint={t('admin.appeals.noteHint', { max: NOTE_MAX })}>
          <Textarea rows={3} dir="auto" value={note} maxLength={NOTE_MAX + 50} onChange={(e) => setNote(e.target.value)} />
        </FormField>
        <ReasonField
          value={why}
          onChange={setWhy}
          minLength={ADMIN_REASON_MIN}
          label={t('admin.wp02.actionReason.label')}
          disabled={decide.isPending}
          focusOnMount
        />
      </Modal>
    </>
  );
}
