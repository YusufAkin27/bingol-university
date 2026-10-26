// SAYFA: Yasaklı görseller (/admin/moderation/blocklist)
// API: GET /api/admin/moderation/blocklist?cursor=<sha256>&size= , POST .../blocklist {sha256 (64 hex), note?} (201, idempotent),
//      DELETE .../blocklist/{sha256} (204/404) (api/moderation.ts). Yüklemelerde özeti eşleşen görsel reddedilir (medya hattı).
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { moderationApi, qk } from '../../api';
import type { BlocklistEntry } from '../../api/types';
import {
  Button,
  Card,
  ConfirmDialog,
  CopyButton,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  LoadMore,
  PageHeader,
  Skeleton,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import { isValidSha256, normalizeSha256 } from './moderation/modLogic';
import styles from './moderation/moderation.module.css';

const NOTE_MAX = 300;

export default function BlocklistPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  usePageTitle(t('admin.blocklist.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [sha, setSha] = useState('');
  const [note, setNote] = useState('');
  const [touched, setTouched] = useState(false);
  const [removing, setRemoving] = useState<BlocklistEntry | null>(null);

  const query = useInfiniteQuery({
    queryKey: [...qk.moderation.blocklist(), 'pages'],
    queryFn: ({ pageParam }) => moderationApi.listBlocklist({ cursor: pageParam, size: 50 }),
    initialPageParam: null as string | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
  });
  const items = query.data?.pages.flatMap((p) => p.items) ?? [];

  const add = useMutation({
    mutationFn: () => moderationApi.addBlocklist(normalizeSha256(sha), note.trim()),
    onSuccess: () => {
      toast.success(t('admin.blocklist.toast.added'));
      setSha('');
      setNote('');
      setTouched(false);
      void qc.invalidateQueries({ queryKey: qk.moderation.blocklist() });
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  const remove = useMutation({
    mutationFn: (e: BlocklistEntry) => moderationApi.removeBlocklist(e.sha256),
    onSuccess: () => {
      toast.success(t('admin.blocklist.toast.removed'));
      setRemoving(null);
      void qc.invalidateQueries({ queryKey: qk.moderation.blocklist() });
    },
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      setRemoving(null);
      void qc.invalidateQueries({ queryKey: qk.moderation.blocklist() });
    },
  });

  const shaInvalid = !isValidSha256(sha);

  return (
    <>
      <PageHeader title={t('admin.blocklist.title')} />
      <div className={styles.stack}>
        <Card title={t('admin.blocklist.add')}>
          <form
            className={styles.formGrid}
            onSubmit={(e) => {
              e.preventDefault();
              setTouched(true);
              if (!shaInvalid) add.mutate();
            }}
          >
            <div className={styles.wide}>
              <FormField
                label={t('admin.blocklist.sha')}
                error={touched && shaInvalid ? t('admin.blocklist.shaInvalid') : null}
                required
              >
                <Input className="ltr" value={sha} maxLength={80} autoComplete="off" onChange={(e) => setSha(e.target.value)} />
              </FormField>
            </div>
            <div className={styles.wide}>
              <FormField label={t('admin.blocklist.note')}>
                <Input value={note} maxLength={NOTE_MAX} dir="auto" onChange={(e) => setNote(e.target.value)} />
              </FormField>
            </div>
            <div>
              <Button type="submit" loading={add.isPending}>
                {t('admin.blocklist.addBtn')}
              </Button>
            </div>
          </form>
        </Card>

        {query.isError ? (
          <ErrorState description={adminErrorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
        ) : query.isLoading ? (
          <Skeleton height="5rem" width="100%" />
        ) : items.length === 0 ? (
          <EmptyState icon="shield" title={t('admin.blocklist.empty.title')} description={t('admin.blocklist.empty.hint')} />
        ) : (
          <>
            <ul className={styles.rowList} aria-label={t('admin.blocklist.title')}>
              {items.map((e) => (
                <li key={e.sha256} className={styles.item}>
                  <div className={styles.itemHead}>
                    <code className={`${styles.mono} ltr`}>{e.sha256}</code>
                    <CopyButton value={e.sha256} />
                    <span className={styles.spacer} />
                    <Button size="sm" variant="danger" onClick={() => setRemoving(e)}>
                      {t('admin.blocklist.remove')}
                    </Button>
                  </div>
                  {e.note && (
                    <p className={styles.body} dir="auto">
                      {e.note}
                    </p>
                  )}
                  <p className={styles.muted}>
                    {formatDateTime(e.createdAt)}
                    {e.createdBy ? ` · ${t('admin.blocklist.by', { id: e.createdBy })}` : ''}
                  </p>
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
      <ConfirmDialog
        open={!!removing}
        onClose={() => setRemoving(null)}
        onConfirm={() => removing && remove.mutate(removing)}
        loading={remove.isPending}
        danger
        title={t('admin.blocklist.removeTitle')}
        message={t('admin.blocklist.removeBody')}
        confirmLabel={t('admin.blocklist.remove')}
      />
    </>
  );
}
