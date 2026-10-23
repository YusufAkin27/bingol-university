import { useAppInfo } from '../../../api/hooks';
import { Icon } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './PageHero.module.css';

/** Bakım modu açıksa görünür uyarı (banner SiteLayout'ta gösterilir). */
export function MaintenanceNotice() {
  const { t } = useI18n();
  const info = useAppInfo();
  const m = info.data?.maintenance;
  if (!m?.enabled) return null;
  return (
    <div className={styles.maintenance} role="status">
      <Icon name="alert" size={18} />
      <span>
        <strong>{t('site.maintenance.title')}</strong>
        {m.message ? `: ${m.message}` : ''}
      </span>
    </div>
  );
}
