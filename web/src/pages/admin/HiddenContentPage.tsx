// SAYFA: Gizlenen içerik (/admin/moderation/hidden)  [P11]
// API: GET /api/admin/moderation/hidden (birleşik liste; tür/gizleyen/tarih süzgeci), POST .../hidden/{type}/{id}/restore {reason}
//      (api/modAdmin.ts). Geri alma yalnız geri alınabilir türlerde; ilgili ihlaller sayılmaz, sahibine bildirim gider.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { modAdminApi, qk } from '../../api';
import type { HiddenRow } from '../../api/modAdmin';
import type { ReportTargetType } from '../../api/types';
import {
  Badge,
  EmptyState,
  ErrorState,
  FormField,
  GuardedAction,
  Input,
  PageHeader,
  Pagination,
  Select,
  StatusPill,
  Table,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { adminError } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { AuthImage } from './moderation/AuthImage';
import { MOD_TARGET_TYPES, restoreAvailability } from './moderation/p11Logic';
import styles from './moderation/p11.module.css';

interface Filters {
  targetType: ReportTargetType | '';
  hiddenBy: 'AUTO' | 'ADMIN' | '';
  from: string;
  to: string;
}
const EMPTY: Filters = { targetType: '', hiddenBy: '', from: '', to: '' };

export default function HiddenContentPage() {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.p11.hidden.title'));
  const [filters, setFilters] = useState<Filters>(EMPTY);
  const [page, setPage] = useState(0);
  const set = (patch: Partial<Filters>) => {
    setFilters((f) => ({ ...f, ...patch }));
    setPage(0);
  };

  const params = { ...filters, page, size: 20 };
  const query = useQuery({
    queryKey: [...qk.moderation.all, 'hidden', params],
    queryFn: () => modAdminApi.listHidden(params),
  });
  const data = query.data;

  const columns: Column<HiddenRow>[] = [
    {
      key: 'target',
      header: t('admin.p11.hidden.col.content'),
      render: (r) => (
        <span className={styles.cellStack}>
          <Badge tone="primary">{t(`admin.reports.targetType.${r.targetType}`)}</Badge>
          <span className={`${styles.muted} ltr`}>#{r.targetId}</span>
          {!r.exists && <span className={styles.muted}>{t('admin.p11.hidden.gone')}</span>}
        </span>
      ),
    },
    {
      key: 'preview',
      header: t('admin.p11.hidden.col.preview'),
      render: (r) =>
        r.preview?.kind === 'IMAGE' ? (
          <div className={styles.preview}>
            <AuthImage url={r.preview.thumbnailUrl ?? r.preview.url} alt={t('admin.reports.preview.image')} />
          </div>
        ) : r.preview?.kind === 'TEXT' && r.preview.text ? (
          <p className={styles.previewText} dir="auto">
            {r.preview.text}
          </p>
        ) : (
          <span className={styles.muted}>{t('admin.p11.hidden.noPreview')}</span>
        ),
    },
    {
      key: 'owner',
      header: t('admin.p11.hidden.col.owner'),
      render: (r) =>
        r.ownerId ? (
          <Link to={paths.admin.user(r.ownerId)} dir="auto">
            {r.ownerName || `#${r.ownerId}`}
          </Link>
        ) : (
          '—'
        ),
    },
    {
      key: 'hiddenBy',
      header: t('admin.p11.hidden.col.by'),
      render: (r) => (
        <StatusPill tone={r.hiddenBy === 'ADMIN' ? 'danger' : 'warning'}>{t(`admin.p11.hidden.by.${r.hiddenBy}`)}</StatusPill>
      ),
    },
    { key: 'hiddenAt', header: t('admin.p11.hidden.col.date'), render: (r) => (r.hiddenAt ? formatDateTime(r.hiddenAt) : '—') },
    {
      key: 'actions',
      header: t('admin.p11.col.actions'),
      align: 'end',
      render: (r) => {
        const av = restoreAvailability(r);
        if (!av.ok) {
          return <span className={styles.why}>{av.why ? td(av.why) : ''}</span>;
        }
        return (
          <GuardedAction
            size="sm"
            variant="secondary"
            requireReason
            irreversible={false}
            title={t('admin.p11.hidden.restore.title')}
            confirmLabel={t('admin.p11.hidden.restore.button')}
            message={t('admin.p11.hidden.restore.message', { type: t(`admin.reports.targetType.${r.targetType}`), id: r.targetId })}
            consequence={t('admin.p11.hidden.restore.consequence')}
            successMessage={t('admin.p11.hidden.restore.done')}
            errorMessage={(e) => adminError(i18n, e)}
            invalidateKeys={[qk.moderation.all, qk.reports.all]}
            onConfirm={({ reason, idempotencyKey }) =>
              modAdminApi.restoreHidden(r.targetType, r.targetId, { reason, idempotencyKey })
            }
          >
            {t('admin.p11.hidden.restore.button')}
          </GuardedAction>
        );
      },
    },
  ];

  return (
    <>
      <PageHeader title={t('admin.p11.hidden.title')} description={t('admin.p11.hidden.desc')} />
      <div className={styles.filters} role="search" aria-label={t('admin.p11.filters')}>
        <FormField label={t('admin.p11.hidden.filter.type')}>
          <Select value={filters.targetType} onChange={(e) => set({ targetType: e.target.value as ReportTargetType | '' })}>
            <option value="">{t('admin.p11.filter.all')}</option>
            {MOD_TARGET_TYPES.map((x) => (
              <option key={x} value={x}>
                {t(`admin.reports.targetType.${x}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p11.hidden.filter.by')}>
          <Select value={filters.hiddenBy} onChange={(e) => set({ hiddenBy: e.target.value as Filters['hiddenBy'] })}>
            <option value="">{t('admin.p11.filter.all')}</option>
            <option value="AUTO">{t('admin.p11.hidden.by.AUTO')}</option>
            <option value="ADMIN">{t('admin.p11.hidden.by.ADMIN')}</option>
          </Select>
        </FormField>
        <FormField label={t('admin.p11.filter.from')}>
          <Input type="date" value={filters.from} max={filters.to || undefined} onChange={(e) => set({ from: e.target.value })} />
        </FormField>
        <FormField label={t('admin.p11.filter.to')}>
          <Input type="date" value={filters.to} min={filters.from || undefined} onChange={(e) => set({ to: e.target.value })} />
        </FormField>
      </div>

      {data && (
        <p className={styles.meta} aria-live="polite">
          {t('admin.p11.count', { n: formatNumber(data.total) })}
        </p>
      )}
      {query.isError ? (
        <ErrorState onRetry={() => void query.refetch()} description={adminError(i18n, query.error)} />
      ) : (
        <>
          <Table
            caption={t('admin.p11.hidden.list')}
            columns={columns}
            rows={data?.items}
            rowKey={(r) => `${r.targetType}:${r.targetId}`}
            loading={query.isLoading}
            empty={
              <EmptyState
                icon="eyeOff"
                title={t('admin.p11.hidden.empty.title')}
                description={t('admin.p11.hidden.empty.hint')}
                compact
              />
            }
          />
          {data && data.totalPages > 1 && (
            <div className={styles.pager}>
              <Pagination page={data.page} totalPages={data.totalPages} totalItems={data.total} onPageChange={setPage} />
            </div>
          )}
        </>
      )}
    </>
  );
}
