import { useI18n } from '../../../i18n/I18nProvider';
import shared from './site.module.css';
import styles from './AdminAccessNotice.module.css';

/**
 * Yönetici gerekçeli ve denetimli erişim bildirimi.
 * Mesajların şifreli iletildiği ve saklandığı; yönetici erişiminin yalnızca yazılı gerekçeyle ve değiştirilemez kayıtla yapıldığı söylenir.
 */
export function AdminAccessNotice() {
  const { t } = useI18n();
  return (
    <aside className={styles.box} aria-labelledby="admin-access-title" data-testid="admin-access-notice">
      <h2 id="admin-access-title" className={shared.h3}>
        {t('legal.adminAccess.title')}
      </h2>
      <p>{t('legal.adminAccess.body1')}</p>
      <p>{t('legal.adminAccess.body2')}</p>
    </aside>
  );
}
