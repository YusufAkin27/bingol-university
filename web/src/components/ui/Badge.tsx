import type { ReactNode } from 'react';
import styles from './Badge.module.css';

export type Tone = 'neutral' | 'primary' | 'success' | 'warning' | 'danger' | 'info';

export function Badge({ tone = 'neutral', children }: { tone?: Tone; children: ReactNode }) {
  return <span className={`${styles.badge} ${styles[tone]}`}>{children}</span>;
}

/** Durum rozeti: renge ek olarak nokta + metin taşır (renk tek başına anlam taşımaz). */
export function StatusPill({ tone = 'neutral', children }: { tone?: Tone; children: ReactNode }) {
  return (
    <span className={`${styles.pill} ${styles[tone]}`}>
      <span className={styles.dot} aria-hidden="true" />
      {children}
    </span>
  );
}

/** Sık kullanılan durum değerlerini tona eşler; bilinmeyen değer nötr olur. */
export function toneFor(status: string): Tone {
  switch (status) {
    case 'ACTIVE':
    case 'SENT':
    case 'DONE':
    case 'RESOLVED':
    case 'ANSWERED':
      return 'success';
    case 'OPEN':
    case 'NEW':
    case 'PENDING_REVIEW':
    case 'SCHEDULED':
    case 'SENDING':
    case 'IN_REVIEW':
      return 'warning';
    case 'SUSPENDED':
    case 'FAILED':
    case 'REJECTED':
    case 'HIDDEN':
      return 'danger';
    case 'PLANNED':
      return 'info';
    default:
      return 'neutral';
  }
}
