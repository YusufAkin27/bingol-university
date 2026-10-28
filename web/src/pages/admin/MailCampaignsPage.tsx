// SAYFA: Mail kampanyaları (/admin/mail/campaigns, /new sihirbazı, /:id ayrıntı)
// API: GET /api/admin/mail/campaigns?status=&q=&page=, GET /campaigns/{id}, GET /campaigns/{id}/recipients?status=,
//      POST /campaigns/audience/preview, POST /campaigns, POST /campaigns/{id}/schedule|pause|resume|cancel (api/adminMail.ts).
//      SENDING/SCHEDULED kampanya varken liste ve ayrıntı 5 sn'de bir yenilenir.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useParams } from 'react-router-dom';
import { listMailCampaigns, mailKeys, type CampaignStatus, type MailCampaignView } from '../../api/adminMail';
import {
  ButtonLink,
  EmptyState,
  ErrorState,
  FormField,
  Icon,
  PageHeader,
  Pagination,
  SearchInput,
  Select,
  Table,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { CampaignDetail } from './mail/CampaignDetail';
import { CampaignWizard } from './mail/CampaignWizard';
import { CampaignStatusPill, ProgressBar } from './mail/MailParts';
import { isCampaignLive, mailErrorMessage } from './mail/mailLogic';
import styles from './mail/mail.module.css';

export default function MailCampaignsPage() {
  const { id } = useParams();
  if (id === 'new') return <CampaignWizard />;
  if (id !== undefined) {
    const n = Number(id);
    if (Number.isInteger(n) && n > 0) return <CampaignDetail key={n} id={n} />;
  }
  return <CampaignList />;
}

const STATUSES: CampaignStatus[] = ['DRAFT', 'SCHEDULED', 'SENDING', 'PAUSED', 'DONE', 'CANCELLED', 'FAILED'];

function CampaignList() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  usePageTitle(t('admin.mail.campaigns.title'));
  const [status, setStatus] = useState<CampaignStatus | ''>('');
  const [q, setQ] = useState('');
  const [page, setPage] = useState(0);
  const params = { status: status || undefined, q: q || undefined, page, size: 20 };
  const query = useQuery({
    queryKey: mailKeys.campaigns(params),
    queryFn: () => listMailCampaigns(params),
    refetchInterval: (qr) => (qr.state.data?.items.some((c) => isCampaignLive(c.status)) ? 5000 : false),
  });

  const columns: Column<MailCampaignView>[] = [
    {
      key: 'name',
      header: t('admin.mail.campaigns.col.name'),
      render: (c) => (
        <div>
          <strong>{c.name}</strong>
          <div className={styles.muted}>{c.templateName}</div>
        </div>
      ),
    },
    { key: 'status', header: t('common.status'), width: '170px', render: (c) => <CampaignStatusPill status={c.status} /> },
    {
      key: 'progress',
      header: t('admin.mail.campaigns.col.progress'),
      width: '220px',
      render: (c) => (
        <div>
          <ProgressBar percent={c.counters.progressPercent} label={`${c.name}: ${t('admin.mail.detail.progress')}`} />
          <span className={styles.muted}>
            {formatNumber(c.counters.queued)} / {formatNumber(c.counters.target)}
          </span>
        </div>
      ),
    },
    {
      key: 'when',
      header: t('admin.mail.campaigns.col.when'),
      render: (c) => <span className={styles.nowrap}>{formatDateTime(c.scheduledAt ?? c.createdAt)}</span>,
    },
    {
      key: 'open',
      header: <span className="sr-only">{t('admin.mail.campaigns.open')}</span>,
      width: '110px',
      render: (c) => (
        <ButtonLink to={`${paths.admin.mailCampaigns}/${c.id}`} variant="ghost" size="sm" aria-label={`${t('admin.mail.campaigns.open')}: ${c.name}`}>
          {t('admin.mail.campaigns.open')}
        </ButtonLink>
      ),
    },
  ];

  return (
    <div>
      <PageHeader
        title={t('admin.mail.campaigns.title')}
        description={t('admin.mail.campaigns.intro')}
        actions={
          <ButtonLink to={`${paths.admin.mailCampaigns}/new`} leftIcon={<Icon name="plus" size={18} />}>
            {t('admin.mail.campaigns.new')}
          </ButtonLink>
        }
      />
      <div className={styles.toolbar}>
        <div className={styles.toolbarSearch}>
          <SearchInput
            label={t('common.search')}
            placeholder={t('admin.mail.campaigns.search')}
            onSearch={(v) => {
              setQ(v.trim());
              setPage(0);
            }}
          />
        </div>
        <FormField label={t('common.status')}>
          <Select
            value={status}
            onChange={(e) => {
              setStatus(e.target.value as CampaignStatus | '');
              setPage(0);
            }}
          >
            <option value="">{t('common.all')}</option>
            {STATUSES.map((s) => (
              <option key={s} value={s}>
                {t(`admin.mail.cstatus.${s}`)}
              </option>
            ))}
          </Select>
        </FormField>
      </div>
      {query.isError ? (
        <ErrorState description={mailErrorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
      ) : (
        <>
          <Table
            caption={t('admin.mail.campaigns.title')}
            columns={columns}
            rows={query.data?.items}
            rowKey={(c) => c.id}
            loading={query.isLoading}
            empty={
              <EmptyState
                icon="mail"
                title={t('admin.mail.campaigns.empty.title')}
                description={t('admin.mail.campaigns.empty.hint')}
                action={<ButtonLink to={`${paths.admin.mailCampaigns}/new`}>{t('admin.mail.campaigns.new')}</ButtonLink>}
              />
            }
          />
          <Pagination page={query.data?.page ?? page} totalPages={query.data?.totalPages ?? 0} totalItems={query.data?.totalItems} onPageChange={setPage} />
        </>
      )}
    </div>
  );
}
