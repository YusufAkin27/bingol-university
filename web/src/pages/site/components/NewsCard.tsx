import { useState, type ReactNode } from 'react';
import { Link } from '../../../components/LocalizedLink';
import type { NewsSummary } from '../../../api/publicContent';
import { Badge, ButtonLink, ContourBackdrop, Icon } from '../../../components/ui';
import type { TranslationKey } from '../../../i18n';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import { kindTone, safeImageUrl, safeSourceUrl, sourceHost } from './newsUtils';
import styles from './NewsCard.module.css';

/**
 * Haber görseli (API'den; yalnız bingol.edu.tr). Yüklenemezse (CSP, 404, kaynak sitede kaldırılmış) dağ kontur dokulu
 * yedek yüzey gösterilir. `badge` görselin üst köşesine biner (tür rozeti).
 */
export function NewsThumb({
  src,
  alt,
  className,
  badge,
}: {
  src: string | null;
  alt: string;
  className?: string;
  badge?: ReactNode;
}) {
  const safe = safeImageUrl(src);
  const [failed, setFailed] = useState(false);
  const show = safe && !failed;
  return (
    <div className={`${styles.thumb} ${className ?? ''}`} data-fallback={show ? undefined : 'true'}>
      {show ? (
        <img
          src={safe}
          alt={alt}
          loading="lazy"
          decoding="async"
          referrerPolicy="no-referrer"
          onError={() => setFailed(true)}
        />
      ) : (
        <span className={styles.fallback} aria-hidden="true">
          <ContourBackdrop className={styles.contour} />
          <span className={styles.fallbackIcon}>
            <Icon name="news" size={28} />
          </span>
        </span>
      )}
      {badge && <span className={styles.badge}>{badge}</span>}
    </div>
  );
}

export function KindBadge({ kind }: { kind: NewsSummary['type'] }) {
  const { t } = useI18n();
  return <Badge tone={kindTone(kind)}>{t(`pg.news.type.${kind}` as TranslationKey)}</Badge>;
}

/** Detay başlığı için tür + tarih + kaynak alan adı satırı. */
export function NewsMeta({ item }: { item: Pick<NewsSummary, 'type' | 'publishedDate' | 'url'> }) {
  const { formatDate } = useI18n();
  const host = sourceHost(item.url);
  return (
    <div className={styles.meta}>
      <KindBadge kind={item.type} />
      {item.publishedDate && <time dateTime={item.publishedDate}>{formatDate(item.publishedDate)}</time>}
      {host && (
        <span className={styles.host} dir="ltr">
          {host}
        </span>
      )}
    </div>
  );
}

/** `featured`: büyük, yatay öne çıkan kart (okuma + kaynak düğmeleri). Başlık bağlantısı kartın tamamını tıklanabilir yapar. */
export function NewsCard({ item, featured }: { item: NewsSummary; featured?: boolean }) {
  const { t, formatDate } = useI18n();
  const host = sourceHost(item.url);
  const source = safeSourceUrl(item.url);
  const to = paths.site.newsItem(item.id);
  return (
    <article className={`${styles.card} ${featured ? styles.featured : ''}`}>
      <Link to={to} className={styles.imgLink} tabIndex={-1} aria-hidden="true">
        <NewsThumb
          src={item.imageUrl}
          alt=""
          badge={
            featured ? (
              <span className={styles.kicker}>
                <Icon name="star" size={14} /> {t('pg.news.featured')}
              </span>
            ) : (
              <KindBadge kind={item.type} />
            )
          }
        />
      </Link>
      <div className={styles.body}>
        <div className={styles.meta}>
          {featured ? (
            <KindBadge kind={item.type} />
          ) : (
            <span className="sr-only">{t(`pg.news.type.${item.type}` as TranslationKey)}</span>
          )}
          {item.publishedDate && <time dateTime={item.publishedDate}>{formatDate(item.publishedDate)}</time>}
          {host && (
            <span className={styles.host} dir="ltr">
              {host}
            </span>
          )}
        </div>
        <h2 className={styles.title}>
          <Link to={to}>{item.title}</Link>
        </h2>
        {item.summary && <p className={styles.sum}>{item.summary}</p>}
        <div className={styles.foot}>
          {featured ? (
            <>
              <ButtonLink to={to} className={styles.lift} aria-label={`${t('pg.news.read')}: ${item.title}`}>
                {t('pg.news.read')} <Icon name="chevronRight" size={16} />
              </ButtonLink>
              {source && (
                <a
                  href={source}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={`${styles.srcBtn} ${styles.lift}`}
                >
                  <Icon name="external" size={16} /> {t('site.rd04.sourceOpen')}
                </a>
              )}
            </>
          ) : (
            <span className={styles.read} aria-hidden="true">
              {t('pg.news.read')} <Icon name="chevronRight" size={16} />
            </span>
          )}
        </div>
      </div>
    </article>
  );
}

export function NewsCardSkeleton({ featured }: { featured?: boolean }) {
  return (
    <div className={`${styles.card} ${featured ? styles.featured : ''} ${styles.skel}`} aria-hidden="true">
      <div className={`${styles.thumb} ${styles.skelBlock}`} />
      <div className={styles.body}>
        <span className={`${styles.skelLine} ${styles.skelBlock}`} style={{ width: '45%' }} />
        <span
          className={`${styles.skelLine} ${styles.skelBlock}`}
          style={{ width: '92%', height: '1.3rem' }}
        />
        <span
          className={`${styles.skelLine} ${styles.skelBlock}`}
          style={{ width: '70%', height: '1.3rem' }}
        />
        <span className={`${styles.skelLine} ${styles.skelBlock}`} style={{ width: '88%' }} />
        <span className={`${styles.skelLine} ${styles.skelBlock}`} style={{ width: '60%' }} />
        <span className={`${styles.skelPill} ${styles.skelBlock}`} />
      </div>
    </div>
  );
}
