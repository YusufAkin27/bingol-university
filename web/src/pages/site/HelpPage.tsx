// SAYFA: Yardım merkezi (/help) — kategori kartları, SSS ve iletişim/destek yönlendirmesi.
// API: yok (statik bağlantılar). SSS içeriği /faq sayfasında GET /api/faq ile gelir.
import { Link } from 'react-router-dom';
import { ButtonLink, Icon, type IconName } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './HelpPage.module.css';

export const HELP_CATEGORIES: { id: string; icon: IconName; to: string }[] = [
  { id: 'start', icon: 'users', to: paths.site.faq },
  { id: 'features', icon: 'message', to: paths.site.features },
  { id: 'safety', icon: 'shield', to: paths.site.security },
  { id: 'rules', icon: 'flag', to: paths.site.guidelines },
  { id: 'data', icon: 'file', to: paths.site.deleteAccount },
];

export default function HelpPage() {
  const { t } = useI18n();
  const title = t('pg.help.title');
  usePageMeta({ title, description: t('pg.help.meta'), path: paths.site.help });
  return (
    <>
      <PageHero title={title} lead={t('pg.help.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className="container">
          <ul className={styles.grid}>
            {HELP_CATEGORIES.map((c) => (
              <li key={c.id} className={styles.card}>
                <span className={shared.ico} aria-hidden="true">
                  <Icon name={c.icon} size={22} />
                </span>
                <h2 className={styles.h}>{t(`pg.help.cat.${c.id}.title` as TranslationKey)}</h2>
                <p className={shared.muted}>{t(`pg.help.cat.${c.id}.text` as TranslationKey)}</p>
                <Link to={c.to} className={styles.open}>
                  {t('pg.help.open')}
                  <span className="sr-only"> · {t(`pg.help.cat.${c.id}.title` as TranslationKey)}</span>
                </Link>
              </li>
            ))}
          </ul>
          <div className={styles.support}>
            <h2 className={shared.h3}>{t('pg.help.supportTitle')}</h2>
            <p className={shared.muted}>{t('pg.help.supportText')}</p>
            <div className={shared.actions}>
              <ButtonLink to={paths.site.faq}>{t('pg.help.faq')}</ButtonLink>
              <ButtonLink to={paths.site.contact} variant="secondary">
                {t('pg.help.contact')}
              </ButtonLink>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
