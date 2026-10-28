// SAYFA: Kampanyalar (/admin/campaigns)
// API: GET /api/admin/push/campaigns?cursor=&size=, GET .../{id}, POST .../{id}/cancel (api/campaigns.ts).
//      SENDING/SCHEDULED kampanya varken liste 5 sn'de bir yenilenir.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { listCampaigns } from '../../api/campaigns';
import { qk } from '../../api/queryKeys';
import type { CampaignStatus, CampaignView } from '../../api/types';
import {
  Badge,
  ButtonLink,
  ErrorState,
  EmptyState,
  Icon,
  LoadMore,
  PageHeader,
  StatusPill,
  Table,
  Tabs,
  toneFor,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { CampaignDrawer } from './campaigns/CampaignDrawer';
import { useAdminNames, useAudienceSummary } from './campaigns/format';
import { CAMPAIGN_STATUSES, isLive } from './campaigns/lib';
import { adminErrorMessage } from './campaigns/shared';
import styles from './campaigns/campaigns.module.css';

export default function CampaignsPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.campaigns.title'));
  const audienceSummary = useAudienceSummary();
  const [openId, setOpenId] = useState<number | null>(null);
  const [params, setParams] = useSearchParams();
  const sp = params.get('status') as CampaignStatus | null;
  const status: CampaignStatus | undefined = sp && CAMPAIGN_STATUSES.includes(sp) ? sp : undefined;

  const query = useInfiniteQuery({
    queryKey: [...qk.campaigns.list(), status ?? 'ALL', 'pages'],
    queryFn: ({ pageParam }) => listCampaigns({ cursor: pageParam, size: 20, status }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    refetchInterval: (q) =>
      q.state.data?.pages.some((p) => p.items.some((c) => isLive(c.status))) ? 5000 : false,
  });
  const items = query.data?.pages.flatMap((p) => p.items) ?? [];
  const names = useAdminNames(items.map((c) => c.createdBy));
  const live = items.some((c) => isLive(c.status));

  const columns: Column<CampaignView>[] = [
    {
      key: 'status',
      header: t('common.status'),
      width: '150px',
      render: (c) => <StatusPill tone={toneFor(c.status)}>{t(`admin.campaigns.status.${c.status}`)}</StatusPill>,
    },
    {
      key: 'content',
      header: t('admin.campaigns.col.content'),
      render: (c) => (
        <div className={styles.cellContent}>
          <span className={styles.cellTitle}>{c.tr.title}</span>
          <span className={styles.cellBody}>{c.tr.body}</span>
          {c.type === 'SYSTEM' && <Badge tone="danger">{t('admin.campaigns.type.SYSTEM')}</Badge>}
          {c.source && c.source !== 'CAMPAIGN' && <Badge>{t(`admin.campaigns.source.${c.source}`)}</Badge>}
        </div>
      ),
    },
    { key: 'audience', header: t('admin.campaigns.col.audience'), render: (c) => audienceSummary(c.audience) },
    {
      key: 'recipients',
      header: t('admin.campaigns.col.recipients'),
      align: 'end',
      render: (c) =>
        c.recipientCount === null ? (
          '—'
        ) : (
          <span className={styles.cellContent}>
            <span>
              {formatNumber(c.recipientCount)}
              {c.audienceSize != null && ` / ${formatNumber(c.audienceSize)}`}
            </span>
            {!!c.skippedCount && (
              <span className={styles.cellBody}>{t('admin.campaigns.skipped', { n: formatNumber(c.skippedCount) })}</span>
            )}
          </span>
        ),
    },
    {
      key: 'when',
      header: t('admin.campaigns.col.when'),
      render: (c) => (
        <span className={styles.nowrap}>
          {formatDateTime(c.status === 'SCHEDULED' ? c.scheduledAt : (c.startedAt ?? c.scheduledAt))}
        </span>
      ),
    },
    {
      key: 'createdBy',
      header: t('admin.campaigns.col.createdBy'),
      render: (c) => names[c.createdBy] ?? `#${c.createdBy}`,
    },
  ];

  return (
    <div>
      <PageHeader
        title={t('admin.campaigns.title')}
       
        actions={
          <ButtonLink to={paths.admin.campaignNew} leftIcon={<Icon name="plus" size={18} />}>
            {t('admin.campaigns.new')}
          </ButtonLink>
        }
      />
      <div className={styles.statusTabs}>
        <Tabs
          label={t('admin.campaigns.filter.status')}
          value={status ?? 'ALL'}
          tabs={[
            { id: 'ALL', label: t('admin.campaigns.filter.all') },
            ...CAMPAIGN_STATUSES.map((s) => ({ id: s, label: t(`admin.campaigns.status.${s}`) })),
          ]}
          onChange={(id) => setParams(id === 'ALL' ? {} : { status: id }, { replace: true })}
        />
      </div>
      {live && (
        <p className={styles.liveNote} role="status">
          <span className={styles.liveDot} aria-hidden="true" />
          {t('admin.campaigns.autoRefresh')}
        </p>
      )}
      {query.isError ? (
        <ErrorState description={adminErrorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
      ) : (
        <>
          <Table
            caption={t('admin.campaigns.title')}
            columns={columns}
            rows={items}
            rowKey={(c) => c.id}
            loading={query.isLoading}
            onRowClick={(c) => setOpenId(c.id)}
            empty={
              <EmptyState
                icon="bell"
                title={t('admin.campaigns.empty.title')}
                description={t('admin.campaigns.empty.hint')}
                action={<ButtonLink to={paths.admin.campaignNew}>{t('admin.campaigns.new')}</ButtonLink>}
              />
            }
          />
          <LoadMore
            hasMore={!!query.hasNextPage}
            loading={query.isFetchingNextPage}
            onLoadMore={() => void query.fetchNextPage()}
          />
        </>
      )}
      <CampaignDrawer
        id={openId}
        seed={items.find((c) => c.id === openId)}
        onClose={() => setOpenId(null)}
      />
    </div>
  );
}
