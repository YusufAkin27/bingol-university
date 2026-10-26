// SAYFA: Çerez Politikası (/cookies)
// API: yok. Yalnızca zorunlu depolama (bu.lang, bu.theme, bu.cookies) kullanıldığı dürüstçe anlatılır; tercih localStorage'da.
import { Button } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { useCookieChoice } from '../../lib/cookieConsent';
import { paths } from '../../paths';
import { InfoPage, type SectionSpec } from './components/InfoPage';
import styles from './components/InfoPage.module.css';

export const COOKIES_SECTIONS: SectionSpec[] = [
  { id: 's1', p: 1 },
  { id: 's2', p: 1, l: 4 },
  { id: 's3', p: 1 },
  { id: 's4', p: 1 },
  { id: 's5', p: 1 },
];

export default function CookiesPage() {
  const { t } = useI18n();
  const { acknowledged, reset, acknowledge } = useCookieChoice();
  return (
    <InfoPage
      slug="cookies"
      path={paths.site.cookies}
      sections={COOKIES_SECTIONS}
      after={{
        s4: (
          <div className={styles.actions}>
            <p role="status">{acknowledged ? t('pg.cookies.status.ack') : t('pg.cookies.status.none')}</p>
            {acknowledged ? (
              <Button variant="secondary" size="sm" onClick={reset}>
                {t('pg.cookies.reset')}
              </Button>
            ) : (
              <Button size="sm" onClick={acknowledge}>
                {t('pg.cookie.ok')}
              </Button>
            )}
          </div>
        ),
      }}
    />
  );
}
