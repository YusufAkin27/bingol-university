import { useId } from 'react';
import { Icon } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './StoreButton.module.css';

interface Props {
  store: 'android' | 'ios';
  /** Mağaza bağlantısı; yoksa düğme "Yakında" durumunda ve devre dışıdır. */
  href: string | null | undefined;
  /** Koyu zemin (lacivert bölüm) üzerinde kullanım. */
  onDark?: boolean;
}

/** Kendi çizdiğimiz mağaza düğmesi (resmî rozet görseli kullanılmaz). */
export function StoreButton({ store, href, onDark }: Props) {
  const { t } = useI18n();
  const noteId = useId();
  const main = store === 'android' ? t('site.store.playMain') : t('site.store.appleMain');
  const top = href
    ? store === 'android'
      ? t('site.store.playTop')
      : t('site.store.appleTop')
    : t('site.store.soon');
  const body = (
    <>
      <Icon name={store === 'android' ? 'play' : 'apple'} size={28} className={styles.glyph} />
      <span className={styles.label}>
        <span className={styles.top}>{top}</span>
        <span className={styles.main}>{main}</span>
      </span>
    </>
  );
  const cls = `${styles.btn} ${onDark ? styles.onDark : ''}`;
  if (!href) {
    return (
      <span className={styles.wrap}>
        <button type="button" className={`${cls} ${styles.soon}`} aria-disabled="true" aria-describedby={noteId}>
          {body}
        </button>
        <span id={noteId} className={styles.note}>
          {t('site.store.soonNote')}
        </span>
      </span>
    );
  }
  return (
    <span className={styles.wrap}>
      <a className={cls} href={href} target="_blank" rel="noopener noreferrer" aria-describedby={noteId}>
        {body}
      </a>
      <span id={noteId} className="sr-only">
        {t('site.store.newTab')}
      </span>
    </span>
  );
}
