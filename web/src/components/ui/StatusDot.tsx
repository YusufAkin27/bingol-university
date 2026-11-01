import type { ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Icon, type IconName } from './Icon';
import styles from './Kit.module.css';

export type StatusTone = 'success' | 'warning' | 'danger' | 'info' | 'primary' | 'neutral';

const ICON: Record<StatusTone, IconName | null> = {
  success: 'check',
  warning: 'alert',
  danger: 'x',
  info: 'info',
  primary: 'check',
  neutral: null,
};

const TONE_CLASS: Record<StatusTone, string> = {
  success: styles.statusSuccess,
  warning: styles.statusWarning,
  danger: styles.statusDanger,
  info: styles.statusInfo,
  primary: styles.statusPrimary,
  neutral: styles.statusNeutral,
};

export interface StatusDotProps {
  tone?: StatusTone;
  /** Durumu anlatan metin: "Sunucu çalışıyor". Zorunlu: renk ve simge tek başına yetmez. */
  children: ReactNode;
  /** Ekran okuyucu için ton adını ("Sorun yok") metnin önüne ekleme. Varsayılan: ekle. */
  announceTone?: boolean;
  /** Canlı/çalışıyor göstergesi için yavaş nabız (hareket azaltma tercihinde kapanır). */
  pulse?: boolean;
  className?: string;
}

/** Durum göstergesi: renk + farklı biçimli simge (onay, üçgen, çarpı, i) + metin birlikte. */
export function StatusDot({ tone = 'neutral', children, announceTone = true, pulse, className }: StatusDotProps) {
  const { t } = useI18n();
  const icon = ICON[tone];
  return (
    <span className={`${styles.status} ${TONE_CLASS[tone]} ${className ?? ''}`} data-tone={tone}>
      <span className={`${styles.statusIcon} ${pulse ? styles.pulse : ''}`} aria-hidden="true">
        {icon ? <Icon name={icon} size={13} strokeWidth={2.4} /> : <span className={styles.statusDot} />}
      </span>
      {announceTone && <span className="sr-only">{t(`admin.kit.status.${tone}`)}: </span>}
      <span className={styles.statusText}>{children}</span>
    </span>
  );
}
