import { Suspense, lazy, useEffect, useId, useState, type ReactNode } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { useAppInfo, useStoreLinks } from '../api/hooks';
import { CookieBanner } from '../components/CookieBanner';
import { CookiePrefs } from '../components/CookiePrefsLazy';
import { Link, NavLink } from '../components/LocalizedLink';
import { ErrorBoundary } from '../components/ErrorBoundary';
import { LanguageSwitcher } from '../components/LanguageSwitcher';
import { PageSkeleton } from '../components/PageSkeleton';
import { Logo } from '../components/brand/Logo';
import { StoreBadge } from '../components/StoreBadge';
import { ThemeToggle } from '../components/ThemeToggle';
import { ButtonLink, Icon, IconButton } from '../components/ui';
import { useI18n } from '../i18n/I18nProvider';
import { useMediaQuery } from '../lib/useMediaQuery';
import { paths } from '../paths';
import { FOOTER_GROUPS, MAIN_NAV } from './siteLinks';
import styles from './SiteLayout.module.css';

// Çekmece yalnız menü açılınca indirilir (ana paket bütçesi)
const SiteDrawer = lazy(() => import('./SiteDrawer').then((m) => ({ default: m.SiteDrawer })));

/** Alt bilgi bağlantı grubu: masaüstünde düz başlık + liste, mobilde akordeon (varsayılan kapalı). */
function FootGroup({ title, accordion, children }: { title: string; accordion: boolean; children: ReactNode }) {
  const uid = useId();
  const [open, setOpen] = useState(false);
  if (!accordion) {
    return (
      <nav aria-labelledby={`${uid}-h`}>
        <h2 id={`${uid}-h`} className={styles.footTitle}>
          {title}
        </h2>
        {children}
      </nav>
    );
  }
  return (
    <nav aria-labelledby={`${uid}-h`} className={styles.acc}>
      <h2 id={`${uid}-h`} className={styles.accHead}>
        <button
          type="button"
          className={styles.accBtn}
          aria-expanded={open}
          aria-controls={`${uid}-p`}
          onClick={() => setOpen((v) => !v)}
        >
          <span>{title}</span>
          <Icon name="chevronDown" size={20} className={`${styles.accChev} ${open ? styles.accChevOpen : ''}`} />
        </button>
      </h2>
      <div id={`${uid}-p`} hidden={!open} className={styles.accPanel}>
        {children}
      </div>
    </nav>
  );
}

/**
 * Herkese açık site kabuğu: atlama bağlantısı, banner, üst menü (logo, ortalı gezinme, dil, tema, İndir; <= 1020px'te
 * logo + menü düğmesi ve yandan açılan çekmece), sayfa içeriği (ErrorBoundary + yükleme iskeleti), 4 sütunlu alt bilgi
 * (Kurum / Ürün / Destek / Yasal; marka + mağaza rozetleri, bağımsızlık notu, iletişim bilgisi appInfo'dan) ve çerez bandı.
 * Yönetim paneline giden hiçbir bağlantı burada bulunmaz.
 */
export function SiteLayout() {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const [prefsOpen, setPrefsOpen] = useState(false);
  const location = useLocation();
  const info = useAppInfo();
  const stores = useStoreLinks();
  const compactFooter = useMediaQuery('(max-width: 639px)');

  // Sayfa değişince menüyü kapat, en üste dön
  useEffect(() => {
    setOpen(false);
    window.scrollTo?.({ top: 0 });
  }, [location.pathname]);

  const data = info.data;
  const hasContact = !!(
    data?.contactEmail ||
    data?.phone ||
    data?.address ||
    data?.social.instagram ||
    data?.social.twitter ||
    data?.social.youtube
  );

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
          <Logo to={paths.site.home} height={36} priority />
          <nav id="site-nav" aria-label={t('site.nav.main')} className={styles.nav}>
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
          </nav>
          <div className={styles.tools}>
            <span className={styles.desk}>
              <LanguageSwitcher compact />
            </span>
            <span className={styles.desk}>
              <ThemeToggle />
            </span>
            <ButtonLink
              to={paths.site.download}
              variant="accent"
              size="md"
              className={`${styles.cta} ${styles.desk}`}
              leftIcon={<Icon name="download" size={18} />}
            >
              {t('site.nav.download')}
            </ButtonLink>
            <IconButton
              label={t('site.nav.openMenu')}
              className={styles.burger}
              aria-haspopup="dialog"
              aria-expanded={open}
              onClick={() => setOpen(true)}
            >
              <Icon name="menu" />
            </IconButton>
          </div>
        </div>
      </header>
      {open && (
        <Suspense fallback={null}>
          <SiteDrawer open onClose={() => setOpen(false)} />
        </Suspense>
      )}

      <main id="main" className={styles.main} tabIndex={-1}>
        <ErrorBoundary resetKey={location.pathname}>
          <Suspense fallback={<PageSkeleton />}>
            <Outlet />
          </Suspense>
        </ErrorBoundary>
      </main>

      <footer className={styles.footer}>
        <div className={`container ${styles.footInner}`}>
          <div className={styles.footBrand}>
            <div className={styles.brandMain}>
              <Logo to={paths.site.home} height={36} />
              <p>{t('site.footer.tagline')}</p>
            </div>
            <div className={styles.badges}>
              <StoreBadge store="android" href={stores.android} />
              <StoreBadge store="ios" href={stores.ios} />
            </div>
          </div>
          <div className={styles.groups}>
            {FOOTER_GROUPS.map((g) => (
              <FootGroup key={g.title} title={t(g.title)} accordion={compactFooter}>
                <ul className={styles.footList}>
                  {g.links.map((l) => (
                    <li key={l.to}>
                      <Link to={l.to}>{t(l.label)}</Link>
                    </li>
                  ))}
                </ul>
              </FootGroup>
            ))}
          </div>
          <div className={styles.bottom}>
            <div className={styles.notes}>
              <p className={styles.indep}>{t('site.v3.footer.independent')}</p>
              <p className={styles.sub}>{t('site.rd10.foot.domainNote')}</p>
            </div>
            <div className={styles.contact}>
              <h2 className="sr-only">{t('pg.foot.contactTitle')}</h2>
              <ul className={styles.contactList} aria-label={t('site.rd10.foot.contactLabel')}>
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
                {/* Uygulama bilgisi gelmediyse / iletişim alanları boşsa: iletişim sayfasına yedek bağlantı */}
                {!hasContact && (
                  <li>
                    <Link to={paths.site.contact}>{t('pg.foot.contactLink')}</Link>
                  </li>
                )}
              </ul>
              <p className={styles.sub}>{t('site.footer.rights', { year: new Date().getFullYear() })}</p>
              <ul className={styles.metaLinks}>
                <li>
                  <Link to={paths.site.sitemap}>{t('site.rd10.foot.sitemap')}</Link>
                </li>
                <li>
                  <button type="button" className={styles.linkBtn} onClick={() => setPrefsOpen(true)}>
                    {t('site.rd10.foot.cookiePrefs')}
                  </button>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </footer>
      <CookieBanner />
      <CookiePrefs open={prefsOpen} onClose={() => setPrefsOpen(false)} />
    </div>
  );
}
