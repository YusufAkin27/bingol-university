// SAYFA: Sürüm notları (/changelog)
// API: GET /api/app/info (iletişim e-postası), GET /api/app/version (mağazadaki güncel sürüm; yoksa gizlenir).
// docs/CHANGELOG.md geliştirici günlüğüdür; ziyaretçiye dönük içerik çeviri dosyalarındaki girdilerden gelir (pg.changelog.eN.*).
import { useQuery } from '@tanstack/react-query';
import { checkVersion } from '../../api/appInfo';
import { useAppInfo } from '../../api/hooks';
import { qk } from '../../api/queryKeys';
import { ButtonLink, Icon } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { Reveal } from './components/Reveal';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './ChangelogPage.module.css';

/**
 * Girdi sayısı ve madde sayıları; yeni girdi = üç dilde yeni anahtarlar + buraya satır (en yeni en üstte).
 * `version` yalnızca girdinin gerçek sürümü biliniyorsa doldurulur (rozet olarak çizilir); bilinmiyorsa boş bırakın.
 */
export const CHANGELOG: { id: string; items: number; version?: string }[] = [
  { id: 'e1', items: 6 },
  { id: 'e2', items: 3 },
];

export default function ChangelogPage() {
  const { t } = useI18n();
  const info = useAppInfo();
  const email = info.data?.contactEmail || info.data?.supportEmail || null;
  const store = useQuery({
    queryKey: qk.storeLink('ANDROID'),
    queryFn: () => checkVersion('ANDROID'),
    staleTime: 10 * 60_000,
    retry: false,
  });
  const latest = store.data?.latestVersion || null;
  const title = t('pg.changelog.title');
  usePageMeta({ route: 'changelog' });
  return (
    <>
      <PageHero eyebrow={t('site.v3.eyebrow')} title={title} lead={t('pg.changelog.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.layout}`}>
          <div className={styles.main}>
            <ol className={styles.timeline}>
              {CHANGELOG.map((e, idx) => (
                <li key={e.id} className={`${styles.item} ${idx === 0 ? styles.itemLatest : ''}`}>
                  <span className={styles.dot} aria-hidden="true" />
                  <Reveal delay={idx * 60}>
                    <article className={styles.entry} aria-labelledby={`cl-${e.id}`}>
                      <header className={styles.entryHead}>
                        <h2 id={`cl-${e.id}`} className={styles.entryTitle}>
                          <Icon name="calendar" size={18} />
                          <time dateTime={t(`pg.changelog.${e.id}.date` as TranslationKey)}>
                            {t(`pg.changelog.${e.id}.title` as TranslationKey)}
                          </time>
                        </h2>
                        <span className={styles.tags}>
                          {e.version && (
                            <span className={styles.version} dir="ltr">
                              {t('site.rd08.cl.versionLabel', { v: e.version })}
                            </span>
                          )}
                          {idx === 0 && <span className={styles.latest}>{t('site.rd08.cl.latest')}</span>}
                        </span>
                      </header>
                      <ul className={styles.list}>
                        {Array.from({ length: e.items }, (_, i) => (
                          <li key={i}>{t(`pg.changelog.${e.id}.l${i + 1}` as TranslationKey)}</li>
                        ))}
                      </ul>
                    </article>
                  </Reveal>
                </li>
              ))}
            </ol>
            <p className={shared.muted}>{t('pg.changelog.note')}</p>
          </div>

          <aside className={styles.side} aria-labelledby="cl-feedback">
            <div className={styles.card}>
              <span className={styles.cardIcon} aria-hidden="true">
                <Icon name="message" size={22} />
              </span>
              <h2 id="cl-feedback" className={styles.cardTitle}>
                {t('site.rd08.cl.feedbackTitle')}
              </h2>
              <p className={styles.cardText}>{t('site.rd08.cl.feedbackText')}</p>
              {email && (
                <a className={styles.mail} href={`mailto:${email}`}>
                  <Icon name="mail" size={18} />
                  <span dir="ltr">{email}</span>
                </a>
              )}
              <ButtonLink to={paths.site.contact} variant={email ? 'secondary' : 'primary'}>
                {t('site.rd08.cl.feedbackCta')}
              </ButtonLink>
              {latest && (
                <p className={styles.storeVersion}>
                  <span>{t('site.rd08.cl.storeVersion')}</span>
                  <strong dir="ltr">{latest}</strong>
                </p>
              )}
            </div>
          </aside>
        </div>
      </section>
    </>
  );
}
