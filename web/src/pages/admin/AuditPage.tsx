// SAYFA: Denetim kaydı (/admin/audit) — v2 (W-P02)
// API: GET /api/admin/audit?page=&size=&adminId=&method=&status=&q=&from=&to=&targetType=&targetId= (api/audit.ts),
//      GET /api/admin/audit/export.csv (aynı süzgeçler; en çok 50.000 satır; isteğin kendisi denetlenir),
//      yönetici süzgeci için GET /api/admin/users?role=ADMIN.
// Süzgeç durumu URL'dedir (paylaşılabilir): ?adminId=&method=&status=&q=&from=&to=&targetType=&targetId=&page=
// Satıra tıklayınca ayrıntı çekmecesi açılır; hedef sütunu ilgili yönetim sayfasına bağlanır.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useMemo, useRef, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { exportAuditCsv, listAudit, type AuditRowV2 } from '../../api/audit';
import {
  Badge,
  Button,
  ConfirmDialog,
  CopyButton,
  EmptyState,
  ErrorState,
  Icon,
  PageHeader,
  Pagination,
  StatusPill,
  Table,
  useGuardedMutation,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { AuditDrawer } from './audit/AuditDrawer';
import { AuditFilterBar } from './audit/AuditFilterBar';
import {
  AUDIT_CSV_MAX_ROWS,
  AUDIT_PAGE_SIZE,
  EMPTY_AUDIT_FILTERS,
  clip,
  describeAction,
  filtersFromParams,
  filtersToParams,
  filtersToQuery,
  targetHref,
  type AuditFilters,
} from './audit/auditLogic';
import styles from './audit/audit.module.css';
import { isDenied, statusTone } from './audit/status';
import { downloadBlob } from './users/filters';

export default function AuditPage() {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.audit.title'));
  const [sp, setSp] = useSearchParams();
  const f = useMemo(() => filtersFromParams(sp), [sp]);
  const [resetKey, setResetKey] = useState(0);
  const [openRow, setOpenRow] = useState<AuditRowV2 | null>(null);
  const [csvOpen, setCsvOpen] = useState(false);

  // Aynı anda biten iki gecikmeli alan (metin + hedef kimliği) birbirini ezmesin: en güncel süzgeç ref'te tutulur.
  const latest = useRef(f);
  latest.current = f;
  const update = (patch: Partial<AuditFilters>) => {
    const next = { ...latest.current, page: 0, ...patch };
    latest.current = next;
    setSp(filtersToParams(next), { replace: !('page' in patch) });
  };

  const query = { page: f.page, size: AUDIT_PAGE_SIZE, ...filtersToQuery(f) };
  const list = useQuery({
    queryKey: ['audit', 'list', query],
    queryFn: () => listAudit(query),
    placeholderData: keepPreviousData,
  });

  const csv = useGuardedMutation<Blob>({
    mutationFn: () => exportAuditCsv(filtersToQuery(f)),
    successMessage: t('admin.wp02.audit.exportDone'),
    errorMessage: (e) => t('admin.wp02.audit.exportFail', { reason: errorMessage(i18n, e) }),
  });
  const runCsv = async () => {
    const res = await csv.run();
    if (res.ok) {
      downloadBlob(res.data, `denetim-kaydi-${new Date().toISOString().slice(0, 10)}.csv`);
      setCsvOpen(false);
    }
  };

  const columns: Column<AuditRowV2>[] = [
    {
      key: 'at',
      header: t('admin.audit.col.time'),
      render: (r) => <span className={styles.nowrap}>{formatDateTime(r.at)}</span>,
    },
    {
      key: 'admin',
      header: t('admin.audit.col.admin'),
      render: (r) =>
        r.adminId === null && r.adminEmail === 'basic-admin' ? (
          <span title={t('admin.wp02.audit.basicAdmin')}>
            <Badge tone="warning">basic-admin</Badge>
          </span>
        ) : r.adminEmail ? (
          <span className="ltr">{r.adminEmail}</span>
        ) : (
          <span className={styles.muted}>{t('admin.audit.noAdmin')}</span>
        ),
    },
    {
      key: 'action',
      header: t('admin.wp02.audit.col.action'),
      render: (r) => {
        const a = describeAction(td, r.method, r.path);
        return (
          <span className={styles.action}>
            <span className={styles.actionLabel}>{a.label}</span>
            <span className={styles.actionRaw}>
              <span className={`${styles.method} ltr`}>{r.method}</span> <span className="ltr">{r.path}</span>
            </span>
          </span>
        );
      },
    },
    {
      key: 'target',
      header: t('admin.wp02.audit.col.target'),
      render: (r) => {
        if (!r.targetType) return <span className={styles.muted}>{t('admin.wp02.audit.noTarget')}</span>;
        const href = targetHref(r.targetType, r.targetId);
        const label = (
          <>
            {r.targetType}
            {r.targetId ? <span className="ltr"> #{r.targetId}</span> : null}
          </>
        );
        return href ? (
          // Satır tıklamasını (ayrıntı çekmecesi) tetiklemesin
          <Link to={href} onClick={(e) => e.stopPropagation()} className={styles.targetLink}>
            {label}
          </Link>
        ) : (
          <span>{label}</span>
        );
      },
    },
    {
      key: 'reason',
      header: t('admin.wp02.audit.col.reason'),
      render: (r) =>
        r.reason ? (
          <span className={styles.clip} dir="auto" title={r.reason}>
            {clip(r.reason, 50)}
          </span>
        ) : (
          <span className={styles.muted}>{t('admin.wp02.audit.noReason')}</span>
        ),
    },
    {
      key: 'summary',
      header: t('admin.wp02.audit.col.summary'),
      render: (r) =>
        r.summary ? (
          <span className={styles.clip} dir="auto" title={r.summary}>
            {clip(r.summary, 50)}
          </span>
        ) : (
          <span className={styles.muted}>—</span>
        ),
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
    {
      key: 'request',
      header: t('admin.wp02.audit.col.request'),
      render: (r) =>
        r.requestId ? (
          // Kopyalama düğmesi satırı açmasın
          <span
            className={styles.requestCell}
            onClick={(e) => e.stopPropagation()}
            onKeyDown={(e) => e.stopPropagation()}
          >
            <code className={`${styles.code} ltr`} title={r.requestId}>
              {r.requestId.slice(0, 8)}
            </code>
            <CopyButton value={r.requestId} label={t('admin.wp02.audit.copyRequest')} />
          </span>
        ) : (
          <span className={styles.muted}>—</span>
        ),
    },
  ];

  const data = list.data;
  return (
    <div>
      <PageHeader
        title={t('admin.audit.title')}
        description={t('admin.wp02.audit.subtitle')}
        actions={
          <>
            <Link to={paths.admin.auditMessageAccess}>{t('admin.wp02.audit.messageAccessLink')}</Link>
            <Button variant="secondary" leftIcon={<Icon name="download" size={16} />} onClick={() => setCsvOpen(true)}>
              {t('admin.wp02.audit.exportCsv')}
            </Button>
          </>
        }
      />
      <AuditFilterBar
        value={f}
        onChange={update}
        resetKey={resetKey}
        onReset={() => {
          setResetKey((k) => k + 1);
          setSp(filtersToParams(EMPTY_AUDIT_FILTERS), { replace: true });
        }}
      />

      {list.isError && !data ? (
        <ErrorState
          title={t('admin.wp02.audit.error.title')}
          description={errorMessage(i18n, list.error)}
          onRetry={() => void list.refetch()}
        />
      ) : (
        <div className={styles.card}>
          <Table
            caption={t('admin.audit.title')}
            columns={columns}
            rows={data?.items}
            rowKey={(r) => r.id}
            loading={list.isLoading}
            onRowClick={(r) => setOpenRow(r)}
            empty={
              <EmptyState
                icon="list"
                compact
                title={t('admin.wp02.audit.empty.title')}
                description={t('admin.wp02.audit.empty.hint')}
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
              <span className={styles.muted}>{t('admin.wp02.audit.total', { n: formatNumber(data.totalItems) })}</span>
            </div>
          )}
        </div>
      )}

      <AuditDrawer row={openRow} onClose={() => setOpenRow(null)} />

      <ConfirmDialog
        open={csvOpen}
        onClose={() => !csv.isPending && setCsvOpen(false)}
        onConfirm={() => void runCsv()}
        title={t('admin.wp02.audit.exportCsv')}
        message={t('admin.wp02.audit.exportNote', { max: formatNumber(AUDIT_CSV_MAX_ROWS) })}
        confirmLabel={t('admin.wp02.audit.exportCsv')}
        loading={csv.isPending}
      />
    </div>
  );
}
