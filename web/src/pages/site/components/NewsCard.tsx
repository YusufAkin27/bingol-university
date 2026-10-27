import { useState } from 'react';
import { Link } from 'react-router-dom';
import type { NewsSummary } from '../../../api/publicContent';
import { Badge, Icon } from '../../../components/ui';
import type { TranslationKey } from '../../../i18n';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import { kindTone, safeImageUrl, sourceHost } from './newsUtils';
import styles from './NewsCard.module.css';

/** Görsel varsa gösterir; yüklenemezse (CSP, 404, kaynak sitede kaldırılmış) gradyan + ikon yedeğine döner. */
export function NewsThumb({ src, alt, className }: { src: string | null; alt: string; className?: string }) {
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
          <Icon name="news" size={32} />
        </span>
      )}
    </div>
  );
}

export function NewsMeta({ item }: { item: Pick<NewsSummary, 'type' | 'publishedDate' | 'url'> }) {
  const { t, formatDate } = useI18n();
  const host = sourceHost(item.url);
  return (
    <div className={styles.meta}>
      <Badge tone={kindTone(item.type)}>{t(`pg.news.type.${item.type}` as TranslationKey)}</Badge>
      {item.publishedDate && <time dateTime={item.publishedDate}>{formatDate(item.publishedDate)}</time>}
      {host && (
        <span className={styles.host} dir="ltr">
          {host}
        </span>
      )}
    </div>
  );
}

/** `featured`: büyük, yatay öne çıkan kart. */
export function NewsCard({ item, featured }: { item: NewsSummary; featured?: boolean }) {
  const { t } = useI18n();
  return (
    <article className={`${styles.card} ${featured ? styles.featured : ''}`}>
      <Link to={paths.site.newsItem(item.id)} className={styles.imgLink} tabIndex={-1} aria-hidden="true">
        <NewsThumb src={item.imageUrl} alt="" />
      </Link>
      <div className={styles.body}>
        {featured && <span className={styles.kicker}>{t('pg.news.featured')}</span>}
        <NewsMeta item={item} />
        <h2 className={styles.title}>
          <Link to={paths.site.newsItem(item.id)}>{item.title}</Link>
        </h2>
        {item.summary && <p className={styles.sum}>{item.summary}</p>}
        <Link
          to={paths.site.newsItem(item.id)}
          className={styles.read}
          aria-label={`${t('pg.news.read')}: ${item.title}`}
        >
          {t('pg.news.read')} <Icon name="chevronRight" size={16} />
        </Link>
      </div>
    </article>
  );
}

export function NewsCardSkeleton({ featured }: { featured?: boolean }) {
  return (
    <div className={`${styles.card} ${featured ? styles.featured : ''} ${styles.skel}`} aria-hidden="true">
      <div className={`${styles.thumb} ${styles.skelBlock}`} />
      <div className={styles.body}>
        <span className={`${styles.skelLine} ${styles.skelBlock}`} style={{ width: '40%' }} />
        <span
          className={`${styles.skelLine} ${styles.skelBlock}`}
          style={{ width: '90%', height: '1.3rem' }}
        />
        <span className={`${styles.skelLine} ${styles.skelBlock}`} style={{ width: '75%' }} />
      </div>
    </div>
  );
}
