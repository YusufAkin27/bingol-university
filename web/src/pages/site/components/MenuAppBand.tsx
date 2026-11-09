import { useId } from 'react';
import { useStoreLinks } from '../../../api/hooks';
import { useI18n } from '../../../i18n/I18nProvider';
import { PhoneMockup } from './PhoneMockup';
import { Reveal } from './Reveal';
import { StoreButton } from './StoreButton';
import styles from './MenuAppBand.module.css';

/**
 * Yemek listesi sayfasının uygulama bölümü: gerçek Yemek ekranı (SHOTS.menu) kırpılmadan, büyük telefonda.
 * Mağaza bağlantıları sunucudaki ayardan gelir (yoksa "Yakında").
 */
export function MenuAppBand() {
  const { t } = useI18n();
  const id = useId();
  const links = useStoreLinks();
  return (
    <section className={styles.wrap} aria-labelledby={id}>
      <div className="container">
        <Reveal className={styles.card}>
          <div className={styles.copy}>
            <h2 id={id} className={styles.title}>
              {t('site.s2.menu.appTitle')}
            </h2>
            <p className={styles.text}>{t('site.s2.menu.appText')}</p>
            <div className={styles.badges}>
              <StoreButton store="android" href={links.android} note={false} />
              <StoreButton store="ios" href={links.ios} note={false} />
            </div>
          </div>
          <div className={styles.shot}>
            <PhoneMockup shot="menu" width="var(--band-phone-w)" />
          </div>
        </Reveal>
      </div>
    </section>
  );
}
