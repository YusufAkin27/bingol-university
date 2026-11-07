import { useRef } from 'react';
import { createPortal } from 'react-dom';
import { LanguageSegmented } from '../components/LanguageSwitcher';
import { NavLink } from '../components/LocalizedLink';
import { Logo } from '../components/brand/Logo';
import { ButtonLink, Icon, IconButton } from '../components/ui';
import { useFocusTrap } from '../components/ui/Overlay';
import { useI18n } from '../i18n/I18nProvider';
import { useTheme } from '../lib/theme';
import { paths } from '../paths';
import { MAIN_NAV } from './siteLinks';
import styles from './SiteDrawer.module.css';

/**
 * Mobil gezinme çekmecesi (<= 1020px): satır sonundan kayan panel + karartma. Bağlantılar, dil (TR/EN/AR),
 * tema anahtarı ve tam genişlik İndir. Odak çekmecede tutulur, Escape ve karartma kapatır, kapanınca odak düğmeye döner.
 */
export function SiteDrawer({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useI18n();
  const { resolved, toggle } = useTheme();
  const ref = useRef<HTMLDivElement>(null);
  useFocusTrap(ref, open, onClose);
  if (!open) return null;
  const dark = resolved === 'dark';
  return createPortal(
    <div className={styles.scrim} onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-label={t('site.rd10.nav.drawerTitle')}
        tabIndex={-1}
        className={styles.panel}
      >
        <div className={styles.head}>
          <div className={styles.brand}>
            <Logo variant="mark" height={36} to={paths.site.home} />
            <span className={styles.brandText}>
              <strong>{t('common.appName')}</strong>
              <span>{t('site.rd10.nav.drawerTitle')}</span>
            </span>
          </div>
          <IconButton label={t('site.nav.closeMenu')} onClick={onClose}>
            <Icon name="x" />
          </IconButton>
        </div>
        <nav aria-label={t('site.nav.main')} className={styles.nav}>
          {MAIN_NAV.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              end={n.end}
              className={({ isActive }) => `${styles.link} ${isActive ? styles.active : ''}`}
              onClick={onClose}
            >
              <span>{t(n.label)}</span>
              <Icon name="chevronRight" size={18} className={styles.chev} />
            </NavLink>
          ))}
        </nav>
        <div className={styles.foot}>
          <div className={styles.settings}>
            <LanguageSegmented />
            <div className={styles.themeRow}>
              <span className={styles.themeIcon} aria-hidden="true">
                <Icon name={dark ? 'moon' : 'sun'} size={18} />
              </span>
              <span className={styles.themeLabel}>
                {t('site.rd10.theme.label')}: {dark ? t('site.rd10.theme.dark') : t('site.rd10.theme.light')}
              </span>
              <button
                type="button"
                role="switch"
                aria-checked={dark}
                aria-label={t('site.rd10.theme.switch')}
                className={styles.switch}
                onClick={toggle}
              >
                <span className={styles.knob} />
              </button>
            </div>
          </div>
          <ButtonLink
            to={paths.site.download}
            variant="accent"
            size="lg"
            fullWidth
            leftIcon={<Icon name="download" size={18} />}
            onClick={onClose}
          >
            {t('site.nav.download')}
          </ButtonLink>
          <p className={styles.note}>{t('site.v3.footer.independent')}</p>
        </div>
      </div>
    </div>,
    document.body,
  );
}
