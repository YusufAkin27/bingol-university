// SAYFA: Haberler ve duyurular (/news)
// API: GET /api/news?type=HABER|DUYURU|ETKINLIK&q=metin(en az 2 karakter)&page&size (herkese açık, sayfa tabanlı).
// Tür ve arama URL'de (?type=&q=); "Daha fazla yükle" sayfaları birikimli getirir. En yeni kayıt öne çıkan kart olur (aramada olmaz).
// Görseller yalnızca *.bingol.edu.tr'den yüklenir (nginx CSP img-src); yüklenemezse gradyan/ikon yedeği gösterilir.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { getPublicNews, NEWS_KINDS, type NewsKind } from '../../api/publicContent';
import { Button, EmptyState, ErrorState, Icon, SearchInput } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { AppCallout } from './components/AppCallout';
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
  usePageMeta({ route: 'news' });

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
  const filtered = searching || !!type;
  const [first, ...rest] = items;
  const featured = !searching && first ? first : null;
  const grid = featured ? rest : items;
  // Girdi kontrolsüzdür (debounce); "temizle" yalnızca anahtarı değiştirerek yeniden kurar, yazarken odak kaybolmaz.
  const [searchKey, setSearchKey] = useState(0);
  const clearAll = () => {
    update({ type: null, q: '' });
    setSearchKey((k) => k + 1);
  };
  const typeLabel = type ? t(`pg.news.type.${type}` as TranslationKey) : '';

  return (
    <>
      <PageHero
        eyebrow={t('site.rd04.eyebrow')}
        title={title}
        lead={t('pg.news.lead')}
        crumbs={[{ label: title }]}
      />
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
                key={searchKey}
                defaultValue={rawQ}
                label={t('pg.news.search')}
                placeholder={t('pg.news.searchPlaceholder')}
                onSearch={(v) => update({ q: v })}
              />
            </div>
          </div>

          {filtered && (
            <div className={styles.active} role="group" aria-label={t('site.rd04.activeFilters')}>
              <span className={styles.activeLabel}>{t('site.rd04.activeFilters')}</span>
              {type && (
                <button
                  type="button"
                  className={styles.pill}
                  aria-label={t('site.rd04.filterRemove', { label: typeLabel })}
                  onClick={() => update({ type: null })}
                >
                  {t('site.rd04.filterType')}: {typeLabel} <Icon name="x" size={14} />
                </button>
              )}
              {searching && (
                <button
                  type="button"
                  className={styles.pill}
                  aria-label={t('site.rd04.filterRemove', { label: q })}
                  onClick={() => {
                    update({ q: '' });
                    setSearchKey((k) => k + 1);
                  }}
                >
                  {t('site.rd04.filterQuery')}: “{q}” <Icon name="x" size={14} />
                </button>
              )}
            </div>
          )}

          <div className={styles.results}>
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
              <div className={styles.stateBox}>
                <ErrorState
                  title={t('pg.news.error')}
                  description={errorMessage(i18n, query.error)}
                  onRetry={() => void query.refetch()}
                />
              </div>
            )}
            {query.data && items.length === 0 && (
              <div className={styles.stateBox}>
                <EmptyState
                  icon="news"
                  title={searching ? t('pg.news.emptySearch') : t('pg.news.empty')}
                  description={searching ? t('pg.news.emptySearchHint') : t('pg.news.emptyHint')}
                  action={
                    filtered ? (
                      <Button
                        variant="primary"
                        leftIcon={<Icon name="filter" size={16} />}
                        onClick={clearAll}
                      >
                        {t('site.rd04.clearFilters')}
                      </Button>
                    ) : undefined
                  }
                />
              </div>
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
                <div className={styles.more}>
                  <p className={styles.shown} role="status" aria-live="polite">
                    {t('site.rd04.shown', { shown: items.length, total })}
                  </p>
                  {query.hasNextPage && (
                    <Button
                      variant="secondary"
                      loading={query.isFetchingNextPage}
                      onClick={() => void query.fetchNextPage()}
                    >
                      {t('common.loadMore')}
                    </Button>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      </section>
      <AppCallout
        shot="home"
        title={t('site.s2.news.appTitle')}
        text={t('site.s2.news.appText')}
        crop={0.8}
      />
    </>
  );
}
