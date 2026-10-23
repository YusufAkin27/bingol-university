// SAYFA: Veri talebi / KVKK hakları (/data-request)
// API: GET /api/app/info (contactEmail/supportEmail: başvuru e-postası; yoksa gizlenir). Metinler statiktir.
import { Link } from 'react-router-dom';
import { useAppInfo } from '../../api/hooks';
import { Icon } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './DataRequestPage.module.css';

export default function DataRequestPage() {
  const { t } = useI18n();
  const info = useAppInfo();
  usePageMeta({ title: t('site.dataRequest.title'), description: t('site.meta.dataRequest') });
  const mail = info.data?.contactEmail ?? info.data?.supportEmail ?? null;
  return (
    <>
      <PageHero title={t('site.dataRequest.title')} lead={t('site.dataRequest.lead')} />
      <div className={`container ${styles.page}`}>
        <section className={styles.block} aria-labelledby="dr-self">
          <h2 id="dr-self" className={shared.h2}>
            {t('site.dataRequest.selfTitle')}
          </h2>
          <div className={styles.selfGrid}>
            {([1, 2] as const).map((n) => (
              <div key={n} className={styles.self}>
                <span className={shared.ico}>
                  <Icon name={n === 1 ? 'download' : 'logout'} size={22} />
                </span>
                <h3 className={shared.h3}>{t(`site.dataRequest.self${n}.title` as TranslationKey)}</h3>
                <p className={shared.muted}>{t(`site.dataRequest.self${n}.text` as TranslationKey)}</p>
              </div>
            ))}
          </div>
        </section>

        <section className={styles.block} aria-labelledby="dr-rights">
          <h2 id="dr-rights" className={shared.h2}>
            {t('site.dataRequest.rightsTitle')}
          </h2>
          <ul className={styles.rights}>
            {([1, 2, 3, 4, 5, 6, 7, 8, 9] as const).map((n) => (
              <li key={n}>
                <Icon name="check" size={18} />
                <span>{t(`site.dataRequest.right${n}` as TranslationKey)}</span>
              </li>
            ))}
          </ul>
        </section>

        <section className={styles.block} aria-labelledby="dr-apply">
          <h2 id="dr-apply" className={shared.h2}>
            {t('site.dataRequest.applyTitle')}
          </h2>
          <ul className={styles.apply}>
            <li>{t('site.dataRequest.apply1')}</li>
            {mail && (
              <li>
                {t('site.dataRequest.apply2')}{' '}
                <a href={`mailto:${mail}`} className="ltr">
                  {mail}
                </a>
              </li>
            )}
          </ul>
          <p className={shared.muted}>{t('site.dataRequest.applyNote')}</p>
        </section>

        <section className={styles.block} aria-labelledby="dr-ret">
          <h2 id="dr-ret" className={shared.h2}>
            {t('site.dataRequest.retentionTitle')}
          </h2>
          <ul className={styles.apply}>
            {([1, 2, 3, 4] as const).map((n) => (
              <li key={n}>{t(`site.dataRequest.ret${n}` as TranslationKey)}</li>
            ))}
          </ul>
          <p>
            <Link to={paths.site.legal('KVKK')} className={styles.link}>
              {t('site.dataRequest.readKvkk')}
            </Link>
          </p>
        </section>
      </div>
    </>
  );
}
