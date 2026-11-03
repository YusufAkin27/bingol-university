import { useState } from 'react';
import { Link } from './LocalizedLink';
import { CookiePrefs } from './CookiePrefsLazy';
import { useI18n } from '../i18n/I18nProvider';
import { useCookieChoice } from '../lib/cookieConsent';
import { paths } from '../paths';
import { Button, Icon } from './ui';
import styles from './CookieBanner.module.css';

/**
 * Çerez bilgilendirme bandı: yalnızca zorunlu depolama kullanıldığını söyler, onay istemez; "Anladım" ile kapanır.
 * "Tercihler" dil/tema hatırlamayı kapatabileceğiniz küçük bir pencere açar. Analiz/reklam/izleme yoktur.
 */
export function CookieBanner() {
  const { t } = useI18n();
  const { acknowledged, acknowledge } = useCookieChoice();
  const [prefsOpen, setPrefsOpen] = useState(false);
  return (
    <>
      {!acknowledged && (
        <section className={styles.banner} aria-label={t('pg.cookie.label')}>
          <span className={styles.icon} aria-hidden="true">
            <Icon name="shield" size={22} />
          </span>
          <div className={styles.copy}>
            <p className={styles.title}>{t('site.rd10.cookie.title')}</p>
            <p className={styles.text}>
              <span className={styles.long}>{t('pg.cookie.text')}</span>
              <span className={styles.short}>{t('pg.cookie.short')}</span>{' '}
              <Link to={paths.site.cookies} className={styles.link}>
                {t('pg.cookie.more')}
              </Link>
            </p>
          </div>
          <div className={styles.actions}>
            <Button variant="ghost" size="md" onClick={() => setPrefsOpen(true)}>
              {t('site.rd10.cookie.prefs')}
            </Button>
            <Button size="md" onClick={acknowledge}>
              {t('pg.cookie.ok')}
            </Button>
          </div>
        </section>
      )}
      <CookiePrefs open={prefsOpen} onClose={() => setPrefsOpen(false)} />
    </>
  );
}
