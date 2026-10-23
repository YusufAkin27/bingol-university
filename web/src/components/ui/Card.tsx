import type { HTMLAttributes, ReactNode } from 'react';
import { Icon } from './Icon';
import { Skeleton } from './Feedback';
import styles from './Card.module.css';

interface CardProps extends Omit<HTMLAttributes<HTMLElement>, 'title'> {
  title?: ReactNode;
  actions?: ReactNode;
  padded?: boolean;
  as?: 'section' | 'div' | 'article';
}

export function Card({
  title,
  actions,
  padded = true,
  as: Tag = 'section',
  className,
  children,
  ...rest
}: CardProps) {
  return (
    <Tag className={`${styles.card} ${className ?? ''}`} {...rest}>
      {(title || actions) && (
        <header className={styles.head}>
          {title && <h2 className={styles.title}>{title}</h2>}
          {actions && <div className={styles.actions}>{actions}</div>}
        </header>
      )}
      <div className={padded ? styles.body : undefined}>{children}</div>
    </Tag>
  );
}

export function Sparkline({ data, label }: { data: number[]; label?: string }) {
  if (data.length < 2) return null;
  const w = 96;
  const h = 32;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const span = max - min || 1;
  const pts = data.map(
    (v, i) => [(i / (data.length - 1)) * w, h - 3 - ((v - min) / span) * (h - 6)] as const,
  );
  const line = pts.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ');
  const area = `${line} L${w} ${h} L0 ${h} Z`;
  return (
    <svg
      className={styles.spark}
      viewBox={`0 0 ${w} ${h}`}
      width={w}
      height={h}
      role={label ? 'img' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      preserveAspectRatio="none"
    >
      <path d={area} fill="var(--chart-1)" opacity="0.14" />
      <path
        d={line}
        fill="none"
        stroke="var(--chart-1)"
        strokeWidth="1.8"
        strokeLinejoin="round"
        strokeLinecap="round"
      />
    </svg>
  );
}

export interface StatCardProps {
  title: string;
  value: ReactNode;
  /** Önceki döneme göre yüzde değişim (örn. 12.5 ya da -3). Okla gösterilir. */
  change?: number | null;
  /** Değişim metninin yanındaki açıklama (örn. "son 7 gün"). */
  changeLabel?: string;
  /** Artışın iyi mi kötü mü olduğu (örn. açık rapor artışı kötüdür). Varsayılan: artış iyi. */
  invertTone?: boolean;
  sparkline?: number[];
  loading?: boolean;
  hint?: string;
}

export function StatCard({
  title,
  value,
  change,
  changeLabel,
  invertTone,
  sparkline,
  loading,
  hint,
}: StatCardProps) {
  const dir = change === undefined || change === null || change === 0 ? 'flat' : change > 0 ? 'up' : 'down';
  const good = dir === 'flat' ? null : (dir === 'up') !== !!invertTone;
  return (
    <div className={styles.stat}>
      <p className={styles.statTitle}>{title}</p>
      <div className={styles.statRow}>
        <p className={styles.statValue}>{loading ? <Skeleton width="4ch" height="1.1em" /> : value}</p>
        {sparkline && !loading && <Sparkline data={sparkline} />}
      </div>
      {!loading &&
        (change !== undefined && change !== null ? (
          <p className={`${styles.change} ${good === null ? '' : good ? styles.good : styles.bad}`}>
            {dir !== 'flat' && <Icon name={dir === 'up' ? 'arrowUp' : 'arrowDown'} size={14} />}
            <span className="ltr">
              {change > 0 ? '+' : ''}
              {change}%
            </span>
            {changeLabel && <span className={styles.changeLabel}>{changeLabel}</span>}
          </p>
        ) : (
          hint && <p className={styles.changeLabel}>{hint}</p>
        ))}
    </div>
  );
}
