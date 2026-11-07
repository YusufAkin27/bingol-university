import { Icon } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './AdminAccessNotice.module.css';

/**
 * Yönetici gerekçeli ve denetimli erişim bildirimi.
 * Mesajların şifreli iletildiği ve saklandığı; yönetici erişiminin yalnızca yazılı gerekçeyle ve değiştirilemez kayıtla yapıldığı söylenir.
 */
export function AdminAccessNotice() {
  const { t } = useI18n();
  return (
    <aside className={styles.box} aria-labelledby="admin-access-title" data-testid="admin-access-notice">
      <span className={styles.icon} aria-hidden="true">
        <Icon name="info" size={20} />
      </span>
      <div className={styles.text}>
        <h2 id="admin-access-title" className={styles.title}>
          {t('legal.adminAccess.title')}
        </h2>
        <p>{t('legal.adminAccess.body1')}</p>
        <p>{t('legal.adminAccess.body2')}</p>
      </div>
    </aside>
  );
}
