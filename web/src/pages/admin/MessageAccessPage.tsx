// SAYFA: Mesaj erişim kayıtları (/admin/audit/message-access)
// API: GET /api/admin/audit/message-access?page=&size=&adminId=&targetUserId=&conversationId=&kind=&q=&from=&to= (api/audit.ts).
// Kim, hangi kullanıcının hangi sohbetini/mesajını ne zaman ve hangi sebeple açtı. İçerik dönmez; bu okuma da denetlenir.
// Süzgeç durumu URL'dedir.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useMemo, useRef, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { MESSAGE_ACCESS_KINDS, listMessageAccess, type MessageAccessRow } from '../../api/audit';
import { qk } from '../../api/queryKeys';
import { listUsers } from '../../api/users';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  PageHeader,
  Pagination,
  SearchInput,
  Select,
  Table,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import styles from './audit/audit.module.css';
import {
  accessFiltersFromParams,
  accessFiltersToParams,
  accessFiltersToQuery,
  num,
  type AccessFilters,
} from './audit/accessLogic';
import { clip } from './audit/auditLogic';
import { DebouncedInput } from './users/DebouncedInput';

export default function MessageAccessPage() {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.wp02.access.title'));
  const [sp, setSp] = useSearchParams();
  const f = useMemo(() => accessFiltersFromParams(sp), [sp]);
  const [resetKey, setResetKey] = useState(0);

  // Aynı anda biten iki gecikmeli alan birbirini ezmesin: en güncel süzgeç ref'te tutulur.
  const latest = useRef(f);
  latest.current = f;
  const update = (patch: Partial<AccessFilters>) => {
    const next = { ...latest.current, page: 0, ...patch };
    latest.current = next;
    setSp(accessFiltersToParams(next), { replace: !('page' in patch) });
  };
  const query = accessFiltersToQuery(f);
  const list = useQuery({
    queryKey: ['audit', 'message-access', query],
    queryFn: () => listMessageAccess(query),
    placeholderData: keepPreviousData,
  });
  const admins = useQuery({
    queryKey: qk.users.list({ role: 'ADMIN', size: 100 }),
    queryFn: () => listUsers({ role: 'ADMIN', size: 100 }),
    staleTime: 60_000,
  });
  const activeCount = [f.adminId !== undefined, f.targetUserId, f.conversationId, f.kind, f.q, f.from, f.to].filter(Boolean).length;

  const columns: Column<MessageAccessRow>[] = [
    { key: 'at', header: t('admin.wp02.access.col.time'), render: (r) => <span className={styles.nowrap}>{formatDateTime(r.at)}</span> },
    {
      key: 'admin',
      header: t('admin.wp02.access.col.admin'),
      render: (r) => (r.adminEmail ? <span className="ltr">{r.adminEmail}</span> : <span className={styles.muted}>—</span>),
    },
    {
      key: 'user',
      header: t('admin.wp02.access.col.user'),
      render: (r) =>
        r.targetUserId != null ? (
          <Link to={paths.admin.user(r.targetUserId)} className={styles.targetLink}>
            {t('admin.wp02.access.userLink', { id: r.targetUserId })}
          </Link>
        ) : (
          <span className={styles.muted}>—</span>
        ),
    },
    {
      key: 'conversation',
      header: t('admin.wp02.access.col.conversation'),
      render: (r) =>
        r.conversationId != null ? (
          r.targetUserId != null ? (
            <Link to={paths.admin.userMessages(r.targetUserId, r.conversationId)}>
              {t('admin.wp02.access.chatLink', { id: r.conversationId })}
            </Link>
          ) : (
            <span>{t('admin.wp02.access.chatLink', { id: r.conversationId })}</span>
          )
        ) : (
          <span className={styles.muted}>—</span>
        ),
    },
    {
      key: 'kind',
      header: t('admin.wp02.access.col.kind'),
      render: (r) => <Badge tone="primary">{td(`admin.wp02.access.kind.${r.kind}`, r.kind)}</Badge>,
    },
    {
      key: 'count',
      header: t('admin.wp02.access.col.count'),
      align: 'end',
      render: (r) => (r.messageCount != null ? formatNumber(r.messageCount) : '—'),
    },
    {
      key: 'range',
      header: t('admin.wp02.access.col.range'),
      render: (r) =>
        r.fromMessageId != null && r.toMessageId != null ? (
          <span className="ltr">{t('admin.wp02.access.range', { from: r.fromMessageId, to: r.toMessageId })}</span>
        ) : (
          <span className={styles.muted}>—</span>
        ),
    },
    {
      key: 'reason',
      header: t('admin.wp02.access.col.reason'),
      render: (r) =>
        r.reason ? (
          <span className={styles.clip} dir="auto" title={r.reason}>
            {clip(r.reason, 80)}
          </span>
        ) : (
          <span className={styles.muted}>—</span>
        ),
    },
    { key: 'ip', header: t('admin.wp02.access.col.ip'), render: (r) => <span className="ltr">{r.ip ?? '—'}</span> },
  ];

  const data = list.data;
  return (
    <div>
      <PageHeader
        title={t('admin.wp02.access.title')}
        description={t('admin.wp02.access.subtitle')}
        actions={<Link to={paths.admin.audit}>{t('admin.wp02.access.back')}</Link>}
      />
      <div className={styles.filters} role="group" aria-label={t('admin.wp02.access.filters.label')}>
        <div className={styles.bar}>
          <div className={styles.search}>
            <SearchInput
              key={resetKey}
              defaultValue={f.q}
              placeholder={t('admin.wp02.access.filter.q')}
              label={t('admin.wp02.access.filter.q')}
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
              {f.adminId !== undefined && !admins.data?.items.some((a) => a.id === f.adminId) && (
                <option value={f.adminId}>#{f.adminId}</option>
              )}
            </Select>
          </div>
          <div className={styles.select}>
            <Select aria-label={t('admin.wp02.access.filter.kind')} value={f.kind} onChange={(e) => update({ kind: e.target.value })}>
              <option value="">
                {t('admin.wp02.access.filter.kind')}: {t('common.all')}
              </option>
              {MESSAGE_ACCESS_KINDS.map((k) => (
                <option key={k} value={k}>
                  {td(`admin.wp02.access.kind.${k}`, k)}
                </option>
              ))}
            </Select>
          </div>
        </div>
        <div className={styles.bar}>
          <div className={styles.select}>
            <DebouncedInput
              value={f.targetUserId}
              label={t('admin.wp02.access.filter.targetUserId')}
              onCommit={(v) => update({ targetUserId: num(v) })}
            />
          </div>
          <div className={styles.select}>
            <DebouncedInput
              value={f.conversationId}
              label={t('admin.wp02.access.filter.conversationId')}
              onCommit={(v) => update({ conversationId: num(v) })}
            />
          </div>
          <FormField label={t('admin.wp02.access.filter.from')} className={styles.dateField}>
            <Input type="date" value={f.from} max={f.to || undefined} onChange={(e) => update({ from: e.target.value })} />
          </FormField>
          <FormField label={t('admin.wp02.access.filter.to')} className={styles.dateField}>
            <Input type="date" value={f.to} min={f.from || undefined} onChange={(e) => update({ to: e.target.value })} />
          </FormField>
          <div className={styles.resetWrap}>
            <Button
              variant="ghost"
              size="sm"
              disabled={activeCount === 0}
              onClick={() => {
                setResetKey((k) => k + 1);
                setSp(new URLSearchParams(), { replace: true });
              }}
            >
              {t('admin.wp02.access.filter.reset')}
            </Button>
          </div>
        </div>
      </div>

      {list.isError && !data ? (
        <ErrorState
          title={t('admin.wp02.access.error.title')}
          description={errorMessage(i18n, list.error)}
          onRetry={() => void list.refetch()}
        />
      ) : (
        <div className={styles.card}>
          <Table
            caption={t('admin.wp02.access.title')}
            columns={columns}
            rows={data?.items}
            rowKey={(r) => r.id}
            loading={list.isLoading}
            empty={
              <EmptyState
                icon="shield"
                compact
                title={t('admin.wp02.access.empty.title')}
                description={t('admin.wp02.access.empty.hint')}
              />
            }
          />
          {data && data.totalPages > 1 ? (
            <div className={styles.pager}>
              <Pagination
                page={data.page}
                totalPages={data.totalPages}
                totalItems={data.totalItems}
                onPageChange={(page) => update({ page })}
              />
            </div>
          ) : (
            data && (
              <div className={styles.pager}>
                <span className={styles.muted}>{t('admin.wp02.access.total', { n: formatNumber(data.totalItems) })}</span>
              </div>
            )
          )}
        </div>
      )}
    </div>
  );
}
