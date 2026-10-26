// SAYFA: Haber/duyuru/etkinlik detayı (/news/:id)
// API: GET /api/news/{id} (herkese açık; 404 → bulunamadı); GET /api/news?type=<aynı tür>&size=12 (önceki/sonraki ve ilgili içerikler).
// Metin düz metin olarak, HTML enjekte edilmeden. Paylaş: Web Share API, yoksa bağlantıyı kopyalar. Orijinal habere bağlantı korunur.
import { useQuery } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { isApiError } from '../../api/client';
import { getPublicNews, getPublicNewsItem } from '../../api/publicContent';
import { Button, ButtonLink, EmptyState, ErrorState, Icon, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { NewsCard, NewsMeta, NewsThumb } from './components/NewsCard';
import { PageHero } from './components/PageHero';
import { safeImageUrl, safeSourceUrl, sourceHost } from './components/newsUtils';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './NewsDetailPage.module.css';

export { safeSourceUrl };

/** Mevcut kaydın liste içindeki komşuları ve (kendisi hariç) ilgili kayıtlar. Liste yeniden eskiye sıralıdır. */
export function neighbours<T extends { id: number }>(list: T[], id: number) {
  const i = list.findIndex((x) => x.id === id);
  return {
    newer: i > 0 ? list[i - 1] : null,
    older: i >= 0 && i < list.length - 1 ? list[i + 1] : null,
    related: list.filter((x) => x.id !== id).slice(0, 3),
  };
}

function ShareButton({ title }: { title: string }) {
  const { t } = useI18n();
  const [copied, setCopied] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout>>();
  useEffect(() => () => clearTimeout(timer.current), []);

  async function share() {
    const url = window.location.href;
    if (typeof navigator.share === 'function') {
      try {
        await navigator.share({ title, url });
        return;
      } catch (e) {
        if ((e as Error)?.name === 'AbortError') return; // kullanıcı vazgeçti
      }
    }
    try {
      await navigator.clipboard.writeText(url);
    } catch {
      const ta = document.createElement('textarea');
      ta.value = url;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      try {
        document.execCommand('copy');
      } catch {
        /* sessizce geç */
      }
      ta.remove();
    }
    setCopied(true);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => setCopied(false), 2200);
  }

  return (
    <>
      <Button
        variant="secondary"
        size="sm"
        leftIcon={<Icon name={copied ? 'check' : 'arrowUp'} size={16} />}
        onClick={() => void share()}
      >
        {copied ? t('pg.news.linkCopied') : t('pg.news.share')}
      </Button>
      <span className="sr-only" role="status" aria-live="polite">
        {copied ? t('pg.news.linkCopied') : ''}
      </span>
    </>
  );
}

export default function NewsDetailPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const { id } = useParams();
  const valid = !!id && /^\d+$/.test(id);
  const q = useQuery({
    queryKey: ['public', 'news-item', id],
    queryFn: () => getPublicNewsItem(id!),
    enabled: valid,
  });
  const kind = q.data?.type;
  const more = useQuery({
    queryKey: ['public', 'news', 'related', kind],
    queryFn: () => getPublicNews({ type: kind, size: 12 }),
    enabled: !!kind,
    staleTime: 60_000,
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
  const host = sourceHost(q.data?.url ?? null);
  const hero = safeImageUrl(q.data?.imageUrl ?? null);
  const paras = (q.data?.content ?? '').split(/\n+/).filter((p) => p.trim());
  const nb = q.data ? neighbours(more.data?.items ?? [], q.data.id) : null;

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
              <Skeleton height="14rem" radius="var(--radius-lg)" />
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
              <div className={styles.head}>
                <NewsMeta item={q.data} />
                <div className={styles.actions}>
                  <ShareButton title={q.data.title} />
                </div>
              </div>
              {hero && (
                <NewsThumb src={q.data.imageUrl} alt={t('pg.news.untitledImage')} className={styles.hero} />
              )}
              <div className={styles.prose}>
                {paras.length > 0 ? (
                  paras.map((p, i) => <p key={i}>{p}</p>)
                ) : (
                  <p className={shared.muted}>{t('pg.news.noContent')}</p>
                )}
              </div>
              {source && (
                <p className={styles.originalRow}>
                  <a href={source} target="_blank" rel="noopener noreferrer" className={styles.orig}>
                    {t('pg.news.original')} <Icon name="external" size={16} />
                  </a>
                  {host && (
                    <span className={styles.srcHost} dir="ltr">
                      {host}
                    </span>
                  )}
                </p>
              )}
            </article>
          )}

          {q.data && nb && (nb.newer || nb.older) && (
            <nav className={styles.pager} aria-label={t('pg.news.prevNext')}>
              {nb.older ? (
                <Link to={paths.site.newsItem(nb.older.id)} rel="prev" className={styles.pagerLink}>
                  <span className={styles.pagerLabel}>{t('pg.news.prev')}</span>
                  <span className={styles.pagerTitle}>{nb.older.title}</span>
                </Link>
              ) : (
                <span />
              )}
              {nb.newer ? (
                <Link
                  to={paths.site.newsItem(nb.newer.id)}
                  rel="next"
                  className={`${styles.pagerLink} ${styles.pagerEnd}`}
                >
                  <span className={styles.pagerLabel}>{t('pg.news.next')}</span>
                  <span className={styles.pagerTitle}>{nb.newer.title}</span>
                </Link>
              ) : (
                <span />
              )}
            </nav>
          )}

          {q.data && nb && nb.related.length > 0 && (
            <section aria-labelledby="news-related" className={styles.related}>
              <h2 id="news-related" className={shared.h3}>
                {t('pg.news.related')}
              </h2>
              <div className={styles.relGrid}>
                {nb.related.map((n) => (
                  <NewsCard key={n.id} item={n} />
                ))}
              </div>
            </section>
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
