// SAYFA: İletişim (/contact)
// API: GET /api/app/info (contactEmail, supportEmail, phone, address, social); herkese açık 'Bize ulaşın' formu (POST /api/public/support/*, T27).
// İletişim bilgisi yalnızca appInfo'dan gelir; boş alan çizilmez.
import { Link } from '../../components/LocalizedLink';
import { useAppInfo } from '../../api/hooks';
import { ErrorState, Icon } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { AppCallout } from './components/AppCallout';
import { ContactList, contactItems } from './components/ContactList';
import { organizationLd } from './components/jsonLd';
import { PageHero } from './components/PageHero';
import { PublicSupportForm } from './components/PublicSupportForm';
import { siteOrigin } from '../../seo/siteUrl';
import { usePageMeta } from './components/usePageMeta';
import styles from './ContactPage.module.css';

export default function ContactPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const info = useAppInfo();
  const origin = siteOrigin();
  usePageMeta({
    route: 'contact',
    jsonLd: organizationLd(info.data, origin),
  });
  const items = contactItems(info.data);
  return (
    <>
      <PageHero eyebrow={t('site.rd07.contact.eyebrow')} title={t('site.contact.title')} lead={t('site.contact.lead')} />
      <section className={styles.section}>
        <div className={`container ${styles.grid}`}>
          <div className={styles.main}>
            <PublicSupportForm />
          </div>

          <div className={styles.side}>
            {info.isError ? (
              <ErrorState
                compact
                title={t('site.contact.loadError')}
                description={errorMessage(i18n, info.error)}
                onRetry={() => void info.refetch()}
              />
            ) : items.length > 0 ? (
              <section className={styles.panel} aria-labelledby="contact-direct">
                <header className={styles.panelHead}>
                  <h2 id="contact-direct" className={styles.h3}>
                    {t('site.rd07.contact.directTitle')}
                  </h2>
                  <p className={styles.sub}>{t('site.rd07.contact.directSub')}</p>
                </header>
                <ContactList info={info.data} />
              </section>
            ) : (
              info.isSuccess && (
                <div className={styles.empty}>
                  <Icon name="info" size={20} />
                  <div>
                    <strong>{t('site.contact.emptyTitle')}</strong>
                    <p>{t('site.contact.emptyText')}</p>
                  </div>
                </div>
              )
            )}

            <section className={styles.panel} aria-labelledby="contact-tips">
              <h2 id="contact-tips" className={styles.h3}>
                {t('site.rd07.contact.tipsTitle')}
              </h2>
              <p className={styles.tip}>
                <strong>{t('site.rd07.contact.tipCodeTitle')}</strong> {t('site.rd07.contact.tipCodeText')}
              </p>
              <Link to={paths.site.faq} className={styles.link}>
                {t('site.rd07.contact.tipFaq')}
                <Icon name="chevronRight" size={18} className={styles.linkIcon} />
              </Link>
            </section>

            <aside className={styles.panel} aria-labelledby="contact-data">
              <h2 id="contact-data" className={styles.h3}>
                {t('site.contact.dataTitle')}
              </h2>
              <p className={styles.sub}>{t('site.contact.dataText')}</p>
              <Link to={paths.site.dataRequest} className={styles.link}>
                {t('site.contact.dataLink')}
                <Icon name="chevronRight" size={18} className={styles.linkIcon} />
              </Link>
            </aside>
          </div>
        </div>
      </section>

      <section className={styles.official} aria-labelledby="contact-official">
        <div className="container">
          <div className={styles.officialCard}>
            <span className={styles.officialIcon}>
              <Icon name="shield" size={22} />
            </span>
            <div className={styles.officialBody}>
              <h2 id="contact-official" className={styles.officialTitle}>
                {t('site.rd07.contact.officialTitle')}
              </h2>
              <p className={styles.sub}>{t('site.rd07.contact.officialText')}</p>
            </div>
          </div>
        </div>
      </section>

      <AppCallout shot="support" title={t('site.contact.inAppTitle')} text={t('site.contact.inAppText')} phoneFirst>
        <ol className={styles.steps}>
          {([1, 2, 3] as const).map((n) => (
            <li key={n}>
              <span className={styles.num} aria-hidden="true">
                {n}
              </span>
              {t(`site.contact.inApp${n}` as 'site.contact.inApp1')}
            </li>
          ))}
        </ol>
      </AppCallout>
    </>
  );
}
