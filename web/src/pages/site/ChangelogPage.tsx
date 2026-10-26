// SAYFA: Sürüm notları (/changelog)
// API: yok. docs/CHANGELOG.md bulunmadığından içerik çeviri dosyalarındaki statik girdilerden gelir (pg.changelog.eN.*).
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './ChangelogPage.module.css';

/** Girdi sayısı ve madde sayıları; yeni girdi = üç dilde yeni anahtarlar + buraya satır. */
export const CHANGELOG: { id: string; items: number }[] = [
  { id: 'e1', items: 6 },
  { id: 'e2', items: 3 },
];

export default function ChangelogPage() {
  const { t } = useI18n();
  const title = t('pg.changelog.title');
  usePageMeta({ title, description: t('pg.changelog.meta'), path: paths.site.changelog });
  return (
    <>
      <PageHero title={title} lead={t('pg.changelog.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          {CHANGELOG.map((e) => (
            <article key={e.id} className={styles.entry} aria-labelledby={`cl-${e.id}`}>
              <h2 id={`cl-${e.id}`} className={shared.h3}>
                <time dateTime={t(`pg.changelog.${e.id}.date` as TranslationKey)}>
                  {t(`pg.changelog.${e.id}.title` as TranslationKey)}
                </time>
              </h2>
              <ul>
                {Array.from({ length: e.items }, (_, i) => (
                  <li key={i}>{t(`pg.changelog.${e.id}.l${i + 1}` as TranslationKey)}</li>
                ))}
              </ul>
            </article>
          ))}
          <p className={shared.muted}>{t('pg.changelog.note')}</p>
        </div>
      </section>
    </>
  );
}
