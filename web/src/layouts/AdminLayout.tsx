import { useNoIndex } from '../lib/useNoIndex';
import { Suspense, useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAppInfo } from '../api/hooks';
import { LanguageSwitcher } from '../components/LanguageSwitcher';
import { Logo } from '../components/brand/Logo';
import { ThemeToggle } from '../components/ThemeToggle';
import { Icon, IconButton, Spinner } from '../components/ui';
import { useI18n } from '../i18n/I18nProvider';
import { readStorage, writeStorage } from '../lib/storage';
import { paths } from '../paths';
import { adminNav } from './adminNav';
import { QuickNav } from './QuickNav';
import { UserMenu } from './UserMenu';
import styles from './AdminLayout.module.css';

const COLLAPSE_KEY = 'bu.admin.sidebar';

export function AdminLayout() {
  useNoIndex();
  const { t, dir } = useI18n();
  const location = useLocation();
  const [collapsed, setCollapsed] = useState(() => readStorage('local', COLLAPSE_KEY) === '1');
  const [mobileOpen, setMobileOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const info = useAppInfo();

  useEffect(() => setMobileOpen(false), [location.pathname]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setSearchOpen(true);
      } else if (e.key === 'Escape') {
        setMobileOpen(false);
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, []);

  function toggleCollapsed() {
    setCollapsed((c) => {
      writeStorage('local', COLLAPSE_KEY, c ? '0' : '1');
      return !c;
    });
  }

  const maintenance = info.data?.maintenance;

  return (
    <div className={`${styles.shell} ${collapsed ? styles.collapsed : ''}`}>
      <a href="#admin-main" className="skip-link">
        {t('common.skipToContent')}
      </a>

      {mobileOpen && <div className={styles.scrim} onClick={() => setMobileOpen(false)} aria-hidden="true" />}
      <aside
        className={`${styles.sidebar} ${mobileOpen ? styles.open : ''}`}
        aria-label={t('admin.nav.aria')}
      >
        <div className={styles.brand}>
          {collapsed && !mobileOpen ? (
            <Logo to={paths.admin.dashboard} variant="mark" height={36} />
          ) : (
            <>
              <Logo to={paths.admin.dashboard} tone="dark" height={32} />
              <span className={styles.brandSub}>{t('admin.nav.title')}</span>
            </>
          )}
        </div>
        <nav className={styles.nav}>
          {adminNav.map((g) => (
            <div key={g.id} className={styles.group}>
              <p className={styles.groupLabel}>{t(g.labelKey)}</p>
              {g.items.map((i) => (
                <NavLink
                  key={i.id}
                  to={i.to}
                  end={i.end}
                  title={collapsed ? t(i.labelKey) : undefined}
                  className={({ isActive }) => `${styles.item} ${isActive ? styles.active : ''}`}
                >
                  <Icon name={i.icon} size={20} />
                  <span className={styles.itemLabel}>{t(i.labelKey)}</span>
                </NavLink>
              ))}
            </div>
          ))}
        </nav>
        <button
          type="button"
          className={styles.collapseBtn}
          onClick={toggleCollapsed}
          aria-label={collapsed ? t('admin.nav.expand') : t('admin.nav.collapse')}
          title={collapsed ? t('admin.nav.expand') : t('admin.nav.collapse')}
        >
          <Icon name="panel" size={20} style={dir === 'rtl' ? { transform: 'scaleX(-1)' } : undefined} />
          <span className={styles.itemLabel}>
            {collapsed ? t('admin.nav.expand') : t('admin.nav.collapse')}
          </span>
        </button>
      </aside>

      <div className={styles.column}>
        <header className={styles.topbar}>
          <IconButton
            label={t('admin.nav.open')}
            className={styles.menuBtn}
            aria-expanded={mobileOpen}
            onClick={() => setMobileOpen((v) => !v)}
          >
            <Icon name="menu" />
          </IconButton>
          <button type="button" className={styles.searchBtn} onClick={() => setSearchOpen(true)}>
            <Icon name="search" size={18} />
            <span>{t('admin.layout.search')}</span>
            <kbd className="ltr">Ctrl K</kbd>
          </button>
          <div className={styles.tools}>
            <LanguageSwitcher compact />
            <ThemeToggle />
            <UserMenu />
          </div>
        </header>

        {maintenance?.enabled && (
          <div className={styles.maintenance} role="status">
            <Icon name="alert" size={18} />
            <strong>{t('admin.layout.maintenance')}</strong>
            {maintenance.message && <span>{maintenance.message}</span>}
          </div>
        )}

        <main id="admin-main" className={styles.main} tabIndex={-1}>
          <Suspense
            fallback={
              <div className={styles.loading}>
                <Spinner size="lg" />
              </div>
            }
          >
            <Outlet />
          </Suspense>
        </main>
      </div>
      <QuickNav open={searchOpen} onClose={() => setSearchOpen(false)} />
    </div>
  );
}
