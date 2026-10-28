import { Link } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import { useCookieChoice } from '../lib/cookieConsent';
import { paths } from '../paths';
import { Button } from './ui';
import styles from './CookieBanner.module.css';

/** Çerez bilgilendirme bandı: yalnızca zorunlu depolama kullanıldığını söyler, onay istemez; "Anladım" ile kapanır. */
export function CookieBanner() {
  const { t } = useI18n();
  const { acknowledged, acknowledge } = useCookieChoice();
  if (acknowledged) return null;
  return (
    <section className={styles.banner} aria-label={t('pg.cookie.label')}>
      <p className={styles.text}>
        <span className={styles.long}>{t('pg.cookie.text')}</span>
        <span className={styles.short}>{t('pg.cookie.short')}</span>{' '}
        <Link to={paths.site.cookies} className={styles.link}>
          {t('pg.cookie.more')}
        </Link>
      </p>
      <Button size="sm" onClick={acknowledge}>
        {t('pg.cookie.ok')}
      </Button>
    </section>
  );
}
