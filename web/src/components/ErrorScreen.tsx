import { Button } from './ui/Button';
import { Icon } from './ui/Icon';
import styles from './ErrorScreen.module.css';

export type ErrorKind = 'error' | 'network' | 'maintenance';

interface Props {
  kind: ErrorKind;
  title: string;
  text: string;
  retryLabel?: string;
  homeLabel?: string;
  onRetry?: () => void;
  /** Bakım ekranında "güncel durum" bağlantısı. */
  statusLabel?: string;
}

/**
 * Hata / ağ sorunu / bakım için ortak tam sayfa ekranı. Metinler dışarıdan gelir (i18n bağlamı olmayan
 * ErrorBoundary de kullanabilsin diye). Ana sayfa bağlantısı düz <a> (Router dışında da çalışır).
 */
export function ErrorScreen({ kind, title, text, retryLabel, homeLabel, onRetry, statusLabel }: Props) {
  const icon = kind === 'maintenance' ? 'settings' : 'alert';
  return (
    <div role="alert" className={styles.wrap} data-kind={kind}>
      <div className={styles.box}>
        <span className={styles.icon} aria-hidden="true">
          <Icon name={icon} size={28} />
        </span>
        <h1 className={styles.title}>{title}</h1>
        <p className={styles.text}>{text}</p>
        <div className={styles.actions}>
          {onRetry && retryLabel && <Button onClick={onRetry}>{retryLabel}</Button>}
          {homeLabel && (
            <a className={styles.home} href="/">
              {homeLabel}
            </a>
          )}
          {statusLabel && (
            <a className={styles.home} href="/status">
              {statusLabel}
            </a>
          )}
        </div>
      </div>
    </div>
  );
}
