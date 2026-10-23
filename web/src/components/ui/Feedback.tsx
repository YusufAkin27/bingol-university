import type { CSSProperties, ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Button } from './Button';
import { Icon, type IconName } from './Icon';
import styles from './Feedback.module.css';

export function Spinner({ size = 'md', label }: { size?: 'sm' | 'md' | 'lg'; label?: string }) {
  const { t } = useI18n();
  return (
    <span
      className={`${styles.spinner} ${styles[size]}`}
      role="status"
      aria-label={label ?? t('common.loading')}
    />
  );
}

export function Skeleton({
  width,
  height = '1em',
  radius,
  style,
}: {
  width?: string | number;
  height?: string | number;
  radius?: string;
  style?: CSSProperties;
}) {
  return (
    <span
      className={styles.skeleton}
      aria-hidden="true"
      style={{ width, height, borderRadius: radius, ...style }}
    />
  );
}

interface StateProps {
  title?: string;
  description?: ReactNode;
  icon?: IconName;
  action?: ReactNode;
  compact?: boolean;
}

/** Boş durum: ne olduğunu söyler, bir sonraki adımı gösterir. */
export function EmptyState({ title, description, icon = 'info', action, compact }: StateProps) {
  const { t } = useI18n();
  return (
    <div className={`${styles.state} ${compact ? styles.compact : ''}`}>
      <span className={styles.stateIcon} aria-hidden="true">
        <Icon name={icon} size={24} />
      </span>
      <h2 className={styles.stateTitle}>{title ?? t('common.state.emptyTitle')}</h2>
      <p className={styles.stateText}>{description ?? t('common.state.emptyHint')}</p>
      {action}
    </div>
  );
}

/** Hata durumu: "Tekrar dene" düğmesiyle. */
export function ErrorState({
  title,
  description,
  onRetry,
  compact,
}: Omit<StateProps, 'icon' | 'action'> & { onRetry?: () => void }) {
  const { t } = useI18n();
  return (
    <div className={`${styles.state} ${styles.error} ${compact ? styles.compact : ''}`} role="alert">
      <span className={styles.stateIcon} aria-hidden="true">
        <Icon name="alert" size={24} />
      </span>
      <h2 className={styles.stateTitle}>{title ?? t('common.state.errorTitle')}</h2>
      <p className={styles.stateText}>{description ?? t('common.state.errorHint')}</p>
      {onRetry && (
        <Button variant="secondary" onClick={onRetry}>
          {t('common.retry')}
        </Button>
      )}
    </div>
  );
}
