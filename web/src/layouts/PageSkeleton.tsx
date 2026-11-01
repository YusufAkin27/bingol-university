import { Skeleton } from '../components/ui';
import { useI18n } from '../i18n/I18nProvider';
import styles from './ShellExtras.module.css';

/**
 * Sayfa parçası yüklenirken gösterilen iskelet: başlık + gösterge şeridi + içerik kartı. Yükseklikleri SABİTTİR
 * (sayfa gelince içerik zıplamasın: CLS). Ekran okuyucuya tek "yükleniyor" duyurusu verir.
 */
export function PageSkeleton() {
  const { t } = useI18n();
  return (
    <div className={styles.skel} role="status" aria-busy="true" aria-label={t('admin.route.loading')}>
      <Skeleton width="min(16rem, 60%)" height="1.75rem" radius="var(--radius-md)" />
      <div className={styles.skelTiles} aria-hidden="true">
        {[0, 1, 2, 3].map((i) => (
          <Skeleton key={i} height="5.5rem" radius="var(--radius-lg)" />
        ))}
      </div>
      <Skeleton height="18rem" radius="var(--radius-lg)" />
    </div>
  );
}

export default PageSkeleton;
