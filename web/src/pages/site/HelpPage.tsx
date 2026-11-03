// SAYFA: Yardım merkezi (/help) — arama, kategori kartları ve doğrudan iletişim kartı.
// API: yok (statik bağlantılar). SSS içeriği /faq sayfasında GET /api/faq ile gelir; buradaki arama `/faq?q=` adresine gider.
import { useState, type FormEvent } from 'react';
import { Link, useLocalizedNavigate } from '../../components/LocalizedLink';
import { Icon, type IconName } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { AppCallout } from './components/AppCallout';
import { PageHero } from './components/PageHero';
import { Reveal } from './components/Reveal';
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
  const navigate = useLocalizedNavigate();
  const [query, setQuery] = useState('');
  const title = t('pg.help.title');
  usePageMeta({ route: 'help' });

  // Soru listesi SSS sayfasında API'den gelir: arama orada yapılır, sorgu `?q=` ile taşınır
  function onSearch(e: FormEvent) {
    e.preventDefault();
    const q = query.trim();
    navigate(q ? `${paths.site.faq}?q=${encodeURIComponent(q)}` : paths.site.faq);
  }

  return (
    <>
      <PageHero eyebrow={t('site.v3.eyebrow')} title={title} lead={t('pg.help.lead')} crumbs={[{ label: title }]}>
        <form className={styles.search} role="search" onSubmit={onSearch}>
          <label htmlFor="help-search" className="sr-only">
            {t('site.rd06.help.searchLabel')}
          </label>
          <span className={styles.searchIcon} aria-hidden="true">
            <Icon name="search" size={20} />
          </span>
          <input
            id="help-search"
            type="search"
            className={styles.input}
            value={query}
            placeholder={t('site.rd06.help.searchPlaceholder')}
            autoComplete="off"
            enterKeyHint="search"
            onChange={(e) => setQuery(e.target.value)}
          />
          <button type="submit" className={styles.searchBtn}>
            {t('site.rd06.help.searchSubmit')}
          </button>
        </form>
      </PageHero>
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className="container">
          <div className={styles.head}>
            <p className={styles.eyebrow}>{t('site.rd06.help.topicsEyebrow')}</p>
            <h2 className={styles.topics}>{t('site.rd06.help.topicsTitle')}</h2>
          </div>
          <ul className={styles.grid}>
            {HELP_CATEGORIES.map((c, i) => (
              <li key={c.id}>
                <Reveal delay={(i % 3) * 70} className={styles.card}>
                  <span className={styles.ico} aria-hidden="true">
                    <Icon name={c.icon} size={22} />
                  </span>
                  <h3 className={styles.h}>{t(`pg.help.cat.${c.id}.title` as TranslationKey)}</h3>
                  <p className={styles.text}>{t(`pg.help.cat.${c.id}.text` as TranslationKey)}</p>
                  <Link to={c.to} className={styles.open}>
                    <span className="sr-only">
                      {t('pg.help.open')} · {t(`pg.help.cat.${c.id}.title` as TranslationKey)}
                    </span>
                    <Icon name="chevronRight" size={20} className={styles.openIcon} />
                  </Link>
                </Reveal>
              </li>
            ))}
            <li>
              <Reveal delay={140} className={`${styles.card} ${styles.support}`}>
                <span className={styles.badge}>
                  <Icon name="lifebuoy" size={16} />
                  {t('site.rd06.help.direct')}
                </span>
                <h3 className={styles.h}>{t('pg.help.supportTitle')}</h3>
                <p className={styles.text}>{t('pg.help.supportText')}</p>
                <div className={styles.actions}>
                  <Link to={paths.site.contact} className={styles.cta}>
                    {t('pg.help.contact')}
                    <Icon name="chevronRight" size={18} className={styles.openIcon} />
                  </Link>
                  <Link to={paths.site.faq} className={styles.faqLink}>
                    {t('pg.help.faq')}
                  </Link>
                </div>
              </Reveal>
            </li>
          </ul>
        </div>
      </section>
      <AppCallout shot="support" title={t('site.s2.help.appTitle')} text={t('site.s2.help.appText')} phoneFirst />
    </>
  );
}
