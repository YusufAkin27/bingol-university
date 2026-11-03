import { useI18n } from '../i18n/I18nProvider';
import styles from './PageSkeleton.module.css';

/**
 * Sayfa yüklenirken (lazy parça) gösterilen iskelet: başlık, üç kart, liste. Üst bilgi ve alt bilgi yerinde kalır.
 * Ekran okuyucu için tek `status` duyurusu; hareket `prefers-reduced-motion` altında durur.
 */
export function PageSkeleton() {
  const { t } = useI18n();
  return (
    <div className={`container ${styles.wrap}`} role="status" aria-busy="true">
      <span className="sr-only">{t('site.rd10.loading.label')}</span>
      <div className={styles.head} aria-hidden="true">
        <span className={`${styles.bar} ${styles.title}`} />
        <span className={`${styles.bar} ${styles.sub}`} />
      </div>
      <div className={styles.cards} aria-hidden="true">
        {[0, 1, 2].map((i) => (
          <div key={i} className={styles.card}>
            <span className={`${styles.bar} ${styles.media}`} />
            <span className={`${styles.bar} ${styles.line}`} />
            <span className={`${styles.bar} ${styles.lineShort}`} />
          </div>
        ))}
      </div>
      <div className={styles.list} aria-hidden="true">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className={styles.row}>
            <span className={`${styles.bar} ${styles.dot}`} />
            <span className={styles.rowText}>
              <span className={`${styles.bar} ${styles.line}`} />
              <span className={`${styles.bar} ${styles.lineShort}`} />
            </span>
            <span className={`${styles.bar} ${styles.pill}`} />
          </div>
        ))}
      </div>
    </div>
  );
}
