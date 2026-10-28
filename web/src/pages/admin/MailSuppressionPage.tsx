// SAYFA: Mail bastırma listesi (/admin/mail/suppressions)  [P13]
// API: GET/POST /api/admin/mail/suppressions, GET/DELETE .../{id}, GET .../export.csv (api/adminMailOps.ts).
// Liste her zaman MASKELİ; tam adres yalnız ayrıntıda ve yalnız bir kullanıcı hesabı eşleşiyorsa görünür.
// Kullanıcının kendi çıkışı (UNSUBSCRIBED/COMPLAINT) kaldırılırken: sebep >= 20 + e-postayı yazarak onay + onay başlığı.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import {
  addSuppression,
  exportSuppressionsCsv,
  getSuppression,
  listSuppressions,
  mailOpsKeys,
  removeSuppression,
  SUPPRESSION_REASONS,
  type MailCategory,
  type SuppressionFilters,
  type SuppressionReason,
  type SuppressionRow,
} from '../../api/adminMailOps';
import {
  Badge,
  Button,
  Drawer,
  EmptyState,
  ErrorState,
  FormField,
  GuardedAction,
  Icon,
  Input,
  Modal,
  PageHeader,
  Pagination,
  SearchInput,
  Select,
  StatusPill,
  Table,
  Textarea,
  useGuardedMutation,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { adminError } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { CsvButton } from './moderation/CsvButton';
import { isSuppressionFormValid, reasonTone, removalPolicy } from './mail/mailOpsLogic';
import styles from './mail/mailops.module.css';

const ERR_SCOPES = ['admin.p13.err', 'admin.err'];

interface Filters {
  reason: SuppressionReason | '';
  category: MailCategory | '';
  q: string;
  from: string;
  to: string;
}
const EMPTY: Filters = { reason: '', category: '', q: '', from: '', to: '' };

export default function MailSuppressionPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.p13.supp.title'));
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(0);
  const [openId, setOpenId] = useState<number | null>(null);
  const [adding, setAdding] = useState(false);
  const set = (patch: Partial<Filters>) => {
    setFilters((f) => ({ ...f, ...patch }));
    setPage(0);
  };

  const params: SuppressionFilters = { ...filters, page, size: 20 };
  const query = useQuery({
    queryKey: [...mailOpsKeys.suppressions, 'list', params],
    queryFn: () => listSuppressions(params),
  });
  const data = query.data;

  const columns: Column<SuppressionRow>[] = [
    {
      key: 'address',
      header: t('admin.p13.supp.col.address'),
      render: (r) =>
        r.emailMasked ? (
          <span className="ltr">{r.emailMasked}</span>
        ) : (
          <span className={styles.muted}>{t('admin.p13.supp.noAddress', { hash: r.hashPrefix })}</span>
        ),
    },
    {
      key: 'reason',
      header: t('admin.p13.supp.col.reason'),
      render: (r) => (
        <span className={styles.cellStack}>
          <StatusPill tone={reasonTone(r.reason)}>{t(`admin.p13.supp.reason.${r.reason}`)}</StatusPill>
          {r.userOptOut && <span className={styles.muted}>{t('admin.p13.supp.optOut')}</span>}
        </span>
      ),
    },
    { key: 'category', header: t('admin.p13.supp.col.category'), render: (r) => <Badge>{t(`admin.p13.category.${r.category}`)}</Badge> },
    {
      key: 'note',
      header: t('admin.p13.supp.col.note'),
      render: (r) => (r.note ? <span dir="auto">{r.note}</span> : <span className={styles.muted}>—</span>),
    },
    { key: 'createdAt', header: t('admin.p13.supp.col.date'), render: (r) => formatDateTime(r.createdAt) },
    {
      key: 'actions',
      header: t('admin.p13.col.actions'),
      align: 'end',
      render: (r) => (
        <Button size="sm" variant="secondary" onClick={() => setOpenId(r.id)}>
          {t('admin.p13.supp.detail.open')}
          <span className="sr-only"> #{r.id}</span>
        </Button>
      ),
    },
  ];

  return (
    <>
      <PageHeader
        title={t('admin.p13.supp.title')}
        description={t('admin.p13.supp.desc')}
        actions={
          <>
            <CsvButton fetcher={() => exportSuppressionsCsv(filters)} filename="mail-bastirma.csv" />
            <Button leftIcon={<Icon name="plus" size={16} />} onClick={() => setAdding(true)}>
              {t('admin.p13.supp.add')}
            </Button>
          </>
        }
      />
      <div className={styles.filters} role="search" aria-label={t('admin.p13.filters')}>
        <div className={styles.searchField}>
          <SearchInput label={t('admin.p13.filter.q')} placeholder={t('admin.p13.supp.filter.qPlaceholder')} onSearch={(q) => set({ q })} />
          <span className={styles.muted}>{t('admin.p13.supp.filter.qHint')}</span>
        </div>
        <FormField label={t('admin.p13.filter.reason')}>
          <Select value={filters.reason} onChange={(e) => set({ reason: e.target.value as SuppressionReason | '' })}>
            <option value="">{t('admin.p13.filter.all')}</option>
            {SUPPRESSION_REASONS.map((x) => (
              <option key={x} value={x}>
                {t(`admin.p13.supp.reason.${x}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p13.filter.category')}>
          <Select value={filters.category} onChange={(e) => set({ category: e.target.value as MailCategory | '' })}>
            <option value="">{t('admin.p13.filter.all')}</option>
            <option value="ANNOUNCEMENT">{t('admin.p13.category.ANNOUNCEMENT')}</option>
            <option value="TRANSACTIONAL">{t('admin.p13.category.TRANSACTIONAL')}</option>
          </Select>
        </FormField>
        <FormField label={t('admin.p13.filter.from')}>
          <Input type="date" value={filters.from} max={filters.to || undefined} onChange={(e) => set({ from: e.target.value })} />
        </FormField>
        <FormField label={t('admin.p13.filter.to')}>
          <Input type="date" value={filters.to} min={filters.from || undefined} onChange={(e) => set({ to: e.target.value })} />
        </FormField>
      </div>

      {data && (
        <p className={styles.meta} aria-live="polite">
          {t('admin.p13.count', { n: formatNumber(data.total) })}
        </p>
      )}
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={adminError(i18n, query.error, ...ERR_SCOPES)} />
      ) : (
        <>
          <Table
            caption={t('admin.p13.supp.list')}
            columns={columns}
            rows={data?.items}
            rowKey={(r) => r.id}
            loading={query.isLoading}
            empty={<EmptyState icon="mail" title={t('admin.p13.supp.empty.title')} description={t('admin.p13.supp.empty.hint')} compact />}
          />
          {data && data.totalPages > 1 && (
            <div className={styles.pager}>
              <Pagination page={data.page} totalPages={data.totalPages} totalItems={data.total} onPageChange={setPage} />
            </div>
          )}
        </>
      )}

      {openId !== null && <SuppressionDrawer id={openId} onClose={() => setOpenId(null)} />}
      {adding && <AddSuppressionModal onClose={() => setAdding(false)} />}
    </>
  );
}

function SuppressionDrawer({ id, onClose }: { id: number; onClose: () => void }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const query = useQuery({
    queryKey: [...mailOpsKeys.suppressions, 'detail', id],
    queryFn: () => getSuppression(id),
    staleTime: 0,
    gcTime: 0,
  });
  const d = query.data;
  const policy = d ? removalPolicy(d) : null;
  const warnKey = d?.reason === 'COMPLAINT' ? 'COMPLAINT' : 'UNSUBSCRIBED';

  return (
    <Drawer open onClose={onClose} title={t('admin.p13.supp.detail.title', { id })} size="md">
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={adminError(i18n, query.error, ...ERR_SCOPES)} />
      ) : !d || !policy ? (
        <p className={styles.muted} role="status">
          {t('admin.p13.loading')}
        </p>
      ) : (
        <>
          {d.userOptOut && (
            <p className={`${styles.callout} ${d.reason === 'COMPLAINT' ? styles.calloutDanger : styles.calloutWarn}`} role="note">
              <strong>{t(`admin.p13.supp.warn.${warnKey}.title`)}</strong> {t(`admin.p13.supp.warn.${warnKey}.body`)}
            </p>
          )}
          <dl className={styles.facts}>
            <dt>{t('admin.p13.supp.col.address')}</dt>
            <dd className="ltr">
              {d.fullEmail ?? d.emailMasked ?? t('admin.p13.supp.noAddress', { hash: d.hashPrefix })}
            </dd>
            {!d.fullEmailResolved && (
              <>
                <dt />
                <dd className={styles.muted}>{t('admin.p13.supp.notResolved')}</dd>
              </>
            )}
            {d.userId && (
              <>
                <dt>{t('admin.p13.supp.detail.user')}</dt>
                <dd>
                  <Link to={paths.admin.user(d.userId)}>#{d.userId}</Link>
                </dd>
              </>
            )}
            <dt>{t('admin.p13.supp.col.reason')}</dt>
            <dd>
              <StatusPill tone={reasonTone(d.reason)}>{t(`admin.p13.supp.reason.${d.reason}`)}</StatusPill>
            </dd>
            <dt>{t('admin.p13.supp.col.category')}</dt>
            <dd>{t(`admin.p13.category.${d.category}`)}</dd>
            <dt>{t('admin.p13.supp.col.note')}</dt>
            <dd dir="auto">{d.note ?? '—'}</dd>
            <dt>{t('admin.p13.supp.col.date')}</dt>
            <dd>{formatDateTime(d.createdAt)}</dd>
            {d.createdBy && (
              <>
                <dt>{t('admin.p13.supp.detail.by')}</dt>
                <dd>#{d.createdBy}</dd>
              </>
            )}
          </dl>
          <div className={styles.dangerZone}>
            <p className={styles.muted}>{t('admin.p13.supp.remove.hint', { n: policy.minReason })}</p>
            <GuardedAction
              danger
              irreversible
              requireReason
              reasonMinLength={policy.minReason}
              typeToConfirm={policy.typeTarget ?? undefined}
              title={t('admin.p13.supp.remove.title')}
              confirmLabel={t('admin.p13.supp.remove.button')}
              message={t(policy.strong ? 'admin.p13.supp.remove.messageStrong' : 'admin.p13.supp.remove.message')}
              consequence={t('admin.p13.supp.remove.consequence')}
              successMessage={t('admin.p13.supp.remove.done')}
              errorMessage={(e) => adminError(i18n, e, ...ERR_SCOPES)}
              invalidateKeys={[mailOpsKeys.suppressions]}
              onSuccess={onClose}
              onConfirm={({ reason, idempotencyKey }) =>
                removeSuppression(d.id, { reason, idempotencyKey, confirm: policy.strong })
              }
            >
              {t('admin.p13.supp.remove.button')}
            </GuardedAction>
          </div>
        </>
      )}
    </Drawer>
  );
}

function AddSuppressionModal({ onClose }: { onClose: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [email, setEmail] = useState('');
  const [note, setNote] = useState('');
  const valid = isSuppressionFormValid(email, note);
  const add = useGuardedMutation({
    mutationFn: (v: { email: string; note: string }, ctx) => addSuppression(v, { idempotencyKey: ctx.idempotencyKey }),
    successMessage: t('admin.p13.supp.add.done'),
    errorMessage: (e) => adminError(i18n, e, ...ERR_SCOPES),
    invalidateKeys: [mailOpsKeys.suppressions],
  });

  async function submit() {
    if (!valid || add.isPending) return;
    const res = await add.run({ email, note });
    if (res.ok) onClose();
  }

  return (
    <Modal
      open
      onClose={() => !add.isPending && onClose()}
      title={t('admin.p13.supp.add.title')}
      footer={
        <>
          <Button variant="ghost" onClick={onClose} disabled={add.isPending}>
            {t('common.cancel')}
          </Button>
          <Button onClick={() => void submit()} disabled={!valid} loading={add.isPending}>
            {t('admin.p13.supp.add.submit')}
          </Button>
        </>
      }
    >
      <form
        className={styles.form}
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        <p className={`${styles.callout} ${styles.calloutWarn}`} role="note">
          {t('admin.p13.supp.add.consequence')}
        </p>
        <FormField label={t('admin.p13.supp.add.email')} hint={t('admin.p13.supp.add.emailHint')} required>
          <Input type="email" dir="ltr" autoComplete="off" value={email} maxLength={254} onChange={(e) => setEmail(e.target.value)} />
        </FormField>
        <FormField label={t('admin.p13.supp.add.note')} hint={t('admin.p13.supp.add.noteHint')} required>
          <Textarea rows={3} value={note} maxLength={300} onChange={(e) => setNote(e.target.value)} />
        </FormField>
      </form>
    </Modal>
  );
}
