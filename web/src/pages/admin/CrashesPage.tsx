// SAYFA: Çökme raporları (/admin/crashes)  [CR1]
// API: GET /api/admin/crashes (+ /summary, /{id}), PATCH .../{id}/status, DELETE .../{id}  (api/crashes.ts)
// Raporlar ANONİMDİR (kullanıcı kimliği/e-posta yok; yığın izi sunucuda maskeli). Durum değişikliği ve silme sebep ister.
// Okuma: system.read; yazma: system.write. Aynı hata, çözüldükten sonra yeni sürümde tekrar ederse sunucu grubu yeniden açar.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import {
  CRASH_PLATFORMS,
  CRASH_STATUSES,
  crashKeys,
  deleteCrash,
  getCrash,
  getCrashSummary,
  listCrashes,
  setCrashStatus,
  type CrashFilters,
  type CrashGroup,
  type CrashPlatform,
  type CrashStatus,
} from '../../api/crashes';
import {
  Badge,
  Button,
  Drawer,
  EmptyState,
  ErrorState,
  FormField,
  GuardedAction,
  Input,
  PageHeader,
  Pagination,
  SearchInput,
  Select,
  StatusPill,
  Table,
  type Column,
  type Tone,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { adminError } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import styles from './crashes/crashes.module.css';

const ERR_SCOPES = ['admin.cr1.err', 'admin.err'];
const WRITE_PERM = 'system.write';
const VISIBLE_VERSIONS = 3;

interface Filters {
  status: CrashStatus | '';
  platform: CrashPlatform | '';
  version: string;
  q: string;
  sort: NonNullable<CrashFilters['sort']>;
}
const EMPTY: Filters = { status: '', platform: '', version: '', q: '', sort: 'lastSeen' };

export function statusTone(s: CrashStatus): Tone {
  return s === 'NEW' ? 'danger' : s === 'ACK' ? 'warning' : 'success';
}

export default function CrashesPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.cr1.title'));
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(0);
  const [openId, setOpenId] = useState<number | null>(null);
  const set = (patch: Partial<Filters>) => {
    setFilters((f) => ({ ...f, ...patch }));
    setPage(0);
  };

  const params: CrashFilters = { ...filters, page, size: 20 };
  const query = useQuery({ queryKey: [...crashKeys.list, params], queryFn: () => listCrashes(params) });
  const summary = useQuery({ queryKey: crashKeys.summary, queryFn: getCrashSummary });
  const data = query.data;

  const columns: Column<CrashGroup>[] = [
    {
      key: 'error',
      header: t('admin.cr1.col.error'),
      render: (r) => (
        <span className={styles.cellStack}>
          <span className={`${styles.errType} ltr`}>{r.errorType}</span>
          {r.topFrame && <span className={`${styles.muted} ltr`}>{r.topFrame}</span>}
          {r.reopenCount > 0 && <Badge tone="warning">{t('admin.cr1.reopened', { n: r.reopenCount })}</Badge>}
        </span>
      ),
    },
    {
      key: 'status',
      header: t('admin.cr1.col.status'),
      render: (r) => <StatusPill tone={statusTone(r.status)}>{t(`admin.cr1.status.${r.status}`)}</StatusPill>,
    },
    { key: 'count', header: t('admin.cr1.col.count'), align: 'end', render: (r) => formatNumber(r.eventCount) },
    {
      key: 'versions',
      header: t('admin.cr1.col.versions'),
      render: (r) => <VersionChips group={r} />,
    },
    {
      key: 'seen',
      header: t('admin.cr1.col.seen'),
      render: (r) => (
        <span className={styles.cellStack}>
          <span>{t('admin.cr1.last', { at: formatDateTime(r.lastSeenAt) })}</span>
          <span className={styles.muted}>{t('admin.cr1.first', { at: formatDateTime(r.firstSeenAt) })}</span>
        </span>
      ),
    },
    {
      key: 'actions',
      header: t('admin.cr1.col.actions'),
      align: 'end',
      render: (r) => (
        <Button size="sm" variant="secondary" onClick={() => setOpenId(r.id)}>
          {t('admin.cr1.open')}
          <span className="sr-only"> #{r.id}</span>
        </Button>
      ),
    },
  ];

  const s = summary.data;
  return (
    <>
      <PageHeader title={t('admin.cr1.title')} description={t('admin.cr1.desc')} />

      {s && (
        <div className={styles.summary} data-testid="crash-summary">
          <Stat label={t('admin.cr1.summary.new')} value={formatNumber(s.newGroups)} />
          <Stat label={t('admin.cr1.summary.ack')} value={formatNumber(s.ackGroups)} />
          <Stat label={t('admin.cr1.summary.resolved')} value={formatNumber(s.resolvedGroups)} />
          <Stat label={t('admin.cr1.summary.reopened')} value={formatNumber(s.reopened)} />
          <Stat label={t('admin.cr1.summary.events24h')} value={formatNumber(s.events24h)} />
        </div>
      )}

      <div className={styles.filters} role="search" aria-label={t('admin.cr1.filters')}>
        <div>
          <SearchInput
            label={t('admin.cr1.filter.q')}
            placeholder={t('admin.cr1.filter.qPlaceholder')}
            onSearch={(q) => set({ q })}
          />
        </div>
        <FormField label={t('admin.cr1.filter.status')}>
          <Select value={filters.status} onChange={(e) => set({ status: e.target.value as CrashStatus | '' })}>
            <option value="">{t('admin.cr1.filter.all')}</option>
            {CRASH_STATUSES.map((x) => (
              <option key={x} value={x}>
                {t(`admin.cr1.status.${x}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.cr1.filter.platform')}>
          <Select value={filters.platform} onChange={(e) => set({ platform: e.target.value as CrashPlatform | '' })}>
            <option value="">{t('admin.cr1.filter.all')}</option>
            {CRASH_PLATFORMS.map((x) => (
              <option key={x} value={x}>
                {t(`admin.cr1.platform.${x}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.cr1.filter.version')}>
          <Input
            value={filters.version}
            placeholder={t('admin.cr1.filter.versionPlaceholder')}
            onChange={(e) => set({ version: e.target.value })}
          />
        </FormField>
        <FormField label={t('admin.cr1.filter.sort')}>
          <Select value={filters.sort} onChange={(e) => set({ sort: e.target.value as Filters['sort'] })}>
            {(['lastSeen', 'firstSeen', 'count'] as const).map((x) => (
              <option key={x} value={x}>
                {t(`admin.cr1.sort.${x}`)}
              </option>
            ))}
          </Select>
        </FormField>
      </div>

      {data && (
        <p className={styles.meta} aria-live="polite">
          {t('admin.cr1.count', { n: formatNumber(data.totalItems) })}
        </p>
      )}
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={adminError(i18n, query.error, ...ERR_SCOPES)} />
      ) : (
        <>
          <Table
            caption={t('admin.cr1.list')}
            columns={columns}
            rows={data?.items}
            rowKey={(r) => r.id}
            loading={query.isLoading}
            empty={<EmptyState icon="alert" title={t('admin.cr1.empty.title')} description={t('admin.cr1.empty.hint')} compact />}
          />
          {data && data.totalPages > 1 && (
            <div className={styles.pager}>
              <Pagination page={data.page} totalPages={data.totalPages} totalItems={data.totalItems} onPageChange={setPage} />
            </div>
          )}
        </>
      )}

      {openId !== null && <CrashDrawer id={openId} onClose={() => setOpenId(null)} />}
    </>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.stat}>
      <span className={styles.statValue}>{value}</span>
      <span className={styles.statLabel}>{label}</span>
    </div>
  );
}

function VersionChips({ group }: { group: CrashGroup }) {
  const { t, formatNumber } = useI18n();
  const shown = group.versions.slice(0, VISIBLE_VERSIONS);
  const more = group.versions.length - shown.length;
  return (
    <span className={styles.chips}>
      {shown.map((v) => (
        <Badge key={`${v.version}-${v.platform}`}>
          <span className="ltr">
            {v.version} · {v.platform === 'ANDROID' ? 'A' : v.platform === 'IOS' ? 'i' : '?'} · {formatNumber(v.count)}
          </span>
        </Badge>
      ))}
      {more > 0 && <span className={styles.muted}>{t('admin.cr1.moreVersions', { n: more })}</span>}
    </span>
  );
}

function CrashDrawer({ id, onClose }: { id: number; onClose: () => void }) {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  const [fixedIn, setFixedIn] = useState('');
  const query = useQuery({ queryKey: crashKeys.detail(id), queryFn: () => getCrash(id), staleTime: 0 });
  const d = query.data;
  const g = d?.group;
  const keys = [crashKeys.all];

  const statusAction = (
    to: CrashStatus,
    kind: 'ack' | 'resolve' | 'reopen',
    opts: { danger?: boolean } = {},
  ) => (
    <GuardedAction
      key={kind}
      permission={WRITE_PERM}
      variant={kind === 'resolve' ? 'primary' : 'secondary'}
      danger={opts.danger}
      requireReason
      reasonMinLength={5}
      irreversible={false}
      title={t(`admin.cr1.act.${kind}.title`)}
      confirmLabel={t(`admin.cr1.act.${kind}.button`)}
      message={t(`admin.cr1.act.${kind}.message`)}
      consequence={t(`admin.cr1.act.${kind}.consequence`)}
      successMessage={t(`admin.cr1.act.${kind}.done`)}
      errorMessage={(e) => adminError(i18n, e, ...ERR_SCOPES)}
      invalidateKeys={keys}
      onConfirm={({ reason, idempotencyKey }) =>
        setCrashStatus(id, to, { reason, idempotencyKey, fixedInVersion: to === 'RESOLVED' ? fixedIn : undefined })
      }
    >
      {t(`admin.cr1.act.${kind}.button`)}
    </GuardedAction>
  );

  return (
    <Drawer open onClose={onClose} title={t('admin.cr1.detail.title', { id })} size="lg">
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={adminError(i18n, query.error, ...ERR_SCOPES)} />
      ) : !g || !d ? (
        <p className={styles.muted} role="status">
          {t('admin.cr1.loading')}
        </p>
      ) : (
        <>
          <p className={styles.callout} role="note">
            {t('admin.cr1.detail.anon')}
          </p>
          {g.reopenCount > 0 && g.status === 'NEW' && (
            <p className={`${styles.callout} ${styles.calloutWarn}`} role="note">
              {t('admin.cr1.detail.reopenNote')}
            </p>
          )}
          <dl className={styles.facts}>
            <dt>{t('admin.cr1.col.status')}</dt>
            <dd>
              <StatusPill tone={statusTone(g.status)}>{t(`admin.cr1.status.${g.status}`)}</StatusPill>
            </dd>
            <dt>{t('admin.cr1.detail.type')}</dt>
            <dd className="ltr">{g.errorType}</dd>
            {g.topFrame && (
              <>
                <dt>{t('admin.cr1.detail.topFrame')}</dt>
                <dd className="ltr">{g.topFrame}</dd>
              </>
            )}
            {g.message && (
              <>
                <dt>{t('admin.cr1.detail.message')}</dt>
                <dd>{g.message}</dd>
              </>
            )}
            <dt>{t('admin.cr1.detail.total')}</dt>
            <dd>{formatNumber(g.eventCount)}</dd>
            <dt>{t('admin.cr1.detail.firstSeen')}</dt>
            <dd>{formatDateTime(g.firstSeenAt)}</dd>
            <dt>{t('admin.cr1.detail.lastSeen')}</dt>
            <dd>{formatDateTime(g.lastSeenAt)}</dd>
            {g.reopenCount > 0 && (
              <>
                <dt>{t('admin.cr1.detail.reopenCount')}</dt>
                <dd>{g.reopenCount}</dd>
              </>
            )}
            {g.statusAt && (
              <>
                <dt>{t('admin.cr1.detail.statusBy')}</dt>
                <dd>
                  {g.statusBy ?? '—'} · {formatDateTime(g.statusAt)}
                </dd>
              </>
            )}
            {g.statusReason && (
              <>
                <dt>{t('admin.cr1.detail.statusReason')}</dt>
                <dd>{g.statusReason}</dd>
              </>
            )}
            {g.fixedInVersion && (
              <>
                <dt>{t('admin.cr1.detail.fixedIn')}</dt>
                <dd className="ltr">{g.fixedInVersion}</dd>
              </>
            )}
          </dl>

          <h3>{t('admin.cr1.detail.versions')}</h3>
          <table className={styles.versionTable}>
            <caption className="sr-only">{t('admin.cr1.detail.versions')}</caption>
            <thead>
              <tr>
                <th scope="col">{t('admin.cr1.filter.version')}</th>
                <th scope="col">{t('admin.cr1.filter.platform')}</th>
                <th scope="col">{t('admin.cr1.col.count')}</th>
              </tr>
            </thead>
            <tbody>
              {g.versions.map((v) => (
                <tr key={`${v.version}-${v.platform}`}>
                  <td className="ltr">{v.version}</td>
                  <td>{td(`admin.cr1.platform.${v.platform}`, v.platform)}</td>
                  <td>{formatNumber(v.count)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className={styles.muted}>{t('admin.cr1.detail.versionsNote')}</p>

          <h3>{t('admin.cr1.detail.events')}</h3>
          <p className={styles.muted}>{t('admin.cr1.detail.eventsNote')}</p>
          {d.events.length === 0 ? (
            <p className={styles.muted}>{t('admin.cr1.detail.noEvents')}</p>
          ) : (
            d.events.slice(0, 10).map((e, i) => (
              <details key={e.id} className={styles.event} open={i === 0}>
                <summary>
                  <span>{formatDateTime(e.occurredAt)}</span>
                  <Badge>
                    <span className="ltr">{e.appVersion}</span>
                  </Badge>
                  <span>{t('admin.cr1.event.device', { platform: e.platform, os: e.osVersion ?? '' })}</span>
                  {e.deviceModel && <span className="ltr">{e.deviceModel}</span>}
                  {e.screen && <span className="ltr">{t('admin.cr1.event.screen', { screen: e.screen })}</span>}
                  {e.fatal && <Badge tone="danger">{t('admin.cr1.event.fatal')}</Badge>}
                </summary>
                <pre className={styles.stack} aria-label={t('admin.cr1.event.stack')}>
                  {e.stack}
                </pre>
              </details>
            ))
          )}

          <div className={styles.dangerZone}>
            {g.status === 'RESOLVED' ? null : (
              <FormField label={t('admin.cr1.act.fixedIn')} hint={t('admin.cr1.act.fixedInHint')}>
                <Input value={fixedIn} onChange={(e) => setFixedIn(e.target.value)} placeholder="1.2.0" />
              </FormField>
            )}
            <div className={styles.actionsRow}>
              {g.status === 'NEW' && statusAction('ACK', 'ack')}
              {g.status !== 'RESOLVED' && statusAction('RESOLVED', 'resolve')}
              {g.status === 'RESOLVED' && statusAction('NEW', 'reopen')}
              <GuardedAction
                permission={WRITE_PERM}
                variant="danger"
                danger
                requireReason
                reasonMinLength={5}
                irreversible
                title={t('admin.cr1.act.delete.title')}
                confirmLabel={t('admin.cr1.act.delete.button')}
                message={t('admin.cr1.act.delete.message')}
                consequence={t('admin.cr1.act.delete.consequence')}
                successMessage={t('admin.cr1.act.delete.done')}
                errorMessage={(e) => adminError(i18n, e, ...ERR_SCOPES)}
                invalidateKeys={keys}
                onConfirm={({ reason, idempotencyKey }) => deleteCrash(id, { reason, idempotencyKey })}
                onSuccess={onClose}
              >
                {t('admin.cr1.act.delete.button')}
              </GuardedAction>
            </div>
          </div>
        </>
      )}
    </Drawer>
  );
}
