import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminUnitNewsApi, qk } from '../../../api';
import { useCan } from '../../../auth/permissions';
import type { UnitAnnouncementRow, UnitSource } from '../../../api/adminUnitNews';
import {
  Badge,
  DataToolbar,
  EmptyState,
  ErrorState,
  Icon,
  Pagination,
  Select,
  Switch,
  Table,
  useToast,
  type Column,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import { gt } from './dict';
import styles from './unitNews.module.css';

const PAGE_SIZE = 20;

/** Yalnız https/http bağlantıları dış bağlantı olarak çizilir (sunucu zaten https verir; savunma amaçlı). */
function safeHref(url: string): string | undefined {
  return /^https?:\/\//i.test(url) ? url : undefined;
}

export function AnnouncementsSection({ sources }: { sources: UnitSource[] | undefined }) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatDate } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const canWrite = useCan('content.write');

  const [q, setQ] = useState('');
  const [source, setSource] = useState('');
  const [vis, setVis] = useState<'' | 'visible' | 'hidden'>('');
  const [page, setPage] = useState(0);

  const params = {
    source: source || undefined,
    q: q || undefined,
    hidden: vis === '' ? undefined : vis === 'hidden',
    page,
    size: PAGE_SIZE,
  };
  const list = useQuery({
    queryKey: qk.unitNews.announcements(params),
    queryFn: () => adminUnitNewsApi.listAnnouncements(params),
    placeholderData: (p) => p,
  });

  const setHidden = useMutation({
    mutationFn: (v: { row: UnitAnnouncementRow; hidden: boolean }) =>
      adminUnitNewsApi.setAnnouncementHidden(v.row.id, v.hidden),
    onSuccess: (_d, v) => {
      toast.success(t(v.hidden ? 'admin.unitNews.list.hiddenToast' : 'admin.unitNews.list.shownToast'));
      void qc.invalidateQueries({ queryKey: qk.unitNews.all });
    },
    onError: (e) => toast.error(errorMessage(i18n, e)),
  });

  const columns: Column<UnitAnnouncementRow>[] = [
    {
      key: 'title',
      header: t('admin.unitNews.list.col.title'),
      render: (r) => {
        const href = safeHref(r.url);
        return (
          <span className={styles.title}>
            {href ? (
              <a
                href={href}
                target="_blank"
                rel="noopener noreferrer"
                dir="auto"
                className={r.hidden ? styles.dim : undefined}
                aria-label={`${r.title} (${t('admin.unitNews.list.openSource')})`}
              >
                {r.title}
                <Icon name="external" size={14} />
              </a>
            ) : (
              <span dir="auto" className={r.hidden ? styles.dim : undefined}>
                {r.title}
              </span>
            )}
            {r.hidden && <Badge tone="danger">{t('admin.unitNews.list.hiddenBadge')}</Badge>}
          </span>
        );
      },
    },
    {
      key: 'source',
      header: t('admin.unitNews.list.col.source'),
      render: (r) => (
        <span className={styles.name}>
          <span dir="auto">{r.sourceName}</span>
          {r.unitName && (
            <span className={styles.muted} dir="auto">
              {r.unitName}
            </span>
          )}
        </span>
      ),
    },
    { key: 'date', header: t('admin.unitNews.list.col.date'), render: (r) => formatDate(r.publishedDate) },
    {
      key: 'attachments',
      header: t('admin.unitNews.list.col.attachments'),
      align: 'end',
      render: (r) => <span className={styles.num}>{r.attachmentCount}</span>,
    },
    {
      key: 'visible',
      header: t('admin.unitNews.list.col.visible'),
      render: (r) => (
        <Switch
          checked={!r.hidden}
          label={<span className="sr-only">{t('admin.unitNews.list.toggle', { title: r.title })}</span>}
          disabled={!canWrite || (setHidden.isPending && setHidden.variables?.row.id === r.id)}
          onChange={(visible) => setHidden.mutate({ row: r, hidden: !visible })}
        />
      ),
    },
  ];

  return (
    <section aria-labelledby="unit-news-list-h">
      <h2 id="unit-news-list-h" className="sr-only">
        {t('admin.unitNews.list.title')}
      </h2>
      <DataToolbar
        onSearch={(v) => {
          setQ(v);
          setPage(0);
        }}
        searchPlaceholder={t('admin.unitNews.list.search')}
        filters={
          <div className={styles.filterRow}>
            <Select
              className={styles.filter}
              aria-label={t('admin.unitNews.list.sourceFilter')}
              value={source}
              onChange={(e) => {
                setSource(e.target.value);
                setPage(0);
              }}
            >
              <option value="">{t('admin.unitNews.list.allSources')}</option>
              {(sources ?? []).map((s) => (
                <option key={s.code} value={s.code}>
                  {s.name}
                </option>
              ))}
            </Select>
            <Select
              className={styles.filter}
              aria-label={t('admin.unitNews.list.visibilityFilter')}
              value={vis}
              onChange={(e) => {
                setVis(e.target.value as '' | 'visible' | 'hidden');
                setPage(0);
              }}
            >
              <option value="">{t('admin.unitNews.list.all')}</option>
              <option value="visible">{t('admin.unitNews.list.visible')}</option>
              <option value="hidden">{t('admin.unitNews.list.hidden')}</option>
            </Select>
          </div>
        }
      />
      {list.isError ? (
        <ErrorState onRetry={() => void list.refetch()} description={errorMessage(i18n, list.error)} />
      ) : (
        <>
          <Table
            caption={t('admin.unitNews.list.title')}
            columns={columns}
            rows={list.data?.content}
            rowKey={(r) => r.id}
            loading={list.isLoading}
            empty={
              <EmptyState
                compact
                icon="news"
                title={t('admin.unitNews.list.empty.title')}
                description={t('admin.unitNews.list.empty.hint')}
              />
            }
          />
          {list.data && (
            <Pagination
              page={list.data.number}
              totalPages={list.data.totalPages}
              totalItems={list.data.totalElements}
              onPageChange={setPage}
            />
          )}
        </>
      )}
    </section>
  );
}
