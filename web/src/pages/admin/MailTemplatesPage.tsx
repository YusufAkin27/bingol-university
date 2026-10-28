// SAYFA: Mail şablonları (/admin/mail/templates, /admin/mail/templates/new, /admin/mail/templates/:id)
// API: GET /api/admin/mail/templates?status=&q=&page=&size=, GET/POST/PUT /templates[/{id}], POST /templates/{id}/publish|archive,
//      DELETE /templates/{id}, POST /templates/preview, POST /templates/{id}/preview|test, GET /templates/{id}/versions,
//      GET /variables (api/adminMail.ts). Önizleme HTML'i yalnız sandbox'lı iframe srcdoc içinde gösterilir.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useParams } from 'react-router-dom';
import { listTemplates, mailKeys, type TemplateRow, type TemplateStatus } from '../../api/adminMail';
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
import { LangBadges, TemplateStatusPill } from './mail/MailParts';
import { TemplateEditor } from './mail/TemplateEditor';
import { mailErrorMessage } from './mail/mailLogic';
import styles from './mail/mail.module.css';

export default function MailTemplatesPage() {
  const { id } = useParams();
  if (id === 'new') return <TemplateEditor id={null} />;
  if (id !== undefined) {
    const n = Number(id);
    return Number.isInteger(n) && n > 0 ? <TemplateEditor key={n} id={n} /> : <TemplateList />;
  }
  return <TemplateList />;
}

const STATUSES: TemplateStatus[] = ['DRAFT', 'PUBLISHED', 'ARCHIVED'];

function TemplateList() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  usePageTitle(t('admin.mail.templates.title'));
  const [status, setStatus] = useState<TemplateStatus | ''>('');
  const [q, setQ] = useState('');
  const [page, setPage] = useState(0);
  const params = { status: status || undefined, q: q || undefined, page, size: 20 };
  const query = useQuery({ queryKey: mailKeys.templates(params), queryFn: () => listTemplates(params) });

  const columns: Column<TemplateRow>[] = [
    {
      key: 'name',
      header: t('admin.mail.templates.col.name'),
      render: (r) => (
        <div>
          <strong>{r.name}</strong>
          {r.description && <div className={styles.muted}>{r.description}</div>}
        </div>
      ),
    },
    { key: 'status', header: t('common.status'), width: '140px', render: (r) => <TemplateStatusPill status={r.status} /> },
    { key: 'langs', header: t('admin.mail.templates.col.langs'), width: '150px', render: (r) => <LangBadges languages={r.languages} /> },
    { key: 'version', header: t('admin.mail.templates.col.version'), width: '90px', align: 'end', render: (r) => `v${r.version}` },
    { key: 'updated', header: t('admin.mail.templates.col.updated'), render: (r) => <span className={styles.nowrap}>{formatDateTime(r.updatedAt)}</span> },
    {
      key: 'open',
      header: <span className="sr-only">{t('common.edit')}</span>,
      width: '110px',
      render: (r) => (
        <ButtonLink to={`${paths.admin.mailTemplates}/${r.id}`} variant="ghost" size="sm" aria-label={`${t('common.edit')}: ${r.name}`}>
          {t('common.edit')}
        </ButtonLink>
      ),
    },
  ];

  return (
    <div>
      <PageHeader
        title={t('admin.mail.templates.title')}
        description={t('admin.mail.templates.intro')}
        actions={
          <ButtonLink to={`${paths.admin.mailTemplates}/new`} leftIcon={<Icon name="plus" size={18} />}>
            {t('admin.mail.templates.new')}
          </ButtonLink>
        }
      />
      <div className={styles.toolbar}>
        <div className={styles.toolbarSearch}>
          <SearchInput
            label={t('common.search')}
            placeholder={t('admin.mail.templates.search')}
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
              setStatus(e.target.value as TemplateStatus | '');
              setPage(0);
            }}
          >
            <option value="">{t('common.all')}</option>
            {STATUSES.map((s) => (
              <option key={s} value={s}>
                {t(`admin.mail.tstatus.${s}`)}
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
            caption={t('admin.mail.templates.title')}
            columns={columns}
            rows={query.data?.items}
            rowKey={(r) => r.id}
            loading={query.isLoading}
            empty={
              <EmptyState
                icon="mail"
                title={t('admin.mail.templates.empty.title')}
                description={t('admin.mail.templates.empty.hint')}
                action={<ButtonLink to={`${paths.admin.mailTemplates}/new`}>{t('admin.mail.templates.new')}</ButtonLink>}
              />
            }
          />
          <Pagination page={query.data?.page ?? page} totalPages={query.data?.totalPages ?? 0} totalItems={query.data?.totalItems} onPageChange={setPage} />
        </>
      )}
    </div>
  );
}
