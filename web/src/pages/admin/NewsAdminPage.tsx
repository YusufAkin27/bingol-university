// SAYFA: Haber yönetimi (/admin/content/news)
// API: GET /api/admin/news?q=&type=&hidden=&page=&size=, PATCH /api/admin/news/{id} {hidden} (api/news.ts),
//      POST /api/admin/sync, POST /api/admin/sync-menu, GET /api/status (api/settings.ts). Kaynak siteye yük bindirir: onay ister.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api, newsApi, qk, settingsApi } from '../../api';
import type { AdminNewsRow, NewsType, SyncSourceStatus } from '../../api/types';
import type { NewsSourceStatus } from '../../api/adminBulk';
import {
  Badge,
  Button,
  Card,
  ConfirmDialog,
  DataToolbar,
  EmptyState,
  ErrorState,
  Icon,
  Insight,
  PageHeader,
  Pagination,
  ResponsiveTable,
  Select,
  StatTile,
  StatusPill,
  useKitFormat,
  useToast,
  type Column,
} from '../../components/ui';
import { StackedBar, SummaryStrip } from './community/Summary';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { GuardedDialog } from '../../components/admin/GuardedDialog';
import { ADMIN_REASON_MIN } from '../../components/admin/guard/match';
import { BULK_MAX, exportNewsCsv, getSourcesStatus, sourcesKeys } from '../../api/adminBulk';
import { NewsBulkBar } from './bulk/BulkBars';
import { BulkCsvButton, useIdSelection } from './bulk/BulkParts';
import { distributionText, newsDistribution } from './content/newsDist';
import { gt, type GT } from './icerik/dict';
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
  const kit = useKitFormat();
  usePageTitle(t('admin.news.title'));
  const toast = useToast();
  const qc = useQueryClient();

  const [q, setQ] = useState('');
  const [type, setType] = useState<NewsType | ''>('');
  const [vis, setVis] = useState<'' | 'visible' | 'hidden'>('');
  const [page, setPage] = useState(0);
  const [syncing, setSyncing] = useState<Source | null>(null);
  // Gizleme/gösterme onayı: hedef satır ve yeni durum
  const [toggling, setToggling] = useState<{ row: AdminNewsRow; hidden: boolean } | null>(null);
  // P15 toplu işlem seçimi: süzgeç/sayfa değişince sıfırlanır (görünmeyen kayıt işlenmesin)
  const selection = useIdSelection<number>(`${q}|${type}|${vis}|${page}`, BULK_MAX);

  const params = {
    q: q || undefined,
    type: type || undefined,
    hidden: vis === '' ? undefined : vis === 'hidden',
    page,
    size: PAGE_SIZE,
  };
  const list = useQuery({
    queryKey: qk.news.list(params),
    queryFn: () => newsApi.listNews(params),
    placeholderData: (p) => p,
  });
  const status = useQuery({ queryKey: qk.settings.sync(), queryFn: settingsApi.getSyncStatus });
  // Tür dağılımı ve genel sayılar (süzgeçten bağımsız); başarısız olursa eski özet gösterilir
  const overall = useQuery({ queryKey: sourcesKeys.status, queryFn: getSourcesStatus, staleTime: 60_000 });
  const gtx = gt(i18n);

  const sync = useMutation({
    mutationFn: async (src: Source) => {
      if (src === 'NEWS') return { src, result: await api.post<Record<string, number>>('/admin/sync') };
      return { src, result: await api.post<Record<string, number>>('/admin/sync-menu') };
    },
    onSuccess: ({ src, result }) => {
      if (src === 'NEWS') {
        toast.success(
          t('admin.news.sync.doneNews', { summary: syncSummary(result) ?? t('admin.news.sync.noNew') }),
        );
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
      card: { priority: 1 },
      render: (r) => (
        <span className={styles.title}>
          <span dir="auto" className={r.hidden ? styles.dim : undefined}>
            {r.title}
          </span>
          {r.hidden && <Badge tone="danger">{t('admin.news.hiddenBadge')}</Badge>}
        </span>
      ),
    },
    {
      key: 'type',
      header: t('admin.news.col.type'),
      card: { priority: 2 },
      render: (r) => <Badge tone="info">{t(`admin.news.type.${r.type}`)}</Badge>,
    },
    {
      key: 'date',
      header: t('admin.news.col.date'),
      card: { priority: 3 },
      render: (r) => (r.publishedDate ? formatDate(r.publishedDate) : '–'),
    },
    {
      key: 'source',
      header: t('admin.news.col.source'),
      card: { priority: 3, label: t('admin.news.col.source') },
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
      card: { actions: true },
      render: (r) => (
        <Button
          variant="secondary"
          size="sm"
          aria-label={`${r.hidden ? t('admin.news.show') : t('admin.news.hide')}: ${r.title}`}
          leftIcon={<Icon name={r.hidden ? 'eye' : 'eyeOff'} size={16} />}
          onClick={() => setToggling({ row: r, hidden: !r.hidden })}
        >
          {r.hidden ? t('admin.news.show') : t('admin.news.hide')}
        </Button>
      ),
    },
  ];

  const pageHidden = (list.data?.items ?? []).filter((r) => r.hidden).length;
  const total = list.data?.totalItems;

  function sourceStatus(src: Source): SyncSourceStatus | undefined {
    return status.data?.[src];
  }

  return (
    <>
      <PageHeader
        title={t('admin.news.title')}
        actions={
          <span data-search-anchor="news-csv">
            <BulkCsvButton
              filename="haberler.csv"
              fetchCsv={() => exportNewsCsv({ q, type, hidden: vis === '' ? undefined : vis === 'hidden' })}
            />
          </span>
        }
      />
      {overall.data?.news ? (
        <NewsOverview
          news={overall.data.news}
          gtx={gtx}
          typeLabel={(k) => i18n.td(`admin.news.type.${k}`, k)}
          fmt={kit.number}
        />
      ) : (
        list.data && (
          <SummaryStrip
            insight={
              <Insight
                tone={pageHidden > 0 ? 'warn' : 'info'}
                parts={
                  (total ?? 0) === 0
                    ? t('admin.v2.news.insight.empty')
                    : t(pageHidden > 0 ? 'admin.v2.news.insight.hidden' : 'admin.v2.news.insight.noHidden', {
                        total: kit.number(total ?? 0),
                        hidden: kit.number(pageHidden),
                      })
                }
              />
            }
          >
            <StatTile
              icon="news"
              label={t('admin.v2.news.sum.total')}
              value={total ?? 0}
              caption={t('admin.v2.news.sum.totalCap')}
            />
            <StatTile
              icon="eyeOff"
              label={t('admin.v2.news.sum.hidden')}
              value={pageHidden}
              caption={t('admin.v2.news.sum.hiddenCap')}
            />
          </SummaryStrip>
        )
      )}
      <Card title={t('admin.news.sync.title')} className={styles.syncCard} data-search-anchor="news-sync">
        {status.isError ? (
          <p className={styles.muted}>{t('admin.news.sync.unavailable')}</p>
        ) : (
          <div className={styles.sources}>
            {SOURCES.map((src) => {
              const s = sourceStatus(src);
              return (
                <div
                  key={src}
                  className={styles.source2}
                  data-source={src}
                  data-search-anchor={src === 'NEWS' ? 'news-sync-news' : 'news-sync-menu'}
                >
                  <div className={styles.srcHead}>
                    <strong>{t(`admin.news.sync.${src}`)}</strong>
                    {s && (
                      <StatusPill tone={s.maintenance ? 'danger' : 'success'}>
                        {s.maintenance ? t('admin.news.sync.maintenance') : t('admin.news.sync.ok')}
                      </StatusPill>
                    )}
                  </div>
                  {s && (
                    <p
                      className={s.maintenance ? styles.age : styles.muted}
                      data-search-anchor={src === 'NEWS' ? 'news-sync-status' : undefined}
                    >
                      {s.maintenance ? t('admin.v2.news.syncMaintenance') : t('admin.v2.news.syncOk')}
                    </p>
                  )}
                  <p className={styles.muted}>
                    {s?.lastSuccessAt
                      ? t('admin.v2.news.syncAge.ago', { ago: kit.relative(s.lastSuccessAt) })
                      : t('admin.v2.news.syncAge.never')}
                    {s?.lastSuccessAt ? ` (${formatDateTime(s.lastSuccessAt)})` : ''}
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

      <div data-search-anchor="news-q">
        <DataToolbar
          onSearch={(v) => {
            setQ(v);
            setPage(0);
          }}
          searchPlaceholder={t('admin.news.searchPlaceholder')}
          filters={
            <div className={styles.filterRow}>
              <Select
                className={styles.filter}
                data-search-anchor="news-type"
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
              <Select
                className={styles.filter}
                data-search-anchor="news-visible"
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
      </div>

      {list.isError ? (
        <ErrorState onRetry={() => void list.refetch()} description={errorMessage(i18n, list.error)} />
      ) : (
        <div data-search-anchor="news-list">
          <ResponsiveTable
            caption={t('admin.news.title')}
            columns={columns}
            rows={list.data?.items}
            rowKey={(r) => r.id}
            selectedKeys={selection.selected}
            onSelectionChange={(s) => selection.setAll([...s] as number[], true)}
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
        </div>
      )}

      <NewsBulkBar ids={[...selection.selected]} onClear={selection.clear} />

      <GuardedDialog
        open={toggling !== null}
        onClose={() => setToggling(null)}
        title={t(toggling?.hidden ? 'admin.p05.news.hideTitle' : 'admin.p05.news.showTitle')}
        message={<strong dir="auto">{toggling?.row.title}</strong>}
        consequence={t(
          toggling?.hidden ? 'admin.p05.news.hideConsequence' : 'admin.p05.news.showConsequence',
        )}
        irreversible={false}
        confirmLabel={t(toggling?.hidden ? 'admin.news.hide' : 'admin.news.show')}
        danger={toggling?.hidden}
        requireReason
        reasonMinLength={ADMIN_REASON_MIN}
        invalidateKeys={[qk.news.all]}
        successMessage={t(toggling?.hidden ? 'admin.news.hiddenToast' : 'admin.news.shownToast')}
        onConfirm={({ reason, idempotencyKey }) =>
          newsApi.setNewsHidden(toggling!.row.id, toggling!.hidden, { reason, idempotencyKey })
        }
      />

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

/** Üst özet: üç vurgulu sayı + tür dağılımı çubuğu + tek cümlelik yorum. Süzgeçten bağımsız genel durumdur. */
function NewsOverview({
  news,
  gtx,
  typeLabel,
  fmt,
}: {
  news: NewsSourceStatus;
  gtx: GT;
  typeLabel: (key: string) => string;
  fmt: (n: number) => string;
}) {
  const parts = newsDistribution(news.byType ?? {}, typeLabel);
  const total = news.total ?? 0;
  const week = news.itemsLast7d ?? 0;
  const hidden = news.hidden ?? 0;
  const sentence =
    total === 0
      ? gtx('admin.icerik.news.dist.insightNone')
      : gtx('admin.icerik.news.dist.insight', {
          total: fmt(total),
          parts: distributionText(parts, fmt),
          week: fmt(week),
          hidden: fmt(hidden),
        });
  return (
    <SummaryStrip
      insight={<Insight tone={hidden > 0 ? 'warn' : 'info'} parts={sentence} />}
    >
      <StatTile icon="news" label={gtx('admin.icerik.news.sum.total')} value={total} caption={gtx('admin.icerik.news.sum.totalCap')} />
      <StatTile icon="download" label={gtx('admin.icerik.news.sum.week')} value={week} caption={gtx('admin.icerik.news.sum.weekCap')} />
      <StatTile icon="eyeOff" label={gtx('admin.icerik.news.sum.hidden')} value={hidden} caption={gtx('admin.icerik.news.sum.hiddenCap')} />
      {parts.length > 0 && (
        <div className={styles.dist} data-search-anchor="news-dist" aria-label={gtx('admin.icerik.news.dist.title')} role="group">
          <h2 className={styles.distTitle}>{gtx('admin.icerik.news.dist.title')}</h2>
          <StackedBar parts={parts} ariaLabel={gtx('admin.icerik.news.dist.label')} />
        </div>
      )}
    </SummaryStrip>
  );
}
