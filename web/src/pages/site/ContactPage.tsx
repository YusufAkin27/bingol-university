// SAYFA: İletişim (/contact)
// API: GET /api/app/info (contactEmail, supportEmail, phone, address, social). Formsuz: mailto + uygulama içi destek yönlendirmesi.
import { Link } from 'react-router-dom';
import { useAppInfo } from '../../api/hooks';
import { ErrorState, Icon } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { ContactList, contactItems } from './components/ContactList';
import { organizationLd } from './components/jsonLd';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './ContactPage.module.css';

export default function ContactPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const info = useAppInfo();
  const origin = typeof window !== 'undefined' ? window.location.origin : '';
  usePageMeta({
    title: t('site.contact.title'),
    description: t('site.meta.contact'),
    jsonLd: organizationLd(info.data, origin),
  });
  const items = contactItems(info.data);
  return (
    <>
      <PageHero title={t('site.contact.title')} lead={t('site.contact.lead')} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.grid}`}>
          <div className={styles.main}>
            <div className={styles.inApp}>
              <h2 className={shared.h2}>{t('site.contact.inAppTitle')}</h2>
              <p className={shared.lead}>{t('site.contact.inAppText')}</p>
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
            </div>

            {info.isError ? (
              <ErrorState
                compact
                title={t('site.contact.loadError')}
                description={errorMessage(i18n, info.error)}
                onRetry={() => void info.refetch()}
              />
            ) : items.length > 0 ? (
              <ContactList info={info.data} />
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
          </div>

          <aside className={styles.side}>
            <h2 className={shared.h3}>{t('site.contact.dataTitle')}</h2>
            <p className={shared.muted}>{t('site.contact.dataText')}</p>
            <Link to={paths.site.dataRequest} className={styles.link}>
              {t('site.contact.dataLink')}
            </Link>
          </aside>
        </div>
      </section>
    </>
  );
}
