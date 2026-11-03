import { Button } from './ui/Button';
import { Icon, type IconName } from './ui/Icon';
import styles from './ErrorScreen.module.css';

export type ErrorKind = 'error' | 'network' | 'maintenance';

export interface ErrorScreenLink {
  href: string;
  label: string;
  icon?: IconName;
}

interface Props {
  kind: ErrorKind;
  title: string;
  text: string;
  retryLabel?: string;
  homeLabel?: string;
  onRetry?: () => void;
  /** Başlık üstündeki küçük durum etiketi ("Beklenmeyen hata"). */
  eyebrow?: string;
  /** Yardımcı bağlantılar kartı (hata/ağ sorununda sağ sütun). Düz <a>: Router dışında da çalışır. */
  links?: ErrorScreenLink[];
  linksTitle?: string;
  linksText?: string;
}

/**
 * Hata / ağ sorunu / bakım için ortak tam sayfa ekranı. Metinler dışarıdan gelir (i18n bağlamı olmayan
 * ErrorBoundary de kullanabilsin diye). Hata ve ağ sorunu iki sütun (metin + yardımcı bağlantılar), bakım ortalı tek kart.
 */
export function ErrorScreen({
  kind,
  title,
  text,
  retryLabel,
  homeLabel,
  onRetry,
  eyebrow,
  links,
  linksTitle,
  linksText,
}: Props) {
  const maintenance = kind === 'maintenance';
  const icon: IconName = maintenance ? 'clock' : 'alert';
  const actions = (
    <div className={styles.actions}>
      {onRetry && retryLabel && (
        <Button onClick={onRetry} size="lg">
          {retryLabel}
        </Button>
      )}
      {homeLabel && (
        <a className={styles.home} href="/">
          <Icon name="home" size={18} />
          {homeLabel}
        </a>
      )}
    </div>
  );

  if (maintenance) {
    return (
      <div role="alert" className={styles.wrap} data-kind={kind}>
        <div className={styles.card}>
          <span className={styles.icon} aria-hidden="true">
            <Icon name={icon} size={30} />
          </span>
          {eyebrow && <p className={styles.pill}>{eyebrow}</p>}
          <h1 className={styles.titleCenter}>{title}</h1>
          <p className={styles.textCenter}>{text}</p>
          {actions}
        </div>
      </div>
    );
  }

  return (
    <div role="alert" className={styles.wrap} data-kind={kind}>
      <div className={`container ${styles.split}`}>
        <div className={styles.main}>
          {eyebrow && (
            <p className={styles.pill}>
              <span className={styles.dot} aria-hidden="true" />
              {eyebrow}
            </p>
          )}
          <h1 className={styles.title}>{title}</h1>
          <p className={styles.text}>{text}</p>
          {actions}
        </div>
        {links && links.length > 0 && (
          <nav className={styles.side} aria-label={linksTitle}>
            {linksTitle && <h2 className={styles.sideTitle}>{linksTitle}</h2>}
            {linksText && <p className={styles.sideText}>{linksText}</p>}
            <ul className={styles.linkList}>
              {links.map((l) => (
                <li key={l.href}>
                  <a className={styles.linkRow} href={l.href}>
                    {l.icon && <Icon name={l.icon} size={20} />}
                    <span>{l.label}</span>
                    <Icon name="chevronRight" size={18} className={styles.chev} />
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        )}
      </div>
    </div>
  );
}
