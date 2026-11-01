// SAYFA: İki faktörlü doğrulama (/admin/two-factor)
// API: GET /api/admin/two-factor/summary, GET /api/admin/two-factor/users?page&size&q (api/twoFactor.ts; izin users.read).
//      E-posta sunucuda maskelenir (PermissionAwareMasking). Satır, kullanıcı ayrıntısına bağlanır.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { qk } from '../../api/queryKeys';
import type { TwoFactorUserRow } from '../../api/types';
import { getTwoFactorSummary, listTwoFactorUsers } from '../../api/twoFactor';
import {
  Avatar,
  Badge,
  EmptyState,
  ErrorState,
  Insight,
  PageHeader,
  Pagination,
  ResponsiveTable,
  SearchInput,
  StatTile,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { gt } from './twofactor/dict';
import people from './people/people.module.css';
import styles from './users/users.module.css';

const PAGE_SIZE = 20;

export default function TwoFactorPage() {
  const i18n = useI18n();
  const t = gt(i18n);
  const { td, formatNumber, formatDateTime } = i18n;
  usePageTitle(t('admin.twoFactor.title'));
  const [q, setQ] = useState('');
  const [page, setPage] = useState(0);

  const summary = useQuery({ queryKey: qk.users.twoFactorSummary(), queryFn: getTwoFactorSummary });
  const params = { page, size: PAGE_SIZE, q };
  const list = useQuery({
    queryKey: qk.users.twoFactorList(params),
    queryFn: () => listTwoFactorUsers({ page, size: PAGE_SIZE, q: q || undefined }),
    placeholderData: keepPreviousData,
  });

  const s = summary.data;
  const data = list.data;
  const dash = <span className={styles.muted}>—</span>;

  const columns: Column<TwoFactorUserRow>[] = [
    {
      key: 'name',
      header: t('admin.twoFactor.col.name'),
      card: { priority: 1 },
      render: (u) => (
        <div className={styles.person}>
          <Avatar name={u.displayName} size={32} />
          <div className={styles.personText}>
            <span className={styles.personName}>{u.displayName}</span>
            <span className={`${styles.personMail} ltr`}>{u.email}</span>
          </div>
        </div>
      ),
    },
    {
      key: 'role',
      header: t('admin.twoFactor.col.role'),
      card: { priority: 2 },
      render: (u) => (
        <Badge tone={u.role === 'ADMIN' ? 'primary' : 'neutral'}>{td(`admin.users.role.${u.role}`)}</Badge>
      ),
    },
    {
      key: 'enabledAt',
      header: t('admin.twoFactor.col.enabledAt'),
      render: (u) =>
        u.enabledAt ? <span className={styles.nowrap}>{formatDateTime(u.enabledAt)}</span> : dash,
    },
    {
      key: 'devices',
      header: t('admin.twoFactor.col.devices'),
      align: 'end',
      card: { priority: 3 },
      render: (u) => formatNumber(u.trustedDeviceCount),
    },
    {
      key: 'lastLoginAt',
      header: t('admin.twoFactor.col.lastLogin'),
      render: (u) =>
        u.lastLoginAt ? (
          <span className={styles.nowrap}>{formatDateTime(u.lastLoginAt)}</span>
        ) : (
          <span className={styles.muted}>{t('admin.twoFactor.never')}</span>
        ),
    },
    {
      key: 'detail',
      header: t('admin.twoFactor.col.detail'),
      card: { actions: true },
      render: (u) => (
        <Link
          to={paths.admin.user(u.userId)}
          state={{ from: paths.admin.twoFactor }}
          aria-label={t('admin.twoFactor.openUser', { name: u.displayName })}
          onClick={(e) => e.stopPropagation()}
        >
          #{u.userId}
        </Link>
      ),
    },
  ];

  return (
    <div>
      <PageHeader title={t('admin.twoFactor.title')} description={t('admin.twoFactor.intro')} />

      <section className={people.summary} aria-label={t('admin.twoFactor.summary')} data-search-anchor="twofactor-summary">
        <Insight
          tone={s && s.enabledCount === 0 ? 'warn' : 'info'}
          parts={
            s
              ? t('admin.twoFactor.sentence', {
                  enabled: formatNumber(s.enabledCount),
                  total: formatNumber(s.totalActiveUsers),
                  percent: formatNumber(Math.round(s.enabledPercent * 10) / 10),
                })
              : t('admin.twoFactor.loading')
          }
        />
        <div className={people.tiles}>
          <StatTile
            label={t('admin.twoFactor.sum.enabled')}
            value={s?.enabledCount}
            unit={t('admin.twoFactor.unit.person')}
            icon="shield"
            loading={summary.isLoading}
          />
          <StatTile
            label={t('admin.twoFactor.sum.percent')}
            value={s ? `%${formatNumber(Math.round(s.enabledPercent * 10) / 10)}` : undefined}
            caption={s ? t('admin.twoFactor.sum.percentHint', { n: formatNumber(s.totalActiveUsers) }) : undefined}
            loading={summary.isLoading}
          />
          <StatTile
            label={t('admin.twoFactor.sum.last7')}
            value={s?.enabledLast7Days}
            unit={t('admin.twoFactor.unit.person')}
            loading={summary.isLoading}
          />
          <StatTile
            label={t('admin.twoFactor.sum.devices')}
            value={s?.trustedDeviceTotal}
            unit={t('admin.twoFactor.unit.device')}
            icon="smartphone"
            loading={summary.isLoading}
          />
        </div>
      </section>
      {summary.isError && (
        <ErrorState
          compact
          description={errorMessage(i18n, summary.error)}
          onRetry={() => void summary.refetch()}
        />
      )}

      <div className={styles.topRow}>
        <div className={styles.search} data-search-anchor="twofactor-search">
          <SearchInput
            defaultValue={q}
            placeholder={t('admin.twoFactor.searchPlaceholder')}
            onSearch={(v) => {
              setQ(v);
              setPage(0);
            }}
          />
        </div>
      </div>

      {list.isError && !data ? (
        <ErrorState description={errorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : (
        <>
          {data && (
            <p className={styles.meta} aria-live="polite">
              {t('admin.twoFactor.count', { n: formatNumber(data.totalItems) })}
            </p>
          )}
          <div className={styles.tableCard} data-search-anchor="twofactor-table">
            <ResponsiveTable
              caption={t('admin.twoFactor.title')}
              columns={columns}
              rows={data?.items}
              rowKey={(u) => u.userId}
              loading={list.isLoading}
              breakpoint={720}
              empty={
                <EmptyState
                  icon="shield"
                  compact
                  title={t('admin.twoFactor.empty.title')}
                  description={t('admin.twoFactor.empty.hint')}
                />
              }
            />
            {data && data.totalPages > 1 && (
              <div className={styles.pager}>
                <Pagination
                  page={data.page}
                  totalPages={data.totalPages}
                  totalItems={data.totalItems}
                  onPageChange={setPage}
                />
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
