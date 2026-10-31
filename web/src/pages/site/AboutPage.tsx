// SAYFA: Hakkımızda (/about)
// API: GET /api/app/info (appName, website, contactEmail, phone, address, social) → yalnızca dolu alanlar gösterilir.
// Yapı: amaç + telefon > değerler (4 madde) > nasıl çalışır (3 adım) > taahhütler > biz kimiz / bağımsızlık notu + iletişim > alt CTA.
import { Link } from '../../components/LocalizedLink';
import { useAppInfo } from '../../api/hooks';
import { Icon, type IconName } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { siteOrigin } from '../../seo/siteUrl';
import { ContactList, contactItems } from './components/ContactList';
import { CtaBand } from './components/CtaBand';
import { organizationLd } from './components/jsonLd';
import { PageHero } from './components/PageHero';
import { PhoneMockup } from './components/PhoneMockup';
import { PointList } from './components/PointList';
import { Reveal } from './components/Reveal';
import { SectionHeading } from './components/SectionHeading';
import { Steps } from './components/Steps';
import { usePageMeta } from './components/usePageMeta';
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
      <PageHero eyebrow={t('site.v3.eyebrow')} title={t('site.about.title')} lead={t('site.about.lead')} />

      <section className={styles.sec}>
        <div className={`container ${styles.purpose}`}>
          <Reveal className={styles.purposeCopy}>
            <h2 className={styles.h2}>{t('site.about.purposeTitle')}</h2>
            <p className={styles.purposeText}>{t('site.about.purposeText')}</p>
          </Reveal>
          <Reveal className={styles.purposeShot} delay={80}>
            <PhoneMockup shot="menu" width="min(56vw, 230px)" tilt={-2} />
          </Reveal>
        </div>
      </section>

      <section className={`${styles.sec} ${styles.soft}`} aria-labelledby="about-values">
        <div className="container">
          <SectionHeading id="about-values" title={t('site.about.valuesTitle')} />
          <div className={styles.block}>
            <PointList
              items={VALUES.map((v) => ({
                icon: v.icon,
                text: (
                  <>
                    <strong>{t(`site.about.value.${v.id}.title` as TranslationKey)}</strong>
                    <span className={styles.muted}>{t(`site.about.value.${v.id}.text` as TranslationKey)}</span>
                  </>
                ),
              }))}
            />
          </div>
        </div>
      </section>

      <section className={styles.sec} aria-labelledby="about-how">
        <div className="container">
          <SectionHeading id="about-how" title={t('site.about.howTitle')} />
          <div className={styles.block}>
            <Steps
              items={([1, 2, 3] as const).map((n) => ({
                title: t(`site.about.how${n}.title` as TranslationKey),
                text: t(`site.about.how${n}.text` as TranslationKey),
              }))}
            />
          </div>
        </div>
      </section>

      <section className={`${styles.sec} ${styles.soft}`} aria-labelledby="about-commit">
        <div className={`container ${styles.commit}`}>
          <div className={styles.commitHead}>
            <SectionHeading id="about-commit" title={t('site.about.commitTitle')} />
            <Link to={paths.site.legal('PRIVACY')} className={styles.more}>
              {t('site.about.readPrivacy')}
              <Icon name="chevronRight" size={18} className={styles.moreIcon} />
            </Link>
          </div>
          <PointList
            items={([1, 2, 3, 4] as const).map((n) => ({
              icon: 'check' as IconName,
              text: t(`site.about.commit${n}` as TranslationKey),
            }))}
          />
        </div>
      </section>

      <section className={styles.sec} aria-labelledby="about-who">
        <div className={`container ${styles.who}`}>
          <SectionHeading id="about-who" eyebrow={t('site.v3.about.indTitle')} title={t('site.about.whoTitle')} lead={t('site.about.whoText')} />
          {hasContact && (
            <div className={styles.contact}>
              <ContactList info={info.data} />
              <p className={styles.note}>{t('site.about.whoContact')}</p>
            </div>
          )}
        </div>
      </section>

      <CtaBand title={t('site.home.ctaTitle')} text={t('site.v3.cta.text')} />
    </>
  );
}
