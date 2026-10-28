// SAYFA: Hakkımızda (/about)
// API: GET /api/app/info (appName, website, contactEmail, phone, address, social) → yalnızca dolu alanlar gösterilir.
import { Link } from '../../components/LocalizedLink';
import { useAppInfo } from '../../api/hooks';
import { ContourBackdrop, Icon, type IconName } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { ContactList, contactItems } from './components/ContactList';
import { organizationLd } from './components/jsonLd';
import { PageHero } from './components/PageHero';
import { siteOrigin } from '../../seo/siteUrl';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './AboutPage.module.css';

const VALUES: { id: string; icon: IconName }[] = [
  { id: 'privacy', icon: 'eyeOff' },
  { id: 'security', icon: 'shield' },
  { id: 'access', icon: 'eye' },
  { id: 'lang', icon: 'globe' },
];

export default function AboutPage() {
  const { t } = useI18n();
  const info = useAppInfo();
  const origin = siteOrigin();
  usePageMeta({
    route: 'about',
    jsonLd: organizationLd(info.data, origin),
  });
  const hasContact = contactItems(info.data).length > 0;
  return (
    <>
      <PageHero title={t('site.about.title')} lead={t('site.about.lead')} />

      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.purpose}`}>
          <h2 className={shared.h2}>{t('site.about.purposeTitle')}</h2>
          <p className={styles.purposeText}>{t('site.about.purposeText')}</p>
        </div>
      </section>

      <section className={`${shared.section} ${styles.values}`}>
        <div className="container">
          <h2 className={shared.h2}>{t('site.about.valuesTitle')}</h2>
          <ul className={styles.valueGrid}>
            {VALUES.map((v) => (
              <li key={v.id}>
                <span className={shared.ico}>
                  <Icon name={v.icon} size={22} />
                </span>
                <h3 className={shared.h3}>{t(`site.about.value.${v.id}.title` as TranslationKey)}</h3>
                <p className={shared.muted}>{t(`site.about.value.${v.id}.text` as TranslationKey)}</p>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className={shared.section}>
        <div className="container">
          <h2 className={shared.h2}>{t('site.about.howTitle')}</h2>
          <ol className={styles.how}>
            {([1, 2, 3] as const).map((n) => (
              <li key={n}>
                <span className={styles.num} aria-hidden="true">
                  {n}
                </span>
                <div>
                  <h3 className={shared.h3}>{t(`site.about.how${n}.title` as TranslationKey)}</h3>
                  <p className={shared.muted}>{t(`site.about.how${n}.text` as TranslationKey)}</p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className={shared.band}>
        <ContourBackdrop className={shared.bandArt} />
        <div className={`container ${shared.bandInner}`}>
          <h2 className={shared.h2} style={{ color: '#fff' }}>
            {t('site.about.commitTitle')}
          </h2>
          <ul className={styles.commits}>
            {([1, 2, 3, 4] as const).map((n) => (
              <li key={n}>{t(`site.about.commit${n}` as TranslationKey)}</li>
            ))}
          </ul>
          <Link to={paths.site.legal('PRIVACY')} className={styles.bandLink}>
            {t('site.about.readPrivacy')}
          </Link>
        </div>
      </section>

      <section className={shared.section}>
        <div className={`container ${styles.who}`}>
          <h2 className={shared.h2}>{t('site.about.whoTitle')}</h2>
          <p className={shared.lead}>{t('site.about.whoText')}</p>
          {hasContact && (
            <>
              <ContactList info={info.data} />
              <p className={styles.note}>{t('site.about.whoContact')}</p>
            </>
          )}
        </div>
      </section>
    </>
  );
}
