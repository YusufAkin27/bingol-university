import { useNavigate } from 'react-router-dom';
import { paths } from '../paths';
import { useAuth } from './AuthProvider';
import { useI18n } from '../i18n/I18nProvider';
import { Button } from '../components/ui/Button';
import { Icon } from '../components/ui/Icon';
import styles from './ForbiddenScreen.module.css';

/** ADMIN olmayan kullanıcı giriş yaptığında gösterilir. */
export function ForbiddenScreen() {
  const { t } = useI18n();
  const { logout } = useAuth();
  const navigate = useNavigate();
  return (
    <main className={styles.wrap} role="alert">
      <div className={styles.card}>
        <span className={styles.icon} aria-hidden="true">
          <Icon name="shield" size={28} />
        </span>
        <h1 className={styles.title}>{t('admin.forbidden.title')}</h1>
        <p className={styles.hint}>{t('admin.forbidden.hint')}</p>
        <Button
          onClick={async () => {
            await logout();
            navigate(paths.admin.login, { replace: true });
          }}
        >
          {t('admin.forbidden.logout')}
        </Button>
      </div>
    </main>
  );
}
