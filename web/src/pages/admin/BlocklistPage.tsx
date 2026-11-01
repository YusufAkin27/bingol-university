// SAYFA: Yasaklı görseller (/admin/moderation/blocklist)
// API: GET /api/admin/moderation/blocklist?cursor=<sha256>&size= , POST .../blocklist {sha256 (64 hex), note?} (201, idempotent),
//      DELETE .../blocklist/{sha256} (204/404) (api/moderation.ts). Yüklemelerde özeti eşleşen görsel reddedilir (medya hattı).
// Mod1: listede arama (özet/not), eklenme yaşı grafiği, son 7 gün göstergesi ve toplu kaldırma.
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useRef, useState } from 'react';
import { moderationApi, qk } from '../../api';
import type { BlocklistEntry } from '../../api/types';
import {
  BulkBar,
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
import { BulkRunDialog, useBatchToast } from './yaptirimMod1/BulkRunDialog';
import { useGt } from './yaptirimMod1/dict';
import { QueueAgePanel } from './yaptirimMod1/QueueAgePanel';
import { ageMs, DAY_MS } from './yaptirimMod1/queueLogic';
import q from './yaptirimMod1/yaptirim.module.css';

const NOTE_MAX = 300;
/** Özet ekleme/silme "yıkıcı" sayılır (saatte en çok 20, docs/ADMIN_API.md): toplu kaldırma bu kadarla sınırlıdır. */
const BULK_MAX = 20;
/** Tarayıcı belleğini korumak için: bundan büyük görsel özetlenmez (yükleme sınırlarının çok üstünde). */
const FILE_MAX_BYTES = 25 * 1024 * 1024;

export default function BlocklistPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const gt = useGt();
  const batchToast = useBatchToast();
  usePageTitle(t('admin.blocklist.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [sha, setSha] = useState('');
  const [note, setNote] = useState('');
  const [touched, setTouched] = useState(false);
  const [removing, setRemoving] = useState<BlocklistEntry | null>(null);
  const [filter, setFilter] = useState('');
  const [selected, setSelected] = useState<ReadonlySet<string>>(new Set());
  const [bulkOpen, setBulkOpen] = useState(false);
  const [fileName, setFileName] = useState('');
  const [hashing, setHashing] = useState<'idle' | 'busy' | 'unsupported' | 'failed' | 'tooBig'>('idle');
  /** Dosyadan hesaplanan özet (alandaki değerle eşleşiyorsa "hazır" mesajı gösterilir). */
  const [hashedSha, setHashedSha] = useState('');
  /** Art arda seçimlerde yalnız en son seçimin sonucu geçerlidir. */
  const pickSeq = useRef(0);
  const fileRef = useRef<HTMLInputElement>(null);

  // B-1: görseli seçince SHA-256 özeti tarayıcıda hesaplanır (dosya sunucuya gitmez); API aynı kalır.
  async function onPickFile(file: File | undefined) {
    const seq = ++pickSeq.current;
    // Her yeni seçimde önceki dosyanın özeti alanda KALMAZ (yanlış görseli yasaklamayı önler)
    setSha('');
    setHashedSha('');
    if (!file) {
      setFileName('');
      setHashing('idle');
      return;
    }
    setFileName(file.name);
    if (file.size > FILE_MAX_BYTES) {
      setHashing('tooBig');
      return;
    }
    if (typeof crypto === 'undefined' || !crypto.subtle) {
      setHashing('unsupported');
      return;
    }
    setHashing('busy');
    try {
      const digest = await crypto.subtle.digest('SHA-256', await file.arrayBuffer());
      if (seq !== pickSeq.current) return;
      const hex = Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
      setSha(hex);
      setHashedSha(hex);
      setHashing('idle');
    } catch {
      if (seq === pickSeq.current) setHashing('failed');
    }
  }

  const query = useInfiniteQuery({
    queryKey: [...qk.moderation.blocklist(), 'pages'],
    queryFn: ({ pageParam }) => moderationApi.listBlocklist({ cursor: pageParam, size: 50 }),
    initialPageParam: null as string | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
  });
  const items = useMemo(() => query.data?.pages.flatMap((p) => p.items) ?? [], [query.data]);
  const now = query.dataUpdatedAt || Date.now();
  const needle = filter.trim().toLowerCase();
  const visible = useMemo(
    () =>
      needle === ''
        ? items
        : items.filter((e) => e.sha256.includes(needle) || (e.note ?? '').toLowerCase().includes(needle)),
    [items, needle],
  );
  const dates = useMemo(() => items.map((e) => e.createdAt), [items]);
  const lastWeek = items.filter((e) => (ageMs(e.createdAt, now) ?? Infinity) < 7 * DAY_MS).length;
  const toggle = (sha: string) =>
    setSelected((cur) => {
      const n = new Set(cur);
      if (n.has(sha)) n.delete(sha);
      else n.add(sha);
      return n;
    });
  const selectedItems = visible.filter((e) => selected.has(e.sha256));
  const bulkItems = selectedItems.slice(0, BULK_MAX);
  const allSelected = visible.length > 0 && visible.every((e) => selected.has(e.sha256));

  const add = useMutation({
    mutationFn: () => moderationApi.addBlocklist(normalizeSha256(sha), note.trim()),
    onSuccess: () => {
      toast.success(t('admin.v2m.bl.added'));
      setSha('');
      setHashedSha('');
      setHashing('idle');
      pickSeq.current += 1;
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
          <StatTile
            label={gt('admin.mod1.bl.tile.week')}
            value={query.isSuccess ? lastWeek : undefined}
            icon="clock"
            loading={query.isLoading}
            error={query.isError}
            caption={gt(query.hasNextPage ? 'admin.mod1.bl.tile.weekMore' : 'admin.mod1.bl.tile.weekHint')}
          />
        </div>
        {query.isSuccess && <Insight parts={[t('admin.v2m.bl.sentence')]} />}
        {query.isSuccess && items.length > 0 && (
          <QueueAgePanel
            anchor="blocklist-age"
            variant="plain"
            title={gt('admin.mod1.bl.age.title')}
            noun={gt('admin.mod1.bl.noun')}
            dates={dates}
            now={now}
            truncated={query.hasNextPage}
          />
        )}
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
              {hashing === 'tooBig' && <p className={v2.hint}>{t('admin.v2m.bl.tooBig')}</p>}
              {fileName && hashedSha !== '' && normalizeSha256(sha) === hashedSha && (
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
            <div className={q.toolbarRow} data-search-anchor="blocklist-filter">
              <FormField label={gt('admin.mod1.bl.filter')} hint={gt('admin.mod1.bl.filterHint', { n: formatNumber(items.length) })}>
                <Input value={filter} maxLength={80} dir="auto" autoComplete="off" onChange={(e) => setFilter(e.target.value)} />
              </FormField>
            </div>
            {visible.length === 0 ? (
              <EmptyState icon="shield" title={gt('admin.mod1.bl.filterEmpty')} description={gt('admin.mod1.bl.filterEmptyHint')} compact />
            ) : (
              <label className={q.selectRow}>
                <input
                  type="checkbox"
                  checked={allSelected}
                  onChange={() => setSelected(allSelected ? new Set() : new Set(visible.map((e) => e.sha256)))}
                />
                <span>{gt('admin.mod1.select.allShown', { n: formatNumber(visible.length) })}</span>
              </label>
            )}
            <ul className={styles.rowList} aria-label={t('admin.blocklist.title')}>
              {visible.map((e) => (
                <li key={e.sha256} className={`${styles.item} ${selected.has(e.sha256) ? q.rowSelected : ''}`}>
                  <div className={styles.itemHead}>
                    <label className={q.rowCheck}>
                      <input
                        type="checkbox"
                        checked={selected.has(e.sha256)}
                        onChange={() => toggle(e.sha256)}
                        aria-label={gt('admin.mod1.select.row', { name: e.sha256.slice(0, 12) })}
                      />
                    </label>
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
      <div className={q.bulkSticky} data-search-anchor="blocklist-bulk">
        <BulkBar count={selectedItems.length} onClear={() => setSelected(new Set())}>
          <Button size="sm" variant="danger" onClick={() => setBulkOpen(true)}>
            {gt('admin.mod1.bl.bulk.remove')}
          </Button>
        </BulkBar>
      </div>
      <BulkRunDialog
        open={bulkOpen}
        onClose={() => setBulkOpen(false)}
        danger
        title={gt('admin.mod1.bl.bulkTitle', { n: formatNumber(bulkItems.length) })}
        message={`${gt('admin.mod1.bl.bulkBody', { n: formatNumber(bulkItems.length) })} ${
          selectedItems.length > BULK_MAX ? gt('admin.mod1.bl.bulkCap', { max: formatNumber(BULK_MAX) }) : ''
        }`}
        confirmLabel={gt('admin.mod1.bl.bulkBtn', { n: formatNumber(bulkItems.length) })}
        items={bulkItems}
        runOne={(e) => moderationApi.removeBlocklist(e.sha256)}
        onDone={(outcome) => {
          batchToast(outcome);
          setBulkOpen(false);
          setSelected(new Set());
          void qc.invalidateQueries({ queryKey: qk.moderation.blocklist() });
        }}
      />
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
