// SAYFA: İtirazlar (/admin/moderation/appeals)
// API: GET /api/admin/moderation/appeals?status=OPEN|ACCEPTED|REJECTED&cursor=&size= , POST /api/admin/moderation/appeals/{id}/decide {accept, note} (api/moderation.ts).
// Kabul = içerik geri açılır ve ihlal iptal edilir; hata kodları ALREADY_RESOLVED / TARGET_NOT_REVERSIBLE çevrilmiş gösterilir.
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
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
  LoadMore,
  Modal,
  PageHeader,
  Skeleton,
  StatusPill,
  Tabs,
  Textarea,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminErrorMessage } from './campaigns/shared';
import { CsvButton } from './moderation/CsvButton';
import { csvName } from './moderation/p11Logic';
import styles from './moderation/moderation.module.css';

const STATUSES: AppealStatus[] = ['OPEN', 'ACCEPTED', 'REJECTED'];
const NOTE_MAX = 500;

export default function AppealsPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  usePageTitle(t('admin.appeals.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [status, setStatus] = useState<AppealStatus>('OPEN');
  const [deciding, setDeciding] = useState<{ appeal: AppealView; accept: boolean } | null>(null);
  const [note, setNote] = useState('');

  const query = useInfiniteQuery({
    queryKey: [...qk.moderation.appeals(status), 'pages'],
    queryFn: ({ pageParam }) => moderationApi.listAppeals({ status, cursor: pageParam, size: 20 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
  });
  const items = query.data?.pages.flatMap((p) => p.items) ?? [];

  const decide = useMutation({
    mutationFn: (v: { id: number; accept: boolean; note: string }) =>
      moderationApi.decideAppeal(v.id, v.accept, v.note.trim()),
    onSuccess: (_d, v) => {
      toast.success(t(v.accept ? 'admin.appeals.toast.accepted' : 'admin.appeals.toast.rejected'));
      setDeciding(null);
      setNote('');
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
      <Tabs
        label={t('admin.appeals.tabs')}
        value={status}
        onChange={(id) => setStatus(id as AppealStatus)}
        tabs={STATUSES.map((s) => ({ id: s, label: t(`admin.appeals.status.${s}`) }))}
      />
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
                    <Link to={paths.admin.user(a.userId)}>{t('admin.appeals.user', { id: a.userId })}</Link>
                    <span className={styles.spacer} />
                    <StatusPill tone={a.status === 'ACCEPTED' ? 'success' : a.status === 'REJECTED' ? 'danger' : 'warning'}>
                      {t(`admin.appeals.status.${a.status}`)}
                    </StatusPill>
                  </div>
                  <p className={styles.body} dir="auto">
                    {a.message}
                  </p>
                  <p className={styles.muted}>
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
                      <Button variant="secondary" onClick={() => setDeciding({ appeal: a, accept: false })}>
                        {t('admin.appeals.reject')}
                      </Button>
                      <Button onClick={() => setDeciding({ appeal: a, accept: true })}>{t('admin.appeals.accept')}</Button>
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
              disabled={note.length > NOTE_MAX}
              onClick={() => deciding && decide.mutate({ id: deciding.appeal.id, accept: deciding.accept, note })}
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
      </Modal>
    </>
  );
}
