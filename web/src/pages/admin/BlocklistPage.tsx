// SAYFA: Yasaklı görseller (/admin/moderation/blocklist)
// API: GET /api/admin/moderation/blocklist?cursor=<sha256>&size= , POST .../blocklist {sha256 (64 hex), note?} (201, idempotent),
//      DELETE .../blocklist/{sha256} (204/404) (api/moderation.ts). Yüklemelerde özeti eşleşen görsel reddedilir (medya hattı).
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
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
  Insight,
  LoadMore,
  PageHeader,
  Skeleton,
  StatTile,
  useToast,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import { isValidSha256, normalizeSha256 } from './moderation/modLogic';
import styles from './moderation/moderation.module.css';
import v2 from './moderation/v2.module.css';

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
  const [fileName, setFileName] = useState('');
  const [hashing, setHashing] = useState<'idle' | 'busy' | 'unsupported' | 'failed'>('idle');
  const fileRef = useRef<HTMLInputElement>(null);

  // B-1: görseli seçince SHA-256 özeti tarayıcıda hesaplanır (dosya sunucuya gitmez); API aynı kalır.
  async function onPickFile(file: File | undefined) {
    if (!file) return;
    setFileName(file.name);
    if (typeof crypto === 'undefined' || !crypto.subtle) {
      setHashing('unsupported');
      return;
    }
    setHashing('busy');
    try {
      const digest = await crypto.subtle.digest('SHA-256', await file.arrayBuffer());
      setSha(Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join(''));
      setHashing('idle');
    } catch {
      setHashing('failed');
    }
  }

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
      toast.success(t('admin.v2m.bl.added'));
      setSha('');
      setFileName('');
      if (fileRef.current) fileRef.current.value = '';
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
      <PageHeader title={t('admin.blocklist.title')} description={t('admin.v2m.bl.desc')} />
      <div className={styles.stack}>
        <div className={v2.tiles} data-search-anchor="blocklist-summary">
          <StatTile
            label={t('admin.v2m.bl.tile')}
            value={query.isSuccess ? items.length : undefined}
            icon="shield"
            loading={query.isLoading}
            error={query.isError}
            onRetry={() => void query.refetch()}
            caption={t(query.hasNextPage ? 'admin.v2m.bl.tileMore' : 'admin.v2m.bl.tileHint')}
          />
        </div>
        {query.isSuccess && <Insight parts={[t('admin.v2m.bl.sentence')]} />}
        <Card title={t('admin.blocklist.add')} data-search-anchor="blocklist-add">
          <form
            className={styles.formGrid}
            onSubmit={(e) => {
              e.preventDefault();
              setTouched(true);
              if (!shaInvalid) add.mutate();
            }}
          >
            <div className={styles.wide}>
              <FormField label={t('admin.v2m.bl.pick')} hint={t('admin.v2m.bl.pickHint')}>
                <input
                  ref={fileRef}
                  type="file"
                  accept="image/*"
                  className={v2.fileInput}
                  data-search-anchor="blocklist-file"
                  onChange={(e) => void onPickFile(e.target.files?.[0])}
                />
              </FormField>
              {hashing === 'busy' && <p className={v2.hint}>{t('admin.v2m.bl.hashing')}</p>}
              {hashing === 'unsupported' && <p className={v2.hint}>{t('admin.v2m.bl.unsupported')}</p>}
              {hashing === 'failed' && <p className={v2.hint}>{t('admin.v2m.bl.failed')}</p>}
              {fileName && isValidSha256(sha) && (
                <p className={v2.hint} role="status">
                  {t('admin.v2m.bl.hashed', { name: fileName })}
                </p>
              )}
            </div>
            <div className={styles.wide}>
              <FormField
                label={t('admin.blocklist.sha')}
                hint={t('admin.v2m.bl.shaHint')}
                error={touched && shaInvalid ? t('admin.blocklist.shaInvalid') : null}
                required
              >
                <Input className="ltr" value={sha} maxLength={80} autoComplete="off" onChange={(e) => setSha(e.target.value)} />
              </FormField>
            </div>
            <div className={styles.wide}>
              <FormField label={t('admin.blocklist.note')} hint={t('admin.v2m.bl.noteHint')}>
                <Input value={note} maxLength={NOTE_MAX} dir="auto" onChange={(e) => setNote(e.target.value)} />
              </FormField>
            </div>
            <div className={v2.touch}>
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
          <EmptyState icon="shield" title={t('admin.blocklist.empty.title')} description={t('admin.v2m.bl.emptyHint')} />
        ) : (
          <>
            <ul className={styles.rowList} aria-label={t('admin.blocklist.title')}>
              {items.map((e) => (
                <li key={e.sha256} className={styles.item}>
                  <div className={styles.itemHead}>
                    <code className={`${styles.mono} ltr`}>{e.sha256}</code>
                    <CopyButton value={e.sha256} />
                    <span className={styles.spacer} />
                    <span className={v2.touch}>
                      <Button size="sm" variant="ghost" className={v2.softDanger} onClick={() => setRemoving(e)}>
                        {t('admin.blocklist.remove')}
                      </Button>
                    </span>
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
