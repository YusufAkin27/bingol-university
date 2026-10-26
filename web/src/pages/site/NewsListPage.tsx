// SAYFA: Haberler ve duyurular (/news)
// API: GET /api/news?type=HABER|DUYURU|ETKINLIK&page&size (herkese açık, sayfa tabanlı). Tür ve sayfa URL'de (?type=&page=).
// Not: CSP img-src yalnızca 'self' olduğundan kaynak sitedeki görseller gösterilmez; metin + orijinal bağlantı sunulur.
import { useQuery } from '@tanstack/react-query';
import { Link, useSearchParams } from 'react-router-dom';
import { getPublicNews, NEWS_KINDS, type NewsKind } from '../../api/publicContent';
import { Badge, EmptyState, ErrorState, Pagination, Skeleton } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './NewsListPage.module.css';

const PAGE_SIZE = 12;

export function parseKind(v: string | null): NewsKind | undefined {
  return NEWS_KINDS.find((k) => k === v);
}

export default function NewsListPage() {
  const i18n = useI18n();
  const { t, formatDate } = i18n;
  const [params, setParams] = useSearchParams();
  const type = parseKind(params.get('type'));
  const page = Math.max(0, Number(params.get('page')) || 0);
  const title = t('pg.news.title');
  usePageMeta({ title, description: t('pg.news.meta'), path: paths.site.news });

  const q = useQuery({
    queryKey: ['public', 'news', type ?? 'ALL', page],
    queryFn: () => getPublicNews({ type, page, size: PAGE_SIZE }),
    placeholderData: (prev) => prev,
  });

  const setType = (k: NewsKind | undefined) => {
    const next = new URLSearchParams();
    if (k) next.set('type', k);
    setParams(next, { replace: true });
  };
  const setPage = (p: number) => {
    const next = new URLSearchParams(params);
    if (p > 0) next.set('page', String(p));
    else next.delete('page');
    setParams(next);
    window.scrollTo?.({ top: 0 });
  };

  return (
    <>
      <PageHero title={title} lead={t('pg.news.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          <div role="group" aria-label={t('pg.news.filter')} className={styles.filters}>
            {[undefined, ...NEWS_KINDS].map((k) => (
              <button
                key={k ?? 'ALL'}
                type="button"
                className={`${styles.chip} ${k === type ? styles.chipOn : ''}`}
                aria-pressed={k === type}
                onClick={() => setType(k)}
              >
                {t(`pg.news.type.${k ?? 'ALL'}` as TranslationKey)}
              </button>
            ))}
          </div>

          {q.isLoading && (
            <div role="status" aria-label={t('common.loading')} className={styles.list}>
              {Array.from({ length: 6 }, (_, i) => (
                <Skeleton key={i} height="5.5rem" />
              ))}
            </div>
          )}
          {q.isError && (
            <ErrorState
              title={t('pg.news.error')}
              description={errorMessage(i18n, q.error)}
              onRetry={() => void q.refetch()}
            />
          )}
          {q.data && q.data.items.length === 0 && (
            <EmptyState icon="news" title={t('pg.news.empty')} description={t('pg.news.emptyHint')} />
          )}
          {q.data && q.data.items.length > 0 && (
            <>
              <ul className={styles.list}>
                {q.data.items.map((n) => (
                  <li key={n.id} className={styles.item}>
                    <div className={styles.meta}>
                      <Badge tone={n.type === 'DUYURU' ? 'warning' : n.type === 'ETKINLIK' ? 'info' : 'primary'}>
                        {t(`pg.news.type.${n.type}` as TranslationKey)}
                      </Badge>
                      {n.publishedDate && <time dateTime={n.publishedDate}>{formatDate(n.publishedDate)}</time>}
                    </div>
                    <h2 className={styles.h}>
                      <Link to={paths.site.newsItem(n.id)}>{n.title}</Link>
                    </h2>
                    {n.summary && <p className={styles.sum}>{n.summary}</p>}
                  </li>
                ))}
              </ul>
              <Pagination
                page={q.data.page}
                totalPages={q.data.totalPages}
                totalItems={q.data.totalItems}
                onPageChange={setPage}
              />
            </>
          )}
          <p className={shared.muted}>{t('pg.news.attribution')}</p>
        </div>
      </section>
    </>
  );
}
