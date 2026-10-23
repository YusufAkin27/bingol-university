// SAYFA: Özellikler (/features)
// API: yok (statik içerik; mağaza bağlantıları için useStoreLinks).
import { useStoreLinks } from '../../api/hooks';
import { Icon } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { FEATURES } from './components/features';
import { PageHero } from './components/PageHero';
import { Phone } from './components/Phone';
import { StoreButton } from './components/StoreButton';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './FeaturesPage.module.css';

export default function FeaturesPage() {
  const { t } = useI18n();
  const stores = useStoreLinks();
  usePageMeta({ title: t('site.features.title'), description: t('site.meta.features') });
  return (
    <>
      <PageHero title={t('site.features.title')} lead={t('site.features.lead')} />
      <div className={`container ${styles.list}`}>
        {FEATURES.map((f) => (
          <section key={f.id} className={styles.row} aria-labelledby={`feat-${f.id}`}>
            <div className={styles.text}>
              <span className={shared.ico}>
                <Icon name={f.icon} size={24} />
              </span>
              <h2 id={`feat-${f.id}`} className={shared.h2}>
                {t(f.title)}
              </h2>
              <p className={shared.lead}>{t(f.text)}</p>
            </div>
            <div className={styles.visual}>
              <Phone screen={f.screen} peek />
            </div>
          </section>
        ))}
      </div>
      <section className={shared.band}>
        <div className={`container ${shared.bandInner} ${styles.cta}`}>
          <h2 className={shared.h2} style={{ color: '#fff' }}>
            {t('site.features.ctaTitle')}
          </h2>
          <div className={styles.ctaButtons}>
            <StoreButton store="android" href={stores.android} onDark />
            <StoreButton store="ios" href={stores.ios} onDark />
          </div>
        </div>
      </section>
    </>
  );
}
