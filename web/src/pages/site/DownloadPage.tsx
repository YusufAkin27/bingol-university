// SAYFA: Uygulamayı indir (/download)
// API: useStoreLinks() → GET /api/app/info (info.stores varsa) ya da GET /api/app/version?platform=ANDROID|IOS (storeUrl).
// Bağlantı yoksa düğme "Yakında" durumunda (devre dışı). QR kod gösterilmez.
import { useAppInfo, useStoreLinks } from '../../api/hooks';
import { Icon } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { mobileAppLd } from './components/jsonLd';
import { PageHero } from './components/PageHero';
import { Phone } from './components/Phone';
import { StoreButton } from './components/StoreButton';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './DownloadPage.module.css';

export default function DownloadPage() {
  const { t } = useI18n();
  const stores = useStoreLinks();
  const info = useAppInfo();
  const origin = typeof window !== 'undefined' ? window.location.origin : '';
  usePageMeta({
    title: t('site.download.title'),
    description: t('site.meta.download'),
    jsonLd: mobileAppLd(info.data, stores, origin),
  });
  return (
    <>
      <PageHero title={t('site.download.title')} lead={t('site.download.lead')} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${shared.split}`}>
          <div className={styles.stores}>
            <div className={styles.platform}>
              <h2 className={shared.h3}>{t('site.download.android')}</h2>
              <StoreButton store="android" href={stores.android} />
            </div>
            <div className={styles.platform}>
              <h2 className={shared.h3}>{t('site.download.ios')}</h2>
              <StoreButton store="ios" href={stores.ios} />
            </div>

            <div className={styles.after}>
              <h2 className={shared.h3}>{t('site.download.afterTitle')}</h2>
              <ol>
                {([1, 2, 3] as const).map((n) => (
                  <li key={n}>
                    <span className={styles.num} aria-hidden="true">
                      {n}
                    </span>
                    {t(`site.download.after${n}` as 'site.download.after1')}
                  </li>
                ))}
              </ol>
            </div>
            <div className={styles.note}>
              <Icon name="info" size={20} />
              <div>
                <strong>{t('site.download.noteTitle')}</strong>
                <p>{t('site.download.note')}</p>
              </div>
            </div>
          </div>
          <div className={styles.visual}>
            <Phone screen="home" peek tilt={-3} />
          </div>
        </div>
      </section>
    </>
  );
}
