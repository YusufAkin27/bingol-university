// SAYFA: Haber yönetimi (/admin/content/news)
// API: GET /api/admin/news?q=&type=&hidden=&page=&size=, PATCH /api/admin/news/{id} {hidden} (api/news.ts),
//      POST /api/admin/sync, POST /api/admin/sync-menu, GET /api/status (api/settings.ts). Kaynak siteye yük bindirir: onay ister.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api, newsApi, qk, settingsApi } from '../../api';
import type { AdminNewsRow, NewsType, SyncSourceStatus } from '../../api/types';
import {
  Badge,
  Button,
  Card,
  ConfirmDialog,
  DataToolbar,
  EmptyState,
  ErrorState,
  Icon,
  IconButton,
  PageHeader,
  Pagination,
  Select,
  StatusPill,
  Table,
  useToast,
  type Column,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import styles from './content/News.module.css';

const TYPES: NewsType[] = ['HABER', 'DUYURU', 'ETKINLIK'];
const SOURCES = ['NEWS', 'MENU'] as const;
type Source = (typeof SOURCES)[number];
const PAGE_SIZE = 20;

/** Senkron yanıtından kısa özet: `HABER 3, DUYURU 1`; hiçbiri yoksa null. */
function syncSummary(r: Record<string, number> | undefined): string | null {
  const parts = Object.entries(r ?? {})
    .filter(([, n]) => n > 0)
    .map(([k, n]) => `${k} ${n}`);
  return parts.length ? parts.join(', ') : null;
}

export default function NewsAdminPage() {
  const i18n = useI18n();
  const { t, formatDate, formatDateTime } = i18n;
  usePageTitle(t('admin.news.title'));
  const toast = useToast();
  const qc = useQueryClient();

  const [q, setQ] = useState('');
  const [type, setType] = useState<NewsType | ''>('');
  const [vis, setVis] = useState<'' | 'visible' | 'hidden'>('');
  const [page, setPage] = useState(0);
  const [syncing, setSyncing] = useState<Source | null>(null);

  const params = {
    q: q || undefined,
    type: type || undefined,
    hidden: vis === '' ? undefined : vis === 'hidden',
    page,
    size: PAGE_SIZE,
  };
  const list = useQuery({ queryKey: qk.news.list(params), queryFn: () => newsApi.listNews(params), placeholderData: (p) => p });
  const status = useQuery({ queryKey: qk.settings.sync(), queryFn: settingsApi.getSyncStatus });

  const setHidden = useMutation({
    mutationFn: (v: { row: AdminNewsRow; hidden: boolean }) => newsApi.setNewsHidden(v.row.id, v.hidden),
    onSuccess: (_d, v) => {
      toast.success(t(v.hidden ? 'admin.news.hiddenToast' : 'admin.news.shownToast'));
      void qc.invalidateQueries({ queryKey: qk.news.all });
    },
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });

  const sync = useMutation({
    mutationFn: async (src: Source) => {
      if (src === 'NEWS') return { src, result: await api.post<Record<string, number>>('/admin/sync') };
      return { src, result: await api.post<Record<string, number>>('/admin/sync-menu') };
    },
    onSuccess: ({ src, result }) => {
      if (src === 'NEWS') {
        toast.success(t('admin.news.sync.doneNews', { summary: syncSummary(result) ?? t('admin.news.sync.noNew') }));
      } else {
        toast.success(t('admin.news.sync.doneMenu', { n: result?.changed ?? 0 }));
      }
      setSyncing(null);
      void qc.invalidateQueries({ queryKey: qk.settings.sync() });
      void qc.invalidateQueries({ queryKey: qk.news.all });
    },
    onError: (e) => {
      toast.error(errorMessage(i18n, e));
      setSyncing(null);
      void qc.invalidateQueries({ queryKey: qk.settings.sync() });
    },
  });

  const columns: Column<AdminNewsRow>[] = [
    {
      key: 'title',
      header: t('admin.news.col.title'),
      render: (r) => (
        <span className={styles.title}>
          <span dir="auto" className={r.hidden ? styles.dim : undefined}>
            {r.title}
          </span>
          {r.hidden && <Badge tone="danger">{t('admin.news.hiddenBadge')}</Badge>}
        </span>
      ),
    },
    { key: 'type', header: t('admin.news.col.type'), render: (r) => t(`admin.news.type.${r.type}`) },
    { key: 'date', header: t('admin.news.col.date'), render: (r) => formatDate(r.publishedDate) },
    {
      key: 'source',
      header: t('admin.news.col.source'),
      render: (r) => (
        <a href={r.url} target="_blank" rel="noopener noreferrer" className={styles.source}>
          {t('admin.news.openSource')}
          <Icon name="external" size={14} />
        </a>
      ),
    },
    {
      key: 'actions',
      header: <span className="sr-only">{t('admin.news.col.actions')}</span>,
      align: 'end',
      render: (r) => (
        <IconButton
          variant="secondary"
          size="sm"
          label={`${r.hidden ? t('admin.news.show') : t('admin.news.hide')}: ${r.title}`}
          disabled={setHidden.isPending && setHidden.variables?.row.id === r.id}
          onClick={() => setHidden.mutate({ row: r, hidden: !r.hidden })}
        >
          <Icon name={r.hidden ? 'eye' : 'eyeOff'} size={16} />
        </IconButton>
      ),
    },
  ];

  function sourceStatus(src: Source): SyncSourceStatus | undefined {
    return status.data?.[src];
  }

  return (
    <>
      <PageHeader title={t('admin.news.title')} />
      <Card title={t('admin.news.sync.title')} className={styles.syncCard}>
        {status.isError ? (
          <p className={styles.muted}>{t('admin.news.sync.unavailable')}</p>
        ) : (
          <div className={styles.sources}>
            {SOURCES.map((src) => {
              const s = sourceStatus(src);
              return (
                <div key={src} className={styles.source2} data-source={src}>
                  <div className={styles.srcHead}>
                    <strong>{t(`admin.news.sync.${src}`)}</strong>
                    {s && (
                      <StatusPill tone={s.maintenance ? 'danger' : 'success'}>
                        {s.maintenance ? t('admin.news.sync.maintenance') : t('admin.news.sync.ok')}
                      </StatusPill>
                    )}
                  </div>
                  <p className={styles.muted}>
                    {t('admin.news.sync.lastSuccess', {
                      date: s?.lastSuccessAt ? formatDateTime(s.lastSuccessAt) : t('admin.news.sync.never'),
                    })}
                  </p>
                  <p className={styles.muted}>
                    {t('admin.news.sync.lastAttempt', {
                      date: s?.lastAttemptAt ? formatDateTime(s.lastAttemptAt) : t('admin.news.sync.never'),
                    })}
                  </p>
                  {s?.maintenance && s.message && (
                    <p className={styles.muted}>{t('admin.news.sync.message', { message: s.message })}</p>
                  )}
                  <Button
                    size="sm"
                    variant="secondary"
                    leftIcon={<Icon name="download" size={16} />}
                    loading={sync.isPending && sync.variables === src}
                    onClick={() => setSyncing(src)}
                  >
                    {t('admin.news.sync.run')}
                  </Button>
                </div>
              );
            })}
          </div>
        )}
      </Card>

      <DataToolbar
        onSearch={(v) => {
          setQ(v);
          setPage(0);
        }}
        searchPlaceholder={t('admin.news.searchPlaceholder')}
        filters={
          <div className={styles.filterRow}>
            <Select className={styles.filter}
              aria-label={t('admin.news.filter.type')}
              value={type}
              onChange={(e) => {
                setType(e.target.value as NewsType | '');
                setPage(0);
              }}
            >
              <option value="">{t('admin.news.filter.allTypes')}</option>
              {TYPES.map((x) => (
                <option key={x} value={x}>
                  {t(`admin.news.type.${x}`)}
                </option>
              ))}
            </Select>
            <Select className={styles.filter}
              aria-label={t('admin.news.filter.visibility')}
              value={vis}
              onChange={(e) => {
                setVis(e.target.value as '' | 'visible' | 'hidden');
                setPage(0);
              }}
            >
              <option value="">{t('admin.news.filter.all')}</option>
              <option value="visible">{t('admin.news.filter.visible')}</option>
              <option value="hidden">{t('admin.news.filter.hidden')}</option>
            </Select>
          </div>
        }
      />

      {list.isError ? (
        <ErrorState onRetry={() => void list.refetch()} description={errorMessage(i18n, list.error)} />
      ) : (
        <>
          <Table
            caption={t('admin.news.title')}
            columns={columns}
            rows={list.data?.items}
            rowKey={(r) => r.id}
            loading={list.isLoading}
            empty={
              <EmptyState
                compact
                icon="news"
                title={t('admin.news.empty.title')}
                description={t('admin.news.empty.hint')}
              />
            }
          />
          {list.data && (
            <Pagination
              page={list.data.page}
              totalPages={list.data.totalPages}
              totalItems={list.data.totalItems}
              onPageChange={setPage}
            />
          )}
        </>
      )}

      <ConfirmDialog
        open={syncing !== null}
        onClose={() => setSyncing(null)}
        onConfirm={() => syncing && sync.mutate(syncing)}
        loading={sync.isPending}
        title={t('admin.news.sync.confirmTitle')}
        message={t('admin.news.sync.confirmBody')}
        confirmLabel={t('admin.news.sync.confirmRun')}
      />
    </>
  );
}
