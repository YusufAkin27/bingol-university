// SAYFA: Özellikler (/features)
// API: yok (statik içerik; mağaza bağlantıları için useStoreLinks).
// Yerleşim: mobilde tek sütun kart, >=640 px 2 sütun, >=1100 px 3 sütun ızgara (zikzak yok).
import { useStoreLinks } from '../../api/hooks';
import { Icon } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { FEATURES } from './components/features';
import { PageHero } from './components/PageHero';
import { StoreButton } from './components/StoreButton';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './FeaturesPage.module.css';

export default function FeaturesPage() {
  const { t } = useI18n();
  const stores = useStoreLinks();
  usePageMeta({ route: 'features' });
  return (
    <>
      <PageHero title={t('site.features.title')} lead={t('site.features.lead')} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <ul className={`container ${styles.grid}`}>
          {FEATURES.map((f) => (
            <li key={f.id} className={styles.card}>
              <span className={shared.ico}>
                <Icon name={f.icon} size={24} />
              </span>
              <h2 id={`feat-${f.id}`} className={styles.title}>
                {t(f.title)}
              </h2>
              <p className={styles.text}>{t(f.text)}</p>
            </li>
          ))}
        </ul>
      </section>
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
