import { Suspense } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { Logo } from '../../components/brand/Logo';
import { ThemeToggle } from '../../components/ThemeToggle';
import { Button, Icon, type IconName } from '../../components/ui';
import { PageSkeleton } from '../../layouts/PageSkeleton';
import { RouteBoundary } from '../../layouts/RouteBoundary';
import { useAcadAuth } from './auth/AcadAuth';
import { useT } from './dict';
import { acadPaths } from './paths';
import styles from './layout.module.css';

const NAV: { to: string; key: string; icon: IconName; end?: boolean }[] = [
  { to: acadPaths.home, key: 'ac.nav.home', icon: 'home', end: true },
  { to: acadPaths.courses, key: 'ac.nav.courses', icon: 'graduation' },
  { to: acadPaths.profile, key: 'ac.nav.profile', icon: 'users' },
];

/** Onaylı akademisyen kabuğu: üst çubuk (marka, gezinti, tema, çıkış) + içerik. Canlı yoklama ekranı bu kabuğun içinde tam ekrana geçebilir. */
export default function AcadLayout() {
  const t = useT();
  const { me, logout } = useAcadAuth();
  const location = useLocation();
  const name = [me?.title, me?.firstName, me?.lastName].filter(Boolean).join(' ');
  return (
    <div className={styles.shell}>
      <a href="#acad-main" className="skip-link">
        {t('ac.skip')}
      </a>
      <header className={styles.top}>
        <div className={styles.brand}>
          {/* Logo'ya `to` verilmez: kit bağlantısı site dil önekini ekler; akademisyen yolu bunun dışındadır */}
          <NavLink to={acadPaths.home} className={styles.brandLink} aria-label={t('ac.brand')}>
            <Logo height={30} decorative />
            <span className={styles.brandSub}>{t('ac.brand.sub')}</span>
          </NavLink>
        </div>
        <nav className={styles.nav} aria-label={t('ac.nav.aria')}>
          {NAV.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              end={n.end}
              className={({ isActive }) => `${styles.navItem} ${isActive ? styles.active : ''}`}
            >
              <Icon name={n.icon} size={18} />
              <span>{t(n.key)}</span>
            </NavLink>
          ))}
        </nav>
        <div className={styles.tools}>
          <span className={styles.who} title={name}>
            {name}
          </span>
          <ThemeToggle />
          <Button variant="ghost" size="sm" leftIcon={<Icon name="logout" size={18} />} onClick={() => void logout()}>
            {t('ac.logout')}
          </Button>
        </div>
      </header>
      <main id="acad-main" className={styles.main} tabIndex={-1}>
        <RouteBoundary resetKey={location.pathname}>
          <Suspense fallback={<PageSkeleton />}>
            <Outlet />
          </Suspense>
        </RouteBoundary>
      </main>
    </div>
  );
}
