import { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAppInfo, useStoreLinks } from '../api/hooks';
import { CookieBanner } from '../components/CookieBanner';
import { ErrorBoundary } from '../components/ErrorBoundary';
import { LanguageSwitcher } from '../components/LanguageSwitcher';
import { Logo } from '../components/brand/Logo';
import { StoreBadge } from '../components/StoreBadge';
import { ThemeToggle } from '../components/ThemeToggle';
import { ButtonLink, ContourBackdrop, Icon, IconButton } from '../components/ui';
import { useI18n } from '../i18n/I18nProvider';
import { paths } from '../paths';
import { MAIN_NAV, SITE_GROUPS } from './siteLinks';
import styles from './SiteLayout.module.css';

/**
 * Herkese açık site kabuğu: atlama bağlantısı, banner, üst menü (dil + tema + mobil hamburger),
 * sayfa içeriği (ErrorBoundary ile korunur), sütunlu alt bilgi ve çerez bilgilendirme bandı.
 * Yönetim paneline giden hiçbir bağlantı burada bulunmaz.
 */
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
            {MAIN_NAV.map((n) => (
              <NavLink
                key={n.to}
                to={n.to}
                end={n.end}
                className={({ isActive }) => `${styles.link} ${isActive ? styles.active : ''}`}
              >
                {t(n.label)}
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
        <ErrorBoundary resetKey={location.pathname}>
          <Outlet />
        </ErrorBoundary>
      </main>

      <footer className={styles.footer}>
        <ContourBackdrop className={styles.footerArt} />
        <div className={`container ${styles.footGrid}`}>
          <div className={styles.footBrand}>
            <Logo to={paths.site.home} tone="dark" height={40} />
            <p>{t('site.footer.tagline')}</p>
            <h2 className={styles.footTitle}>{t('pg.foot.get')}</h2>
            <div className={styles.badges}>
              <StoreBadge store="android" href={stores.android} />
              <StoreBadge store="ios" href={stores.ios} />
            </div>
            <h2 className={styles.footTitle}>{t('pg.foot.contactTitle')}</h2>
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
            </ul>
          </div>
          {SITE_GROUPS.map((g) => (
            <nav key={g.title} aria-labelledby={`foot-${g.title}`}>
              <h2 id={`foot-${g.title}`} className={styles.footTitle}>
                {t(g.title)}
              </h2>
              <ul className={styles.footList}>
                {g.links.map((l) => (
                  <li key={l.to}>
                    <Link to={l.to}>{t(l.label)}</Link>
                  </li>
                ))}
              </ul>
            </nav>
          ))}
        </div>
        <div className={`container ${styles.copy}`}>
          {t('site.footer.rights', { year: new Date().getFullYear() })}
        </div>
      </footer>
      <CookieBanner />
    </div>
  );
}
