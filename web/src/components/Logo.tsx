import { Link } from 'react-router-dom';
import { useI18n } from '../i18n/I18nProvider';
import styles from './Logo.module.css';

export function LogoMark({ size = 36 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true" focusable="false">
      <rect width="64" height="64" rx="14" fill="#1B3A6B" />
      <path d="M8 46 24 24l8 10 6-8 18 20z" fill="#F4F6FA" />
      <path d="M24 24l8 10-6 12H8z" fill="#DFE8F7" />
      <circle cx="47" cy="17" r="5" fill="#D53E35" />
    </svg>
  );
}

/** Marka: işaret + ad. `to` verilirse bağlantıdır. */
export function Logo({
  to = '/',
  subtitle,
  onDark,
  compact,
  narrowMark,
}: {
  to?: string;
  subtitle?: string;
  onDark?: boolean;
  compact?: boolean;
  /** Dar ekranda (≤480px) yalnızca işareti göster */
  narrowMark?: boolean;
}) {
  const { t } = useI18n();
  return (
    <Link
      to={to}
      className={`${styles.logo} ${onDark ? styles.onDark : ''} ${narrowMark ? styles.narrowMark : ''}`}
      aria-label={compact || narrowMark ? t('common.appName') : undefined}
    >
      <LogoMark />
      <span className={styles.text} hidden={compact}>
        <span className={styles.name}>{t('common.appName')}</span>
        {subtitle && <span className={styles.sub}>{subtitle}</span>}
      </span>
    </Link>
  );
}
