// SAYFA: Haberler ve duyurular (/news)
// API: GET /api/news?type=HABER|DUYURU|ETKINLIK&q=metin(en az 2 karakter)&page&size (herkese açık, sayfa tabanlı).
// Tür ve arama URL'de (?type=&q=); "Daha fazla yükle" sayfaları birikimli getirir. En yeni kayıt öne çıkan kart olur (aramada olmaz).
// Görseller yalnızca *.bingol.edu.tr'den yüklenir (nginx CSP img-src); yüklenemezse gradyan/ikon yedeği gösterilir.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useSearchParams } from 'react-router-dom';
import { getPublicNews, NEWS_KINDS, type NewsKind } from '../../api/publicContent';
import { Button, EmptyState, ErrorState, SearchInput } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { NewsCard, NewsCardSkeleton } from './components/NewsCard';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './NewsListPage.module.css';

const PAGE_SIZE = 12;
export const MIN_QUERY = 2;

export function parseKind(v: string | null): NewsKind | undefined {
  return NEWS_KINDS.find((k) => k === v);
}

export default function NewsListPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const [params, setParams] = useSearchParams();
  const type = parseKind(params.get('type'));
  const rawQ = (params.get('q') ?? '').trim();
  const q = rawQ.length >= MIN_QUERY ? rawQ : '';
  const title = t('pg.news.title');
  usePageMeta({ title, description: t('pg.news.meta'), path: paths.site.news });

  const query = useInfiniteQuery({
    queryKey: ['public', 'news', 'list', type ?? 'ALL', q],
    queryFn: ({ pageParam }) => getPublicNews({ type, q, page: pageParam, size: PAGE_SIZE }),
    initialPageParam: 0,
    getNextPageParam: (last) => (last.page + 1 < last.totalPages ? last.page + 1 : undefined),
    placeholderData: (prev) => prev,
  });

  const update = (patch: { type?: NewsKind | null; q?: string }) => {
    const next = new URLSearchParams(params);
    if (patch.type !== undefined) {
      if (patch.type) next.set('type', patch.type);
      else next.delete('type');
    }
    if (patch.q !== undefined) {
      if (patch.q) next.set('q', patch.q);
      else next.delete('q');
    }
    setParams(next, { replace: true });
  };

  const items = query.data?.pages.flatMap((p) => p.items) ?? [];
  const total = query.data?.pages[0]?.totalItems ?? 0;
  const searching = q !== '';
  const [first, ...rest] = items;
  const featured = !searching && first ? first : null;
  const grid = featured ? rest : items;

  return (
    <>
      <PageHero title={title} lead={t('pg.news.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          <div className={styles.toolbar}>
            <div role="group" aria-label={t('pg.news.filter')} className={styles.filters}>
              {[undefined, ...NEWS_KINDS].map((k) => (
                <button
                  key={k ?? 'ALL'}
                  type="button"
                  className={`${styles.chip} ${k === type ? styles.chipOn : ''}`}
                  aria-pressed={k === type}
                  onClick={() => update({ type: k ?? null })}
                >
                  {t(`pg.news.type.${k ?? 'ALL'}` as TranslationKey)}
                </button>
              ))}
            </div>
            <div className={styles.search}>
              <SearchInput
                defaultValue={rawQ}
                label={t('pg.news.search')}
                placeholder={t('pg.news.searchPlaceholder')}
                onSearch={(v) => update({ q: v })}
              />
            </div>
          </div>

          {query.isLoading && (
            <div role="status" aria-label={t('common.loading')} className={styles.stack}>
              <NewsCardSkeleton featured />
              <div className={styles.grid}>
                {Array.from({ length: 6 }, (_, i) => (
                  <NewsCardSkeleton key={i} />
                ))}
              </div>
            </div>
          )}
          {query.isError && !query.data && (
            <ErrorState
              title={t('pg.news.error')}
              description={errorMessage(i18n, query.error)}
              onRetry={() => void query.refetch()}
            />
          )}
          {query.data && items.length === 0 && (
            <EmptyState
              icon="news"
              title={searching ? t('pg.news.emptySearch') : t('pg.news.empty')}
              description={searching ? t('pg.news.emptySearchHint') : t('pg.news.emptyHint')}
            />
          )}
          {items.length > 0 && (
            <div className={styles.stack}>
              {searching && (
                <p className={shared.muted} role="status" aria-live="polite">
                  {t('pg.news.resultCount', { count: total })}
                </p>
              )}
              {featured && <NewsCard item={featured} featured />}
              {grid.length > 0 && (
                <div className={styles.grid}>
                  {grid.map((n) => (
                    <NewsCard key={n.id} item={n} />
                  ))}
                </div>
              )}
              {query.isError && (
                <ErrorState
                  compact
                  title={t('pg.news.error')}
                  description={errorMessage(i18n, query.error)}
                  onRetry={() => void query.fetchNextPage()}
                />
              )}
              {query.hasNextPage && (
                <div className={styles.more}>
                  <Button
                    variant="secondary"
                    loading={query.isFetchingNextPage}
                    onClick={() => void query.fetchNextPage()}
                  >
                    {t('common.loadMore')}
                  </Button>
                </div>
              )}
            </div>
          )}
        </div>
      </section>
    </>
  );
}
