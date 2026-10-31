// SAYFA: Doğrulanmamış kullanıcılar (/admin/pending-users)
// API: GET /api/admin/pending-registrations (imleçli), POST .../{email}/verify | resend-code, DELETE .../{email} (api/pendingUsers.ts).
// Kayıtlar Redis'te 72 saat yaşar; "Doğrula" hesabı e-posta koduna gerek kalmadan oluşturur.
import { useInfiniteQuery, useQueryClient, type InfiniteData } from '@tanstack/react-query';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { isApiError } from '../../api/client';
import {
  cancelPending,
  listPending,
  pendingKeys,
  resendPendingCode,
  verifyPending,
  type PendingPage,
  type PendingUser,
} from '../../api/pendingUsers';
import {
  Badge,
  Button,
  Checkbox,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  Modal,
  PageHeader,
  PermissionButton,
  SearchInput,
  Table,
  useToast,
  type Column,
} from '../../components/ui';
import { ReasonField } from '../../components/admin/guard/ReasonField';
import { ADMIN_REASON_MIN, isReasonValid } from '../../components/admin/guard/match';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { exportPendingCsv } from '../../api/adminBulk';
import { PendingBulkCancel } from './bulk/BulkBars';
import { BulkCsvButton } from './bulk/BulkParts';
import styles from './pending/pending.module.css';

const PAGE_SIZE = 20;
const MAX_BULK = 50;
const RESEND_COOLDOWN_MS = 60_000;

type Cache = InfiniteData<PendingPage, string | null>;
type Dialog = null | { kind: 'verify' | 'cancel'; user: PendingUser } | { kind: 'bulk' };
interface BulkState {
  running: boolean;
  done: number;
  total: number;
  ok: number;
  failed: { email: string; message: string }[];
}

export default function PendingUsersPage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  usePageTitle(t('admin.pend.title'));
  const toast = useToast();
  const qc = useQueryClient();
  const [q, setQ] = useState('');
  const [dialog, setDialog] = useState<Dialog>(null);
  const [busy, setBusy] = useState(false);
  // W1-B (T-011): kodsuz doğrulama gerekçe ister (>= 5 karakter, X-Admin-Reason); izin users.verify (yalnız FULL).
  const [reason, setReason] = useState('');
  const reasonOk = isReasonValid(reason, ADMIN_REASON_MIN);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [cooldown, setCooldown] = useState<Record<string, number>>({});
  const [now, setNow] = useState(() => Date.now());
  const [bulk, setBulk] = useState<BulkState | null>(null);

  const list = useInfiniteQuery({
    queryKey: pendingKeys.list(q),
    queryFn: ({ pageParam }) => listPending({ q, cursor: pageParam, size: PAGE_SIZE }),
    initialPageParam: null as string | null,
    getNextPageParam: (last) => last.nextCursor,
  });

  // Sunucu `q` desteklemese de yüklü satırlar süzülür.
  const rows = useMemo(() => {
    const all = list.data?.pages.flatMap((p) => p.items) ?? [];
    const needle = q.trim().toLowerCase();
    if (!needle) return all;
    return all.filter((u) => `${u.email} ${u.displayName ?? ''}`.toLowerCase().includes(needle));
  }, [list.data, q]);

  const removeFromCache = useCallback(
    (email: string) => {
      qc.setQueriesData<Cache>({ queryKey: pendingKeys.all }, (old) =>
        old
          ? { ...old, pages: old.pages.map((p) => ({ ...p, items: p.items.filter((u) => u.email !== email) })) }
          : old,
      );
      setSelected((s) => {
        if (!s.has(email)) return s;
        const n = new Set(s);
        n.delete(email);
        return n;
      });
    },
    [qc],
  );

  // Geri sayım saati yalnızca bekleyen bir bekleme varken işler.
  const hasCooldown = Object.values(cooldown).some((until) => until > now);
  useEffect(() => {
    if (!hasCooldown) return;
    const id = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(id);
  }, [hasCooldown]);

  // Sonsuz kaydırma
  const sentinel = useRef<HTMLDivElement | null>(null);
  const { hasNextPage, isFetchingNextPage, fetchNextPage } = list;
  useEffect(() => {
    const el = sentinel.current;
    if (!el || !hasNextPage || typeof IntersectionObserver === 'undefined') return;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting) && !isFetchingNextPage) void fetchNextPage();
    });
    io.observe(el);
    return () => io.disconnect();
  }, [hasNextPage, isFetchingNextPage, fetchNextPage, rows.length]);

  function remaining(sec: number): string {
    const s = Math.max(0, sec);
    const d = Math.floor(s / 86400);
    const h = Math.floor((s % 86400) / 3600);
    const m = Math.floor((s % 3600) / 60);
    if (d > 0) return t('admin.pend.remaining.dh', { d: formatNumber(d), h: formatNumber(h) });
    if (h > 0) return t('admin.pend.remaining.hm', { h: formatNumber(h), m: formatNumber(m) });
    return t('admin.pend.remaining.m', { m: formatNumber(m) });
  }

  async function verifyOne(u: PendingUser): Promise<void> {
    await verifyPending(u.email, { reason });
    removeFromCache(u.email);
  }

  async function onVerify(u: PendingUser) {
    setBusy(true);
    try {
      await verifyOne(u);
      toast.success(t('admin.pend.verify.done', { name: u.displayName || u.email }));
      void qc.invalidateQueries({ queryKey: ['users'] });
    } catch (e) {
      if (isApiError(e) && e.code === 'EMAIL_ALREADY_REGISTERED') {
        removeFromCache(u.email);
        toast.info(t('admin.pend.verify.exists'));
      } else if (isApiError(e) && (e.code === 'PENDING_REGISTRATION_NOT_FOUND' || e.status === 404)) {
        removeFromCache(u.email);
        toast.info(t('admin.pend.gone'));
      } else {
        toast.error(errorMessage(i18n, e));
      }
    } finally {
      setBusy(false);
      setDialog(null);
    }
  }

  async function onCancel(u: PendingUser) {
    setBusy(true);
    try {
      await cancelPending(u.email);
      removeFromCache(u.email);
      toast.success(t('admin.pend.cancel.done'));
    } catch (e) {
      if (isApiError(e) && e.status === 404) {
        removeFromCache(u.email);
        toast.info(t('admin.pend.gone'));
      } else {
        toast.error(errorMessage(i18n, e));
      }
    } finally {
      setBusy(false);
      setDialog(null);
    }
  }

  async function onResend(u: PendingUser) {
    const startCooldown = () => {
      setNow(Date.now());
      setCooldown((c) => ({ ...c, [u.email]: Date.now() + RESEND_COOLDOWN_MS }));
    };
    try {
      await resendPendingCode(u.email);
      startCooldown();
      toast.success(t('admin.pend.resend.done'));
      void qc.invalidateQueries({ queryKey: pendingKeys.all });
    } catch (e) {
      if (isApiError(e) && e.status === 429) {
        startCooldown();
        toast.error(t('admin.pend.resend.cooldown'));
      } else if (isApiError(e) && e.status === 404) {
        removeFromCache(u.email);
        toast.info(t('admin.pend.gone'));
      } else {
        toast.error(errorMessage(i18n, e));
      }
    }
  }

  async function runBulk() {
    const targets = rows.filter((u) => selected.has(u.email)).slice(0, MAX_BULK);
    const state: BulkState = { running: true, done: 0, total: targets.length, ok: 0, failed: [] };
    setBulk({ ...state });
    for (const u of targets) {
      try {
        await verifyOne(u);
        state.ok += 1;
      } catch (e) {
        if (isApiError(e) && e.code === 'EMAIL_ALREADY_REGISTERED') {
          removeFromCache(u.email);
          state.failed.push({ email: u.email, message: t('admin.pend.verify.exists') });
        } else {
          state.failed.push({ email: u.email, message: errorMessage(i18n, e) });
        }
      }
      state.done += 1;
      setBulk({ ...state, failed: [...state.failed] });
    }
    state.running = false;
    setBulk({ ...state, failed: [...state.failed] });
    void qc.invalidateQueries({ queryKey: ['users'] });
  }

  function closeBulk() {
    if (bulk?.running) return;
    setBulk(null);
    setDialog(null);
  }

  function toggle(email: string, on: boolean) {
    if (on && selected.size >= MAX_BULK && !selected.has(email)) {
      toast.error(t('admin.pend.bulk.max', { n: MAX_BULK }));
      return;
    }
    setSelected((s) => {
      const n = new Set(s);
      if (on) n.add(email);
      else n.delete(email);
      return n;
    });
  }

  const allChecked = rows.length > 0 && rows.every((u) => selected.has(u.email));
  function toggleAll(on: boolean) {
    if (!on) {
      setSelected(new Set());
      return;
    }
    const n = new Set<string>();
    for (const u of rows) {
      if (n.size >= MAX_BULK) break;
      n.add(u.email);
    }
    if (rows.length > MAX_BULK) toast.info(t('admin.pend.bulk.max', { n: MAX_BULK }));
    setSelected(n);
  }

  const columns: Column<PendingUser>[] = [
    {
      key: 'select',
      header: (
        <Checkbox
          label={<span className="sr-only">{t('admin.pend.selectAll')}</span>}
          checked={allChecked}
          onChange={(e) => toggleAll(e.target.checked)}
        />
      ),
      width: '44px',
      render: (u) => (
        <Checkbox
          label={<span className="sr-only">{t('admin.pend.selectRow', { email: u.email })}</span>}
          checked={selected.has(u.email)}
          onChange={(e) => toggle(u.email, e.target.checked)}
        />
      ),
    },
    {
      key: 'email',
      header: t('admin.pend.col.email'),
      render: (u) => (
        <div className={styles.id}>
          <span className={`${styles.idMain} ltr`}>{u.email}</span>
          {!u.email.includes('@') && <Badge tone="info">{t('admin.pend.schoolNo')}</Badge>}
        </div>
      ),
    },
    {
      key: 'name',
      header: t('admin.pend.col.name'),
      render: (u) => u.displayName || <span className={styles.muted}>—</span>,
    },
    {
      key: 'dept',
      header: t('admin.pend.col.dept'),
      render: (u) =>
        u.faculty || u.department || u.grade ? (
          <div className={styles.id}>
            <span>{u.department ?? u.faculty ?? '—'}</span>
            {u.grade && <span className={styles.muted}>{t('admin.pend.grade', { n: u.grade })}</span>}
          </div>
        ) : (
          <span className={styles.muted}>—</span>
        ),
    },
    {
      key: 'remaining',
      header: t('admin.pend.col.remaining'),
      render: (u) => <span className={styles.nowrap}>{remaining(u.remainingSeconds)}</span>,
    },
    { key: 'resend', header: t('admin.pend.col.resend'), render: (u) => formatNumber(u.resendCount) },
    {
      key: 'actions',
      header: t('admin.pend.col.actions'),
      render: (u) => {
        const wait = Math.ceil(((cooldown[u.email] ?? 0) - now) / 1000);
        return (
          <div className={styles.rowActions}>
            <PermissionButton
              permission="users.verify"
              size="sm"
              onClick={() => {
                setReason('');
                setDialog({ kind: 'verify', user: u });
              }}
            >
              {t('admin.pend.verify')}
            </PermissionButton>
            <Button size="sm" variant="secondary" disabled={wait > 0} onClick={() => void onResend(u)}>
              {wait > 0 ? t('admin.pend.resend.wait', { s: formatNumber(wait) }) : t('admin.pend.resend')}
            </Button>
            <Button size="sm" variant="danger" onClick={() => setDialog({ kind: 'cancel', user: u })}>
              {t('admin.pend.cancel')}
            </Button>
          </div>
        );
      },
    },
  ];

  const dlgUser = dialog && dialog.kind !== 'bulk' ? dialog.user : null;
  const selectedCount = rows.filter((u) => selected.has(u.email)).length;

  return (
    <div>
      <PageHeader title={t('admin.pend.title')} />
      <p className={styles.intro}>{t('admin.pend.intro')}</p>

      <div className={styles.topRow}>
        <div className={styles.search}>
          <SearchInput placeholder={t('admin.pend.search')} onSearch={(v) => setQ(v.trim())} />
        </div>
        <BulkCsvButton filename="bekleyen-kayitlar.csv" fetchCsv={() => exportPendingCsv({ q })} />
        {selectedCount > 0 && (
          <div className={styles.bulk}>
            <span className={styles.muted}>{t('admin.pend.selected', { n: formatNumber(selectedCount) })}</span>
            <PermissionButton
              permission="users.verify"
              onClick={() => {
                setReason('');
                setDialog({ kind: 'bulk' });
              }}
            >
              {t('admin.pend.bulk.verify')}
            </PermissionButton>
            <PendingBulkCancel
              emails={rows.filter((u) => selected.has(u.email)).map((u) => u.email)}
              onDone={() => {
                setSelected(new Set());
                void qc.invalidateQueries({ queryKey: pendingKeys.all });
              }}
            />
          </div>
        )}
      </div>

      {list.isError && !list.data ? (
        <ErrorState description={errorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : (
        <>
          {list.data && (
            <p className={styles.meta} aria-live="polite">
              {t('admin.pend.count', { n: formatNumber(rows.length) })}
            </p>
          )}
          <Table
            caption={t('admin.pend.title')}
            columns={columns}
            rows={list.isLoading ? undefined : rows}
            rowKey={(u) => u.email}
            loading={list.isLoading}
            empty={
              <EmptyState
                icon="users"
                compact
                title={t('admin.pend.empty.title')}
                description={t('admin.pend.empty.hint')}
              />
            }
          />
          {list.isError && (
            <ErrorState
              compact
              description={errorMessage(i18n, list.error)}
              onRetry={() => void list.fetchNextPage()}
            />
          )}
          {hasNextPage && (
            <div className={styles.more} ref={sentinel}>
              <Button variant="secondary" loading={isFetchingNextPage} onClick={() => void fetchNextPage()}>
                {isFetchingNextPage ? t('admin.pend.loadingMore') : t('admin.pend.loadMore')}
              </Button>
            </div>
          )}
        </>
      )}

      <ConfirmDialog
        open={dialog?.kind === 'verify'}
        onClose={() => setDialog(null)}
        onConfirm={() => dlgUser && void onVerify(dlgUser)}
        loading={busy}
        title={t('admin.pend.verify.title')}
        message={
          <>
            <strong className="ltr">{dlgUser?.email}</strong>
            <br />
            {t('admin.pend.verify.message')}
          </>
        }
        confirmLabel={t('admin.pend.verify')}
        confirmDisabled={!reasonOk}
        initialFocus="content"
      >
        <ReasonField value={reason} onChange={setReason} minLength={ADMIN_REASON_MIN} disabled={busy} focusOnMount />
      </ConfirmDialog>
      <ConfirmDialog
        open={dialog?.kind === 'cancel'}
        onClose={() => setDialog(null)}
        onConfirm={() => dlgUser && void onCancel(dlgUser)}
        loading={busy}
        danger
        title={t('admin.pend.cancel.title')}
        message={t('admin.pend.cancel.message', { email: dlgUser?.email ?? '' })}
        confirmLabel={t('admin.pend.cancel')}
      />

      <Modal
        open={dialog?.kind === 'bulk'}
        onClose={closeBulk}
        title={t('admin.pend.bulk.title')}
        size="sm"
        footer={
          bulk && !bulk.running ? (
            <Button onClick={closeBulk}>{t('admin.pend.bulk.close')}</Button>
          ) : (
            <>
              <Button variant="secondary" disabled={!!bulk} onClick={closeBulk}>
                {t('common.cancel')}
              </Button>
              <Button loading={!!bulk?.running} disabled={!reasonOk} onClick={() => void runBulk()}>
                {t('admin.pend.bulk.verify')}
              </Button>
            </>
          )
        }
      >
        {!bulk ? (
          <>
            <p>{t('admin.pend.bulk.message', { n: formatNumber(selectedCount) })}</p>
            <ReasonField value={reason} onChange={setReason} minLength={ADMIN_REASON_MIN} focusOnMount />
          </>
        ) : (
          <div aria-live="polite">
            <p className={styles.progress}>
              {t('admin.pend.bulk.progress', { done: formatNumber(bulk.done), total: formatNumber(bulk.total) })}
            </p>
            {!bulk.running && (
              <>
                <p>
                  <strong>
                    {t('admin.pend.bulk.report', { ok: formatNumber(bulk.ok), fail: formatNumber(bulk.failed.length) })}
                  </strong>
                </p>
                {bulk.failed.length > 0 && (
                  <>
                    <p className={styles.muted}>{t('admin.pend.bulk.failedList')}</p>
                    <ul className={styles.failList}>
                      {bulk.failed.map((f) => (
                        <li key={f.email}>
                          <span className="ltr">{f.email}</span>: {f.message}
                        </li>
                      ))}
                    </ul>
                  </>
                )}
              </>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
}
