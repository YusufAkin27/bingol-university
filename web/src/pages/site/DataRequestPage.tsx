// SAYFA: Veri talebi / KVKK hakları (/data-request)
// API: GET /api/app/info (contactEmail/supportEmail: başvuru e-postası; yoksa gizlenir). Metinler statiktir; sayfada form/gönderim yok:
// uygulamadan kendin yap (indir/sil), uygulama içi destek talebi ve e-posta yolları anlatılır.
import { Link } from '../../components/LocalizedLink';
import { useAppInfo } from '../../api/hooks';
import { ButtonLink, Icon } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { PointList } from './components/PointList';
import { Reveal } from './components/Reveal';
import { SectionHeading } from './components/SectionHeading';
import { usePageMeta } from './components/usePageMeta';
import styles from './DataRequestPage.module.css';

export default function DataRequestPage() {
  const { t } = useI18n();
  const info = useAppInfo();
  usePageMeta({ route: 'dataRequest' });
  const mail = info.data?.contactEmail ?? info.data?.supportEmail ?? null;
  return (
    <>
      <PageHero title={t('site.dataRequest.title')} lead={t('site.dataRequest.lead')} crumbs={[{ label: t('site.dataRequest.title') }]} />
      <div className={`container ${styles.page}`}>
        <section className={styles.block} aria-labelledby="dr-self">
          <SectionHeading id="dr-self" title={t('site.dataRequest.selfTitle')} />
          <PointList
            items={([1, 2] as const).map((n) => ({
              icon: n === 1 ? 'download' : 'logout',
              text: (
                <>
                  <strong>{t(`site.dataRequest.self${n}.title` as TranslationKey)}</strong>
                  <span className={styles.muted}>{t(`site.dataRequest.self${n}.text` as TranslationKey)}</span>
                </>
              ),
            }))}
          />
        </section>

        <section className={styles.block} aria-labelledby="dr-rights">
          <SectionHeading id="dr-rights" title={t('site.dataRequest.rightsTitle')} />
          <Reveal>
            <ul className={styles.rights}>
              {([1, 2, 3, 4, 5, 6, 7, 8, 9] as const).map((n) => (
                <li key={n}>
                  <Icon name="check" size={18} />
                  <span>{t(`site.dataRequest.right${n}` as TranslationKey)}</span>
                </li>
              ))}
            </ul>
          </Reveal>
        </section>

        <section className={styles.block} aria-labelledby="dr-apply">
          <SectionHeading id="dr-apply" title={t('site.dataRequest.applyTitle')} />
          <ul className={styles.apply}>
            <li>
              <Icon name="lifebuoy" size={20} />
              <span>{t('site.dataRequest.apply1')}</span>
            </li>
            {mail && (
              <li>
                <Icon name="mail" size={20} />
                <span>
                  {t('site.dataRequest.apply2')}{' '}
                  <a href={`mailto:${mail}`} className="ltr">
                    {mail}
                  </a>
                </span>
              </li>
            )}
          </ul>
          <p className={styles.note}>{t('site.dataRequest.applyNote')}</p>
          <div className={styles.actions}>
            <ButtonLink to={paths.site.contact} variant="secondary">
              {t('site.nav.contact')}
            </ButtonLink>
          </div>
        </section>

        <section className={styles.block} aria-labelledby="dr-ret">
          <SectionHeading id="dr-ret" title={t('site.dataRequest.retentionTitle')} />
          <ul className={styles.ret}>
            {([1, 2, 3, 4] as const).map((n) => (
              <li key={n}>{t(`site.dataRequest.ret${n}` as TranslationKey)}</li>
            ))}
          </ul>
          <p>
            <Link to={paths.site.legal('KVKK')} className={styles.link}>
              {t('site.dataRequest.readKvkk')}
              <Icon name="chevronRight" size={18} className={styles.arrow} />
            </Link>
          </p>
        </section>
      </div>
    </>
  );
}
