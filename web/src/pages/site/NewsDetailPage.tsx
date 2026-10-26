// SAYFA: Haber/duyuru/etkinlik detayı (/news/:id)
// API: GET /api/news/{id} (herkese açık; 404 → bulunamadı). Kaynak atfı + orijinal bağlantı. Metin düz metin olarak, HTML enjekte edilmeden.
import { useQuery } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { isApiError } from '../../api/client';
import { getPublicNewsItem } from '../../api/publicContent';
import { Badge, ButtonLink, EmptyState, ErrorState, Icon, Skeleton } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './NewsDetailPage.module.css';

/** Yalnızca http(s) bağlantıları açılır; kaynak http ise https'e çevrilir. */
export function safeSourceUrl(url: string | null): string | null {
  if (!url) return null;
  if (!/^https?:\/\//i.test(url)) return null;
  return url.replace(/^http:\/\//i, 'https://');
}

export default function NewsDetailPage() {
  const i18n = useI18n();
  const { t, formatDate } = i18n;
  const { id } = useParams();
  const valid = !!id && /^\d+$/.test(id);
  const q = useQuery({
    queryKey: ['public', 'news-item', id],
    queryFn: () => getPublicNewsItem(id!),
    enabled: valid,
  });
  const list = t('pg.news.title');
  const title = q.data?.title ?? list;
  const notFound = !valid || (q.isError && isApiError(q.error) && q.error.status === 404);
  usePageMeta({
    title,
    description: q.data?.content?.slice(0, 160) || t('pg.news.meta'),
    path: valid ? paths.site.newsItem(id!) : paths.site.news,
    noindex: notFound,
  });
  const source = safeSourceUrl(q.data?.url ?? null);
  const paras = (q.data?.content ?? '').split(/\n+/).filter((p) => p.trim());

  return (
    <>
      <PageHero
        title={notFound ? t('pg.news.notFound') : title}
        crumbs={[{ label: list, to: paths.site.news }, { label: notFound ? t('pg.news.notFound') : title }]}
      />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          {valid && q.isLoading && (
            <div role="status" aria-label={t('common.loading')} className={styles.skel}>
              {[90, 70, 85, 60].map((w, i) => (
                <Skeleton key={i} height="1.1rem" width={`${w}%`} />
              ))}
            </div>
          )}
          {notFound && (
            <EmptyState
              icon="news"
              title={t('pg.news.notFound')}
              description={t('pg.news.notFoundHint')}
              action={<ButtonLink to={paths.site.news}>{t('pg.news.back')}</ButtonLink>}
            />
          )}
          {q.isError && !notFound && (
            <ErrorState
              title={t('pg.news.error')}
              description={errorMessage(i18n, q.error)}
              onRetry={() => void q.refetch()}
            />
          )}
          {q.data && (
            <article className={styles.article}>
              <div className={styles.meta}>
                <Badge tone={q.data.type === 'DUYURU' ? 'warning' : q.data.type === 'ETKINLIK' ? 'info' : 'primary'}>
                  {t(`pg.news.type.${q.data.type}` as TranslationKey)}
                </Badge>
                {q.data.publishedDate && (
                  <time dateTime={q.data.publishedDate}>{formatDate(q.data.publishedDate)}</time>
                )}
                <span>{t('pg.news.source')}</span>
              </div>
              {paras.length > 0 ? (
                paras.map((p, i) => <p key={i}>{p}</p>)
              ) : (
                <p className={shared.muted}>{t('pg.news.noContent')}</p>
              )}
              {source && (
                <p>
                  <a href={source} target="_blank" rel="noopener noreferrer" className={styles.orig}>
                    {t('pg.news.original')} <Icon name="external" size={16} />
                  </a>
                </p>
              )}
              <p className={shared.muted}>{t('pg.news.attribution')}</p>
            </article>
          )}
          {!notFound && (
            <p>
              <Link to={paths.site.news}>{t('pg.news.back')}</Link>
            </p>
          )}
        </div>
      </section>
    </>
  );
}
