// SAYFA: Özellikler (/features)
// API: yok (statik içerik; mağaza bağlantıları CtaBand içinde useStoreLinks ile).
// Yapı: sosyal akış (soyut çizim) + yedi ekran vitrini (zikzak FeatureRow: telefon + başlık + metin) > "Ve daha fazlası" ayrıntı ızgarası > alt CTA.
import { Icon } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { CtaBand } from './components/CtaBand';
import { FEATURES, MORE_FEATURE_IDS, SHOWCASE } from './components/features';
import { FeatureRow } from './components/FeatureRow';
import { FeedSketch } from './components/FeedSketch';
import { PageHero } from './components/PageHero';
import { Reveal } from './components/Reveal';
import { SectionHeading } from './components/SectionHeading';
import { usePageMeta } from './components/usePageMeta';
import styles from './FeaturesPage.module.css';

const MORE = FEATURES.filter((f) => MORE_FEATURE_IDS.includes(f.id));

export default function FeaturesPage() {
  const { t } = useI18n();
  usePageMeta({ route: 'features' });
  return (
    <>
      <PageHero eyebrow={t('site.v3.eyebrow')} title={t('site.features.title')} lead={t('site.features.lead')} />
      <section className="container" aria-label={t('site.features.title')}>
        <ul className={styles.rows}>
          {/* Sosyal akış: gerçek kullanıcı içeriği içermeyen soyut çizim (mahremiyet); diğer satırlar uygulamanın kendi ekranları */}
          <li>
            <FeatureRow
              id="feat-social"
              figure={<FeedSketch />}
              title={t('site.show.social.title')}
              text={t('site.show.social.text')}
            />
          </li>
          {SHOWCASE.map((s, i) => (
            <li key={s.id}>
              <FeatureRow
                id={`feat-${s.id}`}
                shot={s.shot}
                secondShot={s.secondShot}
                title={t(s.title)}
                text={t(s.text)}
                flip={i % 2 === 0}
              />
            </li>
          ))}
        </ul>
      </section>

      <section className={styles.more} aria-labelledby="feat-more">
        <div className="container">
          <SectionHeading id="feat-more" title={t('site.v3.features.moreTitle')} lead={t('site.v3.features.moreLead')} />
          <ul className={styles.grid}>
            {MORE.map((f, i) => (
              <li key={f.id}>
                <Reveal delay={(i % 3) * 70} className={styles.card}>
                  <span className={styles.ico}>
                    <Icon name={f.icon} size={22} />
                  </span>
                  <h3 id={`feat-${f.id}`} className={styles.cardTitle}>
                    {t(f.title)}
                  </h3>
                  <p className={styles.cardText}>{t(f.text)}</p>
                </Reveal>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <CtaBand title={t('site.features.ctaTitle')} text={t('site.v3.cta.text')} />
    </>
  );
}
