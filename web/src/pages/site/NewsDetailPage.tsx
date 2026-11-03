// SAYFA: Haber/duyuru/etkinlik detayı (/news/:id)
// API: GET /api/news/{id} (herkese açık; 404 → bulunamadı); GET /api/news?type=<aynı tür>&size=12 (önceki/sonraki ve ilgili içerikler).
// Metin düz metin olarak, HTML enjekte edilmeden. Paylaş: Web Share API, yoksa bağlantıyı kopyalar. Orijinal habere bağlantı korunur.
// Yerleşim: ekmek kırıntısı + başlık kartı (tür/tarih/kaynak, h1, "Kaynağı aç" + paylaş), makale kartı + yan uygulama kartı, önceki/sonraki, ilgili içerikler.
import { useQuery } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { useParams } from 'react-router-dom';
import { Link } from '../../components/LocalizedLink';
import { Breadcrumbs } from '../../components/Breadcrumbs';
import { isApiError } from '../../api/client';
import { useStoreLinks } from '../../api/hooks';
import { getPublicNews, getPublicNewsItem } from '../../api/publicContent';
import { Button, ButtonLink, EmptyState, ErrorState, Icon, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { NewsCard, NewsMeta, NewsThumb } from './components/NewsCard';
import { MaintenanceNotice } from './components/Notices';
import { useHeadingFocus } from './components/PageHero';
import { StoreButton } from './components/StoreButton';
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

/** Yan kart: haberleri uygulamada takip etme çağrısı; mağaza bağlantıları sunucu ayarından gelir. */
function AppAside() {
  const { t } = useI18n();
  const links = useStoreLinks();
  return (
    <aside className={styles.aside} aria-labelledby="news-app">
      <div className={styles.appCard}>
        <span className={styles.appIcon} aria-hidden="true">
          <Icon name="bell" size={22} />
        </span>
        <h2 id="news-app" className={styles.appTitle}>
          {t('site.rd04.appTitle')}
        </h2>
        <p className={styles.appText}>{t('site.rd04.appText')}</p>
        <div className={styles.badges}>
          <StoreButton store="android" href={links.android} onDark note={false} />
          <StoreButton store="ios" href={links.ios} onDark note={false} />
        </div>
      </div>
    </aside>
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
  const h1 = useHeadingFocus<HTMLHeadingElement>();
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
  const heading = notFound ? t('pg.news.notFound') : title;

  return (
    <>
      <section className={styles.top}>
        <div className={`container ${styles.topInner}`}>
          <MaintenanceNotice />
          <Breadcrumbs items={[{ label: list, to: paths.site.news }, { label: heading }]} />
          <div className={styles.titleCard}>
            {q.data && <NewsMeta item={q.data} />}
            <h1 ref={h1} tabIndex={-1} className={styles.h1}>
              {heading}
            </h1>
            {q.data && (
              <div className={styles.actions}>
                {source && (
                  <a href={source} target="_blank" rel="noopener noreferrer" className={styles.srcBtn}>
                    <Icon name="external" size={16} /> {t('site.rd04.sourceOpen')}
                  </a>
                )}
                <ShareButton title={q.data.title} />
              </div>
            )}
          </div>
        </div>
      </section>

      <section className={`${shared.section} ${styles.content}`}>
        <div className={`container ${styles.layout} ${q.data ? styles.withAside : ''}`}>
          <div className={styles.main}>
            {valid && q.isLoading && (
              <div role="status" aria-label={t('common.loading')} className={styles.skel}>
                <Skeleton height="16rem" radius="var(--radius-lg)" />
                {[92, 78, 88, 64].map((w, i) => (
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
          </div>
          {q.data && <AppAside />}
        </div>

        <div className={`container ${styles.below}`}>
          {q.data && nb && nb.related.length > 0 && (
            <section aria-labelledby="news-related" className={styles.related}>
              <div className={styles.relHead}>
                <h2 id="news-related" className={shared.h3}>
                  {t('pg.news.related')}
                </h2>
                <Link to={paths.site.news} className={styles.all}>
                  {t('site.rd04.allNews')} <Icon name="chevronRight" size={16} />
                </Link>
              </div>
              <div className={styles.relGrid}>
                {nb.related.map((n) => (
                  <NewsCard key={n.id} item={n} />
                ))}
              </div>
            </section>
          )}

          {!notFound && !(q.data && nb && nb.related.length > 0) && (
            <p>
              <Link to={paths.site.news} className={styles.back}>
                {t('pg.news.back')}
              </Link>
            </p>
          )}
        </div>
      </section>
    </>
  );
}
