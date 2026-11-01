import type { CSSProperties, ReactNode } from 'react';
import { isApiError } from '../../api/client';
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
  /** Başlık düzeyi (varsayılan 2). Sayfanın tek içeriği durumsa (404) 1 verin. */
  headingLevel?: 1 | 2;
}

/** Boş durum: ne olduğunu söyler, bir sonraki adımı gösterir. */
export function EmptyState({ title, description, icon = 'info', action, compact, headingLevel = 2 }: StateProps) {
  const { t } = useI18n();
  const Heading = headingLevel === 1 ? 'h1' : 'h2';
  return (
    <div className={`${styles.state} ${compact ? styles.compact : ''}`}>
      <span className={styles.stateIcon} aria-hidden="true">
        <Icon name={icon} size={24} />
      </span>
      <Heading className={styles.stateTitle}>{title ?? t('common.state.emptyTitle')}</Heading>
      <p className={styles.stateText}>{description ?? t('common.state.emptyHint')}</p>
      {action}
    </div>
  );
}

type ErrorReason = 'network' | 'forbidden' | 'notFound' | 'rate' | 'server' | 'generic';

/** Hata nesnesinden neden sınıfı: kullanıcıya "ne oldu, ne yapmalı" farklı söylenir. */
function reasonOf(error: unknown): ErrorReason | null {
  if (error === undefined || error === null) return null;
  if (!isApiError(error)) return error instanceof TypeError ? 'network' : 'generic';
  if (error.status === 0 || error.status === 408 || error.code === 'NETWORK_ERROR') return 'network';
  if (error.status === 401 || error.status === 403) return 'forbidden';
  if (error.status === 404) return 'notFound';
  if (error.status === 429) return 'rate';
  if (error.status >= 500) return 'server';
  return 'generic';
}

type ErrorStateProps = Omit<StateProps, 'icon' | 'action'> & {
  onRetry?: () => void;
  /**
   * Neyin yüklenemediği ("Kulüp listesi"): başlık "Kulüp listesi yüklenemedi" olur. Verilmezse genel metin kullanılır.
   * Aynı sayfada birden çok hata kutusu varsa her birinin konusunu yazın.
   */
  subject?: string;
  /** Hata nesnesi (React Query `error`): açıklama nedene göre seçilir (bağlantı yok / yetki yok / sunucu...). */
  error?: unknown;
  /** Tek satırlık kompakt görünüm: simge + cümle + "Tekrar dene". Çok sayıda kartı olan sayfalarda tercih edin. */
  inline?: boolean;
};

/** Hata durumu: "Tekrar dene" düğmesiyle; konu ve neden verilirse ne olduğunu ve ne yapılacağını söyler. */
export function ErrorState({ title, description, onRetry, compact, subject, error, inline }: ErrorStateProps) {
  const { t } = useI18n();
  const reason = reasonOf(error);
  const heading = title ?? (subject ? t('admin.kit.error.subject', { subject }) : t('common.state.errorTitle'));
  const text =
    description ??
    (reason ? t(`admin.kit.error.${reason}` as const) : subject ? t('admin.kit.error.generic') : t('common.state.errorHint'));
  // yetki hatası yeniden denemekle düzelmez
  const retry = onRetry && reason !== 'forbidden' ? onRetry : undefined;
  if (inline) {
    return (
      <div className={`${styles.inlineError}`} role="alert">
        <span className={styles.inlineIcon} aria-hidden="true">
          <Icon name="alert" size={18} />
        </span>
        <p className={styles.inlineText}>
          <strong>{heading}</strong> {text}
        </p>
        {retry && (
          <Button variant="secondary" size="sm" onClick={retry}>
            {t('common.retry')}
          </Button>
        )}
      </div>
    );
  }
  return (
    <div className={`${styles.state} ${styles.error} ${compact ? styles.compact : ''}`} role="alert">
      <span className={styles.stateIcon} aria-hidden="true">
        <Icon name="alert" size={24} />
      </span>
      <h2 className={styles.stateTitle}>{heading}</h2>
      <p className={styles.stateText}>{text}</p>
      {retry && (
        <Button variant="secondary" onClick={retry}>
          {t('common.retry')}
        </Button>
      )}
    </div>
  );
}
