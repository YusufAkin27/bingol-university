import { useNoIndex } from '../lib/useNoIndex';
import { Suspense, useEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { Link, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useAppInfo } from '../api/hooks';
import { Logo } from '../components/brand/Logo';
import { ThemeToggle } from '../components/ThemeToggle';
import { Icon, IconButton, Spinner } from '../components/ui';
import { useFocusTrap } from '../components/ui/Overlay';
import { useI18n } from '../i18n/I18nProvider';
import { readStorage, writeStorage } from '../lib/storage';
import { paths } from '../paths';
import { adminNav, locateNav, navMatches } from './adminNav';
import { QuickNav } from './QuickNav';
import { UserMenu } from './UserMenu';
import styles from './AdminLayout.module.css';

const COLLAPSE_KEY = 'bu.admin.sidebar';
const GROUPS_KEY = 'bu.admin.navgroups';

/** wide: sabit yan menü (>=1100) · rail: simge çubuğu, genişletince üstte açılır (720-1099) · narrow: çekmece (<720) */
type Tier = 'wide' | 'rail' | 'narrow';

function readTier(): Tier {
  try {
    if (window.matchMedia('(min-width: 1100px)').matches) return 'wide';
    if (window.matchMedia('(min-width: 720px)').matches) return 'rail';
    return 'narrow';
  } catch {
    return 'wide';
  }
}

function useTier(): Tier {
  const [tier, setTier] = useState<Tier>(readTier);
  useEffect(() => {
    let a: MediaQueryList;
    let b: MediaQueryList;
    try {
      a = window.matchMedia('(min-width: 1100px)');
      b = window.matchMedia('(min-width: 720px)');
    } catch {
      return;
    }
    const on = () => setTier(readTier());
    a.addEventListener?.('change', on);
    b.addEventListener?.('change', on);
    on();
    return () => {
      a.removeEventListener?.('change', on);
      b.removeEventListener?.('change', on);
    };
  }, []);
  return tier;
}

function readGroups(): Record<string, boolean> {
  try {
    const v = JSON.parse(readStorage('local', GROUPS_KEY) ?? '{}') as unknown;
    return v && typeof v === 'object' ? (v as Record<string, boolean>) : {};
  } catch {
    return {};
  }
}

export function AdminLayout() {
  useNoIndex();
  const { t } = useI18n();
  const location = useLocation();
  const navigate = useNavigate();
  const tier = useTier();
  const [collapsed, setCollapsed] = useState(() => readStorage('local', COLLAPSE_KEY) === '1');
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [filter, setFilter] = useState('');
  const [groupState, setGroupState] = useState<Record<string, boolean>>(readGroups);
  const info = useAppInfo();
  const asideRef = useRef<HTMLElement>(null);

  const mode: 'full' | 'rail' | 'hidden' =
    tier === 'wide' ? (collapsed ? 'rail' : 'full') : drawerOpen ? 'full' : tier === 'rail' ? 'rail' : 'hidden';
  const slot: 'full' | 'rail' | 'none' =
    tier === 'wide' ? (collapsed ? 'rail' : 'full') : tier === 'rail' ? 'rail' : 'none';
  const overlay = tier !== 'wide' && drawerOpen;
  const rail = mode === 'rail';

  useEffect(() => setDrawerOpen(false), [location.pathname, tier]);

  // Çekmece/üstte açılan menü: odak menüde döner, Esc kapatır, kapanınca odak düğmeye döner
  useFocusTrap(asideRef, overlay, () => setDrawerOpen(false));

  useEffect(() => {
    const onKey = (e: globalThis.KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setSearchOpen(true);
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

  const here = useMemo(() => locateNav(location.pathname), [location.pathname]);
  const filtering = !rail && filter.trim() !== '';

  const visibleGroups = useMemo(
    () =>
      adminNav
        .map((g) => ({
          ...g,
          label: t(g.labelKey),
          items: g.items
            .map((i) => ({ ...i, label: t(i.labelKey) }))
            .filter((i) => !filtering || navMatches(i.label, filter)),
        }))
        .filter((g) => g.items.length > 0),
    [t, filter, filtering],
  );
  const matchCount = visibleGroups.reduce((n, g) => n + g.items.length, 0);

  function isOpen(id: string): boolean {
    if (rail || filtering) return true;
    return groupState[id] ?? (id === 'overview' || id === here?.group.id);
  }

  function toggleGroup(id: string) {
    setGroupState((m) => {
      const next = { ...m, [id]: !isOpen(id) };
      writeStorage('local', GROUPS_KEY, JSON.stringify(next));
      return next;
    });
  }

  /** Menüdeki odaklanabilir öğeler (filtre, grup başlıkları, bağlantılar) arasında ok tuşlarıyla gezinti. */
  function onNavKey(e: KeyboardEvent<HTMLElement>) {
    if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(e.key)) return;
    const root = asideRef.current;
    if (!root) return;
    const items = Array.from(root.querySelectorAll<HTMLElement>('[data-navitem]')).filter(
      (el) => !el.closest('[hidden]'),
    );
    if (items.length === 0) return;
    const idx = items.indexOf(document.activeElement as HTMLElement);
    let next = idx;
    if (e.key === 'ArrowDown') next = Math.min(idx + 1, items.length - 1);
    else if (e.key === 'ArrowUp') next = Math.max(idx - 1, 0);
    else if (e.key === 'Home') next = 0;
    else next = items.length - 1;
    if (idx === -1) next = e.key === 'End' ? items.length - 1 : 0;
    e.preventDefault();
    items[next]?.focus();
  }

  const maintenance = info.data?.maintenance;
  const crumbs: { label: string; to?: string }[] = [{ label: t('admin.layout.home'), to: paths.admin.dashboard }];
  if (here) {
    if (here.item.id !== 'dashboard') crumbs.push({ label: t(here.group.labelKey) });
    crumbs.push({ label: t(here.item.labelKey) });
  }

  const expandLabel = tier === 'wide' ? t('admin.nav.expand') : t('admin.nav.open');
  const toggleLabel = tier === 'wide' && !collapsed ? t('admin.nav.collapse') : expandLabel;

  return (
    <div className={styles.shell} data-slot={slot} data-tier={tier}>
      <a href="#admin-main" className="skip-link">
        {t('common.skipToContent')}
      </a>

      {overlay && <div className={styles.scrim} onClick={() => setDrawerOpen(false)} aria-hidden="true" />}
      <div className={styles.slot}>
        <aside
          ref={asideRef}
          className={`${styles.sidebar} ${overlay ? styles.overlay : ''}`}
          data-mode={mode}
          aria-label={t('admin.nav.title')}
          onKeyDown={onNavKey}
        >
          <div className={styles.brand}>
            {rail ? (
              <Logo to={paths.admin.dashboard} variant="mark" height={36} />
            ) : (
              <>
                <Logo to={paths.admin.dashboard} tone="dark" height={32} />
                <span className={styles.brandSub}>{t('admin.nav.title')}</span>
              </>
            )}
            {overlay && (
              <IconButton
                label={t('admin.nav.close')}
                className={styles.closeBtn}
                data-autofocus
                onClick={() => setDrawerOpen(false)}
              >
                <Icon name="x" />
              </IconButton>
            )}
          </div>

          {!rail && (
            <div className={styles.filter}>
              <Icon name="search" size={16} className={styles.filterIcon} />
              <input
                type="search"
                className={styles.filterInput}
                value={filter}
                placeholder={t('admin.nav.filter.placeholder')}
                aria-label={t('admin.nav.filter.label')}
                autoComplete="off"
                spellCheck={false}
                data-navitem
                onChange={(e) => setFilter(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Escape' && filter) {
                    e.stopPropagation();
                    e.preventDefault();
                    setFilter('');
                  } else if (e.key === 'Enter' && visibleGroups[0]) {
                    e.preventDefault();
                    navigate(visibleGroups[0].items[0].to);
                  }
                }}
              />
              {filter && (
                <button
                  type="button"
                  className={styles.filterClear}
                  aria-label={t('admin.nav.filter.clear')}
                  onClick={() => setFilter('')}
                >
                  <Icon name="x" size={14} />
                </button>
              )}
              <span className="sr-only" role="status">
                {filtering ? t('admin.nav.filter.count', { count: matchCount }) : ''}
              </span>
            </div>
          )}

          <nav className={styles.nav} aria-label={t('admin.nav.aria')}>
            {filtering && visibleGroups.length === 0 && (
              <p className={styles.filterEmpty}>{t('admin.nav.filter.empty')}</p>
            )}
            <ul className={styles.groups}>
              {visibleGroups.map((g) => {
                const open = isOpen(g.id);
                const listId = `admin-nav-${g.id}`;
                return (
                  <li key={g.id} className={styles.group}>
                    {rail ? (
                      <div className={styles.divider} aria-hidden="true" />
                    ) : filtering ? (
                      <p className={styles.groupBtn}>{g.label}</p>
                    ) : (
                      <button
                        type="button"
                        className={styles.groupBtn}
                        aria-expanded={open}
                        aria-controls={listId}
                        data-navitem
                        onClick={() => toggleGroup(g.id)}
                      >
                        <span>{g.label}</span>
                        <Icon name={open ? 'chevronUp' : 'chevronDown'} size={14} className={styles.groupChev} />
                      </button>
                    )}
                    <ul id={listId} className={styles.items} hidden={!open}>
                      {g.items.map((i) => (
                        <li key={i.id}>
                          <NavLink
                            to={i.to}
                            end={i.end}
                            title={rail ? i.label : undefined}
                            aria-label={rail ? i.label : undefined}
                            data-navitem
                            className={({ isActive }) => `${styles.item} ${isActive ? styles.active : ''}`}
                          >
                            <Icon name={i.icon} size={20} />
                            <span className={styles.itemLabel}>{i.label}</span>
                          </NavLink>
                        </li>
                      ))}
                    </ul>
                  </li>
                );
              })}
            </ul>
          </nav>

          {!overlay && tier !== 'narrow' && (
            <button
              type="button"
              className={styles.collapseBtn}
              onClick={() => (tier === 'wide' ? toggleCollapsed() : setDrawerOpen(true))}
              aria-label={toggleLabel}
              title={toggleLabel}
              aria-expanded={tier === 'wide' ? !collapsed : false}
            >
              <Icon name="panel" size={20} />
              <span className={styles.itemLabel}>{toggleLabel}</span>
            </button>
          )}
        </aside>
      </div>

      <div className={styles.column}>
        <header className={styles.topbar}>
          {tier === 'narrow' && (
            <IconButton
              label={t('admin.nav.open')}
              className={styles.menuBtn}
              aria-expanded={drawerOpen}
              onClick={() => setDrawerOpen(true)}
            >
              <Icon name="menu" />
            </IconButton>
          )}
          <nav className={styles.crumbs} aria-label={t('admin.layout.breadcrumb')}>
            <ol>
              {crumbs.map((c, i) => {
                const last = i === crumbs.length - 1;
                return (
                  <li key={i} aria-current={last ? 'page' : undefined} data-last={last || undefined}>
                    {c.to && !last ? <Link to={c.to}>{c.label}</Link> : <span>{c.label}</span>}
                  </li>
                );
              })}
            </ol>
          </nav>
          <div className={styles.tools}>
            <button type="button" className={styles.searchBtn} onClick={() => setSearchOpen(true)}>
              <Icon name="search" size={18} />
              <span className={styles.searchText}>{t('admin.layout.search')}</span>
              <kbd className="ltr">Ctrl K</kbd>
            </button>
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
