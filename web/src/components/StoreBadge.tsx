import { useI18n } from '../i18n/I18nProvider';
import { Icon } from './ui/Icon';
import styles from './StoreBadge.module.css';

interface Props {
  store: 'android' | 'ios';
  /** Mağaza bağlantısı; yoksa rozet "Yakında" olarak pasif görünür. */
  href: string | null | undefined;
}

/** Google Play / App Store rozeti (yerel çizim; dış görsel yok). */
export function StoreBadge({ store, href }: Props) {
  const { t } = useI18n();
  const name = store === 'android' ? t('site.store.googlePlay') : t('site.store.appStore');
  const pre = href
    ? store === 'android'
      ? t('site.store.getItOn')
      : t('site.store.downloadOn')
    : t('site.store.soon');
  const inner = (
    <>
      <Icon name={store === 'android' ? 'play' : 'apple'} size={26} className={styles.glyph} />
      <span className={styles.label}>
        <span className={styles.pre}>{pre}</span>
        <span className={styles.name}>{name}</span>
      </span>
    </>
  );
  if (!href) {
    return (
      <span className={`${styles.badge} ${styles.off}`} aria-disabled="true">
        {inner}
      </span>
    );
  }
  return (
    <a
      className={styles.badge}
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`${pre} ${name}`}
    >
      {inner}
    </a>
  );
}
