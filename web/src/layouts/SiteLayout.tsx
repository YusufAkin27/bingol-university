import { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAppInfo, useStoreLinks } from '../api/hooks';
import { LanguageSwitcher } from '../components/LanguageSwitcher';
import { Logo } from '../components/brand/Logo';
import { StoreBadge } from '../components/StoreBadge';
import { ThemeToggle } from '../components/ThemeToggle';
import { ButtonLink, ContourBackdrop, Icon, IconButton } from '../components/ui';
import { useI18n } from '../i18n/I18nProvider';
import type { TranslationKey } from '../i18n';
import { paths } from '../paths';
import styles from './SiteLayout.module.css';

const NAV: { to: string; key: TranslationKey; end?: boolean }[] = [
  { to: paths.site.home, key: 'site.nav.home', end: true },
  { to: paths.site.features, key: 'site.nav.features' },
  { to: paths.site.about, key: 'site.nav.about' },
  { to: paths.site.faq, key: 'site.nav.faq' },
  { to: paths.site.contact, key: 'site.nav.contact' },
];

const LEGAL: { type: string; key: TranslationKey }[] = [
  { type: 'TERMS', key: 'legal.title.TERMS' },
  { type: 'PRIVACY', key: 'legal.title.PRIVACY' },
  { type: 'KVKK', key: 'legal.title.KVKK' },
  { type: 'COMMUNITY_RULES', key: 'legal.title.COMMUNITY_RULES' },
];

export function SiteLayout() {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const location = useLocation();
  const info = useAppInfo();
  const stores = useStoreLinks();

  // Sayfa değişince menüyü kapat, en üste dön
  useEffect(() => {
    setOpen(false);
    window.scrollTo?.({ top: 0 });
  }, [location.pathname]);

  const data = info.data;

  return (
    <div className={styles.shell}>
      <a href="#main" className="skip-link">
        {t('common.skipToContent')}
      </a>
      {data?.banner && (
        <div className={styles.banner} role="note">
          {data.banner.url ? (
            <a href={data.banner.url} target="_blank" rel="noopener noreferrer">
              {data.banner.text}
            </a>
          ) : (
            data.banner.text
          )}
        </div>
      )}
      <header className={styles.header}>
        <div className={`container ${styles.bar}`}>
          <Logo to={paths.site.home} height={42} />
          <nav
            id="site-nav"
            aria-label={t('site.nav.main')}
            className={`${styles.nav} ${open ? styles.navOpen : ''}`}
          >
            {NAV.map((n) => (
              <NavLink
                key={n.to}
                to={n.to}
                end={n.end}
                className={({ isActive }) => `${styles.link} ${isActive ? styles.active : ''}`}
              >
                {t(n.key)}
              </NavLink>
            ))}
            <ButtonLink
              to={paths.site.download}
              variant="accent"
              size="md"
              className={styles.cta}
              leftIcon={<Icon name="download" size={18} />}
            >
              {t('site.nav.download')}
            </ButtonLink>
          </nav>
          <div className={styles.tools}>
            <LanguageSwitcher compact />
            <ThemeToggle />
            <IconButton
              label={open ? t('site.nav.closeMenu') : t('site.nav.openMenu')}
              className={styles.burger}
              aria-expanded={open}
              aria-controls="site-nav"
              onClick={() => setOpen((v) => !v)}
            >
              <Icon name={open ? 'x' : 'menu'} />
            </IconButton>
          </div>
        </div>
      </header>

      <main id="main" className={styles.main} tabIndex={-1}>
        <Outlet />
      </main>

      <footer className={styles.footer}>
        <ContourBackdrop className={styles.footerArt} />
        <div className={`container ${styles.footGrid}`}>
          <div className={styles.footBrand}>
            <Logo to={paths.site.home} tone="dark" height={40} />
            <p>{t('site.footer.tagline')}</p>
          </div>
          <div>
            <h2 className={styles.footTitle}>{t('site.footer.legal')}</h2>
            <ul className={styles.footList}>
              {LEGAL.map((l) => (
                <li key={l.type}>
                  <Link to={paths.site.legal(l.type)}>{t(l.key)}</Link>
                </li>
              ))}
              <li>
                <Link to={paths.site.dataRequest}>{t('site.dataRequest.title')}</Link>
              </li>
            </ul>
          </div>
          <div>
            <h2 className={styles.footTitle}>{t('site.footer.get')}</h2>
            <div className={styles.badges}>
              <StoreBadge store="android" href={stores.android} />
              <StoreBadge store="ios" href={stores.ios} />
            </div>
          </div>
          <div>
            <h2 className={styles.footTitle}>{t('site.footer.contact')}</h2>
            <ul className={styles.footList}>
              {data?.contactEmail && (
                <li>
                  <a href={`mailto:${data.contactEmail}`} className="ltr">
                    {data.contactEmail}
                  </a>
                </li>
              )}
              {data?.phone && (
                <li>
                  <a href={`tel:${data.phone.replace(/\s+/g, '')}`} className="ltr">
                    {data.phone}
                  </a>
                </li>
              )}
              {data?.address && <li>{data.address}</li>}
              {data?.social.instagram && (
                <li>
                  <a href={data.social.instagram} target="_blank" rel="noopener noreferrer">
                    Instagram
                  </a>
                </li>
              )}
              {data?.social.twitter && (
                <li>
                  <a href={data.social.twitter} target="_blank" rel="noopener noreferrer">
                    X / Twitter
                  </a>
                </li>
              )}
              {data?.social.youtube && (
                <li>
                  <a href={data.social.youtube} target="_blank" rel="noopener noreferrer">
                    YouTube
                  </a>
                </li>
              )}
              <li>
                <Link to={paths.admin.login} className={styles.adminLink}>
                  {t('site.nav.admin')}
                </Link>
              </li>
            </ul>
          </div>
        </div>
        <div className={`container ${styles.copy}`}>
          {t('site.footer.rights', { year: new Date().getFullYear() })}
        </div>
      </footer>
    </div>
  );
}
