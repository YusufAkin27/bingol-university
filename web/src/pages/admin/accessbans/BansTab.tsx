// Engeller sekmesi: GET /api/admin/access-bans (imleç sayfalı), PATCH/DELETE /{id}, GET /{id}/attempts.
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  accessBanKeys,
  BAN_KINDS,
  listAttempts,
  listBans,
  removeBan,
  updateBan,
  type AccessBan,
  type BanKind,
} from '../../../api/accessBans';
import {
  Badge,
  Button,
  ConfirmDialog,
  Drawer,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  LoadMore,
  Modal,
  SearchInput,
  Select,
  Skeleton,
  StatusPill,
  Table,
  useToast,
  type Column,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import { AddBanDialog } from './AddBanDialog';
import styles from './accessBans.module.css';
import { endOfDayIso } from './logic';

export function BansTab() {
  const i18n = useI18n();
  const { t, td, formatDateTime } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [kind, setKind] = useState<BanKind | ''>('');
  const [active, setActive] = useState<'' | 'true' | 'false'>('');
  const [q, setQ] = useState('');
  const [adding, setAdding] = useState(false);
  const [editing, setEditing] = useState<AccessBan | null>(null);
  const [removing, setRemoving] = useState<AccessBan | null>(null);
  const [viewing, setViewing] = useState<AccessBan | null>(null);

  const params = { kind, active: active === '' ? ('' as const) : active === 'true', q, size: 30 };
  const query = useInfiniteQuery({
    queryKey: accessBanKeys.list(params),
    queryFn: ({ pageParam }) => listBans({ ...params, cursor: pageParam }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
  });
  const items = query.data?.pages.flatMap((p) => p.items);

  const refresh = () => void qc.invalidateQueries({ queryKey: accessBanKeys.all });

  const toggle = useMutation({
    mutationFn: (b: AccessBan) => updateBan(b.id, { active: !b.active }),
    onSuccess: () => {
      toast.success(t('admin.ab.toast.updated'));
      refresh();
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  const remove = useMutation({
    mutationFn: (b: AccessBan) => removeBan(b.id),
    onSuccess: () => {
      toast.success(t('admin.ab.toast.removed'));
      setRemoving(null);
      refresh();
    },
    onError: (e) => {
      toast.error(adminErrorMessage(i18n, e));
      setRemoving(null);
      refresh();
    },
  });

  const expired = (b: AccessBan) => !!b.expiresAt && new Date(b.expiresAt).getTime() <= Date.now();

  const columns: Column<AccessBan>[] = [
    {
      key: 'kind',
      header: t('admin.ab.col.kind'),
      render: (b) => <Badge tone="info">{td(`admin.ab.kind.${b.kind}`, b.kind)}</Badge>,
    },
    {
      key: 'value',
      header: t('admin.ab.col.value'),
      render: (b) => (
        <span>
          <code className={`${styles.mono} ltr`} title={b.value}>
            {b.kind === 'USER' && b.label ? b.label : b.valueShort}
          </code>
          {b.kind === 'USER' && <p className={styles.muted}>#{b.userId ?? b.value}</p>}
          {!b.active && <StatusPill tone="neutral">{t('admin.ab.inactive')}</StatusPill>}
        </span>
      ),
    },
    {
      key: 'reason',
      header: t('admin.ab.col.reason'),
      render: (b) => <Badge tone="warning">{td(`admin.ab.reason.${b.reasonCode}`, b.reasonCode)}</Badge>,
    },
    { key: 'note', header: t('admin.ab.col.note'), render: (b) => <span dir="auto">{b.note || '—'}</span> },
    {
      key: 'expires',
      header: t('admin.ab.col.expires'),
      render: (b) =>
        !b.expiresAt ? (
          t('admin.ab.forever')
        ) : expired(b) ? (
          <StatusPill tone="neutral">{t('admin.ab.expired')}</StatusPill>
        ) : (
          t('admin.ab.expiresOn', { date: formatDateTime(b.expiresAt) })
        ),
    },
    {
      key: 'hits',
      header: t('admin.ab.col.hits'),
      render: (b) =>
        b.hitCount > 0 ? (
          <span>
            {i18n.formatNumber(b.hitCount)}
            {b.lastHitAt && <p className={styles.muted}>{t('admin.ab.lastHit', { date: formatDateTime(b.lastHitAt) })}</p>}
          </span>
        ) : (
          <span className={styles.muted}>{t('admin.ab.noHit')}</span>
        ),
    },
    {
      key: 'by',
      header: t('admin.ab.col.by'),
      render: (b) => (b.createdBy != null ? t('admin.ab.by', { id: b.createdBy }) : '—'),
    },
    {
      key: 'actions',
      header: t('admin.ab.col.actions'),
      render: (b) => (
        <div className={styles.actions}>
          <Button size="sm" variant="secondary" onClick={() => setViewing(b)}>
            {t('admin.ab.attempts')}
          </Button>
          <Button size="sm" variant="secondary" onClick={() => setEditing(b)}>
            {t('admin.ab.edit')}
          </Button>
          <Button size="sm" variant="secondary" loading={toggle.isPending && toggle.variables?.id === b.id} onClick={() => toggle.mutate(b)}>
            {b.active ? t('admin.ab.disable') : t('admin.ab.enable')}
          </Button>
          <Button size="sm" variant="danger" onClick={() => setRemoving(b)}>
            {t('admin.ab.remove')}
          </Button>
        </div>
      ),
    },
  ];

  const filtered = kind !== '' || active !== '' || q !== '';

  return (
    <div className={styles.stack}>
      <div className={styles.topRow}>
        <div className={styles.filters} style={{ flex: 1 }}>
          <FormField label={t('admin.ab.filter.kind')}>
            <Select value={kind} onChange={(e) => setKind(e.target.value as BanKind | '')}>
              <option value="">{t('common.all')}</option>
              {BAN_KINDS.map((k) => (
                <option key={k} value={k}>
                  {td(`admin.ab.kind.${k}`)}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.ab.filter.status')}>
            <Select value={active} onChange={(e) => setActive(e.target.value as '' | 'true' | 'false')}>
              <option value="">{t('common.all')}</option>
              <option value="true">{t('admin.ab.filter.active')}</option>
              <option value="false">{t('admin.ab.filter.inactive')}</option>
            </Select>
          </FormField>
          <div>
            <SearchInput label={t('admin.ab.filter.search')} placeholder={t('admin.ab.filter.searchPh')} onSearch={setQ} />
          </div>
        </div>
        <Button onClick={() => setAdding(true)}>{t('admin.ab.add')}</Button>
      </div>

      {query.isError ? (
        <ErrorState description={adminErrorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
      ) : query.isLoading ? (
        <Skeleton height="8rem" width="100%" />
      ) : items && items.length === 0 ? (
        <EmptyState
          icon="shield"
          title={t('admin.ab.empty.title')}
          description={filtered ? t('admin.ab.empty.filtered') : t('admin.ab.empty.hint')}
        />
      ) : (
        <>
          <Table columns={columns} rows={items} rowKey={(b) => b.id} caption={t('admin.ab.title')} />
          <LoadMore
            hasMore={!!query.hasNextPage}
            loading={query.isFetchingNextPage}
            onLoadMore={() => void query.fetchNextPage()}
          />
        </>
      )}

      {adding && <AddBanDialog open onClose={() => setAdding(false)} />}
      {editing && <EditDialog ban={editing} onClose={() => setEditing(null)} onSaved={refresh} />}
      {viewing && <AttemptsDrawer ban={viewing} onClose={() => setViewing(null)} />}
      <ConfirmDialog
        open={!!removing}
        onClose={() => setRemoving(null)}
        onConfirm={() => removing && remove.mutate(removing)}
        loading={remove.isPending}
        danger
        title={t('admin.ab.remove.title')}
        message={t('admin.ab.remove.body')}
        confirmLabel={t('admin.ab.remove')}
      />
    </div>
  );
}

function EditDialog({ ban, onClose, onSaved }: { ban: AccessBan; onClose: () => void; onSaved: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const [note, setNote] = useState(ban.note ?? '');
  const [forever, setForever] = useState(!ban.expiresAt);
  const [date, setDate] = useState(ban.expiresAt ? ban.expiresAt.slice(0, 10) : '');
  const [touched, setTouched] = useState(false);
  const expiresAt = forever ? null : endOfDayIso(date);
  const dateOk = forever || expiresAt !== null;

  const save = useMutation({
    mutationFn: () =>
      updateBan(ban.id, forever ? { note: note.trim(), noExpiry: true } : { note: note.trim(), expiresAt }),
    onSuccess: () => {
      toast.success(t('admin.ab.toast.updated'));
      onSaved();
      onClose();
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });

  return (
    <Modal
      open
      onClose={onClose}
      title={t('admin.ab.edit.title')}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button
            loading={save.isPending}
            onClick={() => {
              setTouched(true);
              if (dateOk) save.mutate();
            }}
          >
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className={styles.form}>
        <FormField label={t('admin.ab.add.note')}>
          <Input value={note} maxLength={300} dir="auto" onChange={(e) => setNote(e.target.value)} />
        </FormField>
        <FormField label={t('admin.ab.add.expiry')}>
          <Select value={forever ? 'never' : 'date'} onChange={(e) => setForever(e.target.value === 'never')}>
            <option value="never">{t('admin.ab.add.expiry.never')}</option>
            <option value="date">{t('admin.ab.add.expiry.date')}</option>
          </Select>
        </FormField>
        {!forever && (
          <FormField
            label={t('admin.ab.add.expiry.date')}
            error={touched && !dateOk ? t('admin.ab.add.expiry.err') : null}
          >
            <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          </FormField>
        )}
      </div>
    </Modal>
  );
}

function AttemptsDrawer({ ban, onClose }: { ban: AccessBan; onClose: () => void }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const q = useQuery({ queryKey: accessBanKeys.attempts(ban.id), queryFn: () => listAttempts(ban.id) });
  return (
    <Drawer open onClose={onClose} title={t('admin.ab.att.title')}>
      {q.isError ? (
        <ErrorState compact description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : q.isLoading ? (
        <Skeleton height="6rem" width="100%" />
      ) : q.data && q.data.length === 0 ? (
        <p className={styles.muted}>{t('admin.ab.att.empty')}</p>
      ) : (
        <ul className={styles.list}>
          {q.data?.map((a, i) => (
            <li key={`${a.at}-${i}`}>
              <span>{formatDateTime(a.at)}</span>
              {a.ip && <code className={`${styles.mono} ltr`}>{a.ip}</code>}
              {a.path && <code className={`${styles.mono} ltr`}>{a.path}</code>}
              {a.userId != null && <span className={styles.muted}>{t('admin.ab.att.user')} #{a.userId}</span>}
            </li>
          ))}
        </ul>
      )}
    </Drawer>
  );
}
