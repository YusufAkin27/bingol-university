// SAYFA: Hakkımızda (/about)
// API: GET /api/app/info (appName, website, contactEmail, phone, address, social) → yalnızca dolu alanlar gösterilir.
// Yapı: başlık > illüstrasyon + doğrulama kartı > bağımsızlık notu > misyon/vizyon + telefon > ilkeler (4 kart) >
// nasıl çalışır (3 adım) > taahhütler > iletişim (yalnız bilgi varsa) > alt CTA.
import { Link } from '../../components/LocalizedLink';
import { useAppInfo } from '../../api/hooks';
import { Icon, type IconName } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { siteOrigin } from '../../seo/siteUrl';
import { AboutArt } from './components/AboutArt';
import { ContactList, contactItems } from './components/ContactList';
import { CtaBand } from './components/CtaBand';
import { InlineLinks } from './components/InlineLinks';
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

      <section className={styles.top} aria-labelledby="about-who">
        <div className={`container ${styles.topGrid}`}>
          <AboutArt className={styles.art} />
          <aside className={styles.verify}>
            <span className={styles.verifyIcon}>
              <Icon name="mail" size={22} />
            </span>
            <p className={styles.eyebrow}>{t('site.rd07.about.verifyEyebrow')}</p>
            <h2 className={styles.h3}>{t('site.about.how2.title')}</h2>
            <p className={styles.muted}>{t('site.about.how2.text')}</p>
          </aside>
          <div className={styles.notice}>
            <span className={styles.noticeIcon}>
              <Icon name="shield" size={22} />
            </span>
            <div className={styles.noticeBody}>
              <p className={styles.eyebrow}>{t('site.v3.about.indTitle')}</p>
              <h2 id="about-who" className={styles.h3}>
                {t('site.about.whoTitle')}
              </h2>
              <p className={styles.muted}>{t('site.about.whoText')}</p>
            </div>
          </div>
        </div>
      </section>

      <section className={styles.sec} aria-labelledby="about-purpose">
        <div className={`container ${styles.purpose}`}>
          <div className={styles.purposeCards}>
            <Reveal as="article" className={styles.card}>
              <p className={styles.eyebrow}>{t('site.rd07.about.missionEyebrow')}</p>
              <h2 id="about-purpose" className={styles.h3}>
                {t('site.rd07.about.missionTitle')}
              </h2>
              <p className={styles.body}>{t('site.about.purposeText')}</p>
            </Reveal>
            <Reveal as="article" className={styles.card} delay={80}>
              <p className={styles.eyebrow}>{t('site.rd07.about.visionEyebrow')}</p>
              <h2 className={styles.h3}>{t('site.rd07.about.visionTitle')}</h2>
              <p className={styles.body}>{t('site.rd07.about.visionText')}</p>
            </Reveal>
          </div>
          <Reveal className={styles.purposeShot} delay={120}>
            <PhoneMockup shot="menu" width="min(72vw, 300px)" tilt={-2} />
          </Reveal>
        </div>
      </section>

      <section className={`${styles.sec} ${styles.soft}`} aria-labelledby="about-values">
        <div className="container">
          <SectionHeading id="about-values" title={t('site.about.valuesTitle')} />
          <ul className={styles.values}>
            {VALUES.map((v, i) => (
              <Reveal as="li" key={v.id} className={styles.value} delay={i * 60}>
                <span className={styles.valueIcon}>
                  <Icon name={v.icon} size={22} />
                </span>
                <h3 className={styles.valueTitle}>{t(`site.about.value.${v.id}.title` as TranslationKey)}</h3>
                <p className={styles.muted}>{t(`site.about.value.${v.id}.text` as TranslationKey)}</p>
              </Reveal>
            ))}
          </ul>
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

      {hasContact && (
        <section className={styles.sec} aria-labelledby="about-contact">
          <div className={`container ${styles.contact}`}>
            <SectionHeading id="about-contact" title={t('site.rd07.about.contactTitle')} lead={t('site.about.whoContact')} />
            <div className={styles.contactList}>
              <ContactList info={info.data} />
              <Link to={paths.site.contact} className={styles.more}>
                {t('site.rd07.about.contactLink')}
                <Icon name="chevronRight" size={18} className={styles.moreIcon} />
              </Link>
            </div>
          </div>
        </section>
      )}

      <InlineLinks
        label={t('site.links.about.label')}
        links={[
          { to: paths.site.contact, label: t('site.links.about.contact') },
          { to: paths.site.faq, label: t('site.links.about.faq') },
        ]}
      >
        {t('site.links.about.text')}
      </InlineLinks>

      <CtaBand title={t('site.home.ctaTitle')} text={t('site.v3.cta.text')} />
    </>
  );
}
