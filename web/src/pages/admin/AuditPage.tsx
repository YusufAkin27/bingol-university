// SAYFA: Denetim kaydı (/admin/audit)
// API: GET /api/admin/audit?page=&size=&adminId=&method=&q= (api/audit.ts); yönetici filtresi için GET /api/admin/users?role=ADMIN.
// Filtre durumu URL'dedir: ?adminId=&method=&q=&page=
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import { listAudit } from '../../api/audit';
import { qk } from '../../api/queryKeys';
import type { AuditParams, AuditRow } from '../../api/types';
import { listUsers } from '../../api/users';
import {
  EmptyState,
  ErrorState,
  Icon,
  PageHeader,
  Pagination,
  SearchInput,
  Select,
  StatusPill,
  Table,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import styles from './audit/audit.module.css';
import { isDenied, statusTone } from './audit/status';

const METHODS = ['POST', 'PUT', 'PATCH', 'DELETE', 'GET'] as const;
const SIZE = 20;

export default function AuditPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.audit.title'));
  const [sp, setSp] = useSearchParams();

  const f = useMemo(() => {
    const page = Number.parseInt(sp.get('page') ?? '0', 10);
    const adminId = Number.parseInt(sp.get('adminId') ?? '', 10);
    const method = sp.get('method') ?? '';
    return {
      adminId: Number.isFinite(adminId) ? adminId : undefined,
      method: (METHODS as readonly string[]).includes(method) ? method : '',
      q: sp.get('q') ?? '',
      page: Number.isFinite(page) && page > 0 ? page : 0,
    };
  }, [sp]);

  const update = (patch: Partial<typeof f>) => {
    const next = { ...f, page: 0, ...patch };
    const out = new URLSearchParams();
    if (next.adminId !== undefined) out.set('adminId', String(next.adminId));
    if (next.method) out.set('method', next.method);
    if (next.q) out.set('q', next.q);
    if (next.page > 0) out.set('page', String(next.page));
    setSp(out, { replace: !('page' in patch) });
  };

  const params: AuditParams = { page: f.page, size: SIZE };
  if (f.adminId !== undefined) params.adminId = f.adminId;
  if (f.method) params.method = f.method;
  if (f.q) params.q = f.q;

  const list = useQuery({
    queryKey: qk.audit.list(params),
    queryFn: () => listAudit(params),
    placeholderData: keepPreviousData,
  });
  const admins = useQuery({
    queryKey: qk.users.list({ role: 'ADMIN', size: 100 }),
    queryFn: () => listUsers({ role: 'ADMIN', size: 100 }),
    staleTime: 60_000,
  });

  const columns: Column<AuditRow>[] = [
    {
      key: 'at',
      header: t('admin.audit.col.time'),
      render: (r) => <span className={styles.nowrap}>{formatDateTime(r.at)}</span>,
    },
    {
      key: 'admin',
      header: t('admin.audit.col.admin'),
      render: (r) =>
        r.adminEmail ? (
          <span className="ltr">{r.adminEmail}</span>
        ) : (
          <span className={styles.muted}>{t('admin.audit.noAdmin')}</span>
        ),
    },
    {
      key: 'method',
      header: t('admin.audit.col.method'),
      render: (r) => <span className={`${styles.method} ltr`}>{r.method}</span>,
    },
    {
      key: 'path',
      header: t('admin.audit.col.path'),
      render: (r) => <span className={`${styles.path} ltr`}>{r.path}</span>,
    },
    {
      key: 'status',
      header: t('admin.audit.col.status'),
      render: (r) =>
        isDenied(r.status) ? (
          <span className={styles.denied}>
            <Icon name="shield" size={14} />
            <span className="ltr">{r.status}</span>
            <span>{t('admin.audit.denied')}</span>
          </span>
        ) : (
          <StatusPill tone={statusTone(r.status)}>
            <span className="ltr">{r.status}</span>
          </StatusPill>
        ),
    },
    {
      key: 'ip',
      header: t('admin.audit.col.ip'),
      render: (r) => <span className="ltr">{r.ip ?? '—'}</span>,
    },
  ];

  const data = list.data;
  return (
    <div>
      <PageHeader title={t('admin.audit.title')} description={t('admin.audit.desc')} />
      <div className={styles.bar} role="group" aria-label={t('admin.audit.filters.label')}>
        <div className={styles.search}>
          <SearchInput
            defaultValue={f.q}
            placeholder={t('admin.audit.filter.q')}
            onSearch={(q) => update({ q })}
          />
        </div>
        <div className={styles.select}>
          <Select
            aria-label={t('admin.audit.filter.admin')}
            value={f.adminId === undefined ? '' : String(f.adminId)}
            onChange={(e) => update({ adminId: e.target.value ? Number(e.target.value) : undefined })}
          >
            <option value="">
              {t('admin.audit.filter.admin')}: {t('common.all')}
            </option>
            {admins.data?.items.map((a) => (
              <option key={a.id} value={a.id}>
                {a.email}
              </option>
            ))}
          </Select>
        </div>
        <div className={styles.select}>
          <Select
            aria-label={t('admin.audit.filter.method')}
            value={f.method}
            onChange={(e) => update({ method: e.target.value })}
          >
            <option value="">
              {t('admin.audit.filter.method')}: {t('common.all')}
            </option>
            {METHODS.map((m) => (
              <option key={m} value={m}>
                {m}
              </option>
            ))}
          </Select>
        </div>
      </div>

      {list.isError && !data ? (
        <ErrorState description={errorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : (
        <div className={styles.card}>
          <Table
            caption={t('admin.audit.title')}
            columns={columns}
            rows={data?.items}
            rowKey={(r) => r.id}
            loading={list.isLoading}
            empty={
              <EmptyState
                icon="list"
                compact
                title={t('admin.audit.empty.title')}
                description={t('admin.audit.empty.hint')}
              />
            }
          />
          {data && data.totalPages > 1 && (
            <div className={styles.pager}>
              <Pagination
                page={data.page}
                totalPages={data.totalPages}
                totalItems={data.totalItems}
                onPageChange={(page) => update({ page })}
              />
            </div>
          )}
          {data && data.totalPages <= 1 && (
            <div className={styles.pager}>
              <span className={styles.muted}>{formatNumber(data.totalItems)}</span>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
