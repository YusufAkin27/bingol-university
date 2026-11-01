import { useId, type ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Sparkline } from './Card';
import { Skeleton } from './Feedback';
import { Icon, type IconName } from './Icon';
import { formatCompact } from './kitFormat';
import styles from './Kit.module.css';

/** Artışın iyi mi kötü mü olduğu: `up` artış iyi, `down` düşüş iyi (örn. açık şikâyet), `neutral` yorum yok. */
export type GoodWhen = 'up' | 'down' | 'neutral';

export interface DeltaBadgeProps {
  /** Önceki döneme göre yüzde değişim (12.5 = %12,5 artış). null/undefined: karşılaştırma yok. */
  change: number | null | undefined;
  goodWhen?: GoodWhen;
  /** "dünden", "geçen haftaya göre" gibi karşılaştırma ifadesi (cümle başında yazılır). */
  compareLabel?: string;
  /** Karşılaştırma yoksa "Karşılaştırılacak eski veri yok" yaz (varsayılan: hiçbir şey yazma). */
  showNone?: boolean;
  className?: string;
}

/**
 * Trend rozeti: ok simgesi + "dünden %12 fazla" cümlesi + renk. Renk tek başına anlam taşımaz;
 * iyi/kötü bilgisi ekran okuyucuya ayrıca söylenir.
 */
export function DeltaBadge({ change, goodWhen = 'up', compareLabel, showNone, className }: DeltaBadgeProps) {
  const { t, formatNumber } = useI18n();
  if (change === null || change === undefined || !Number.isFinite(change)) {
    return showNone ? (
      <span className={`${styles.delta} ${styles.deltaNone} ${className ?? ''}`}>{t('admin.kit.delta.none')}</span>
    ) : null;
  }
  const rounded = Math.round(Math.abs(change) * 10) / 10;
  const dir = rounded === 0 ? 'flat' : change > 0 ? 'up' : 'down';
  const verdict = dir === 'flat' || goodWhen === 'neutral' ? null : (dir === 'up') === (goodWhen === 'up');
  const compare = compareLabel ?? t('admin.kit.delta.compareDefault');
  const text =
    dir === 'flat'
      ? t('admin.kit.delta.same', { compare })
      : t(dir === 'up' ? 'admin.kit.delta.up' : 'admin.kit.delta.down', {
          compare,
          value: formatNumber(rounded, { maximumFractionDigits: 1 }),
        });
  const tone = verdict === null ? '' : verdict ? styles.deltaGood : styles.deltaBad;
  return (
    <span className={`${styles.delta} ${tone} ${className ?? ''}`} data-dir={dir} data-good={verdict ?? undefined}>
      {dir === 'flat' ? (
        <span className={styles.flatMark} aria-hidden="true" />
      ) : (
        <Icon name={dir === 'up' ? 'arrowUp' : 'arrowDown'} size={14} aria-hidden="true" />
      )}
      <span>{text}</span>
      {verdict !== null && (
        <span className="sr-only">{t(verdict ? 'admin.kit.delta.good' : 'admin.kit.delta.bad')}</span>
      )}
    </span>
  );
}

export interface StatTileProps {
  /** Düz Türkçe etiket: "Bugün giren kişi" (DAU değil). */
  label: string;
  /** Sayı verilirse yerel biçimle yazılır (compact: 12,4 B). null/undefined: veri yok. */
  value: number | string | null | undefined;
  /** Sayının yanındaki birim: "kişi", "mesaj". */
  unit?: string;
  compact?: boolean;
  /** Tek cümlelik açıklama (isteğe bağlı). */
  caption?: ReactNode;
  /** Yüzde değişim (percentChange yardımcısıyla hesaplanır). */
  change?: number | null;
  goodWhen?: GoodWhen;
  compareLabel?: string;
  /** Mini eğri için son ölçümler (eskiden yeniye). */
  spark?: number[];
  icon?: IconName;
  loading?: boolean;
  /** Yükleme hatası: "Tekrar dene" düğmesi onRetry varsa görünür. */
  error?: boolean;
  onRetry?: () => void;
  className?: string;
}

/** Büyük sayı kutusu: etiket, büyük değer, trend cümlesi ve isteğe bağlı mini eğri; yükleniyor/boş/hata hâlleriyle. */
export function StatTile({
  label,
  value,
  unit,
  compact,
  caption,
  change,
  goodWhen,
  compareLabel,
  spark,
  icon,
  loading,
  error,
  onRetry,
  className,
}: StatTileProps) {
  const { t, formatNumber, formatDate } = useI18n();
  const labelId = useId();
  const empty = value === null || value === undefined || value === '';
  const shown =
    typeof value === 'number'
      ? compact
        ? formatCompact(value, { t, formatNumber, formatDate })
        : formatNumber(value)
      : (value ?? '');
  const sparkSummary =
    spark && spark.length >= 2
      ? t('admin.kit.tile.spark', {
          count: formatNumber(spark.length),
          first: formatNumber(spark[0]),
          last: formatNumber(spark[spark.length - 1]),
          max: formatNumber(Math.max(...spark)),
        })
      : null;

  return (
    <div
      role="group"
      aria-labelledby={labelId}
      className={`${styles.tile} ${error && !loading ? styles.tileError : ''} ${className ?? ''}`}
      aria-busy={loading || undefined}
    >
      <div className={styles.tileHead}>
        {icon && (
          <span className={styles.tileIcon} aria-hidden="true">
            <Icon name={icon} size={16} />
          </span>
        )}
        <span id={labelId} className={styles.tileLabel}>
          {label}
        </span>
      </div>
      {loading ? (
        <>
          <Skeleton width="6ch" height="1.9rem" />
          <Skeleton width="60%" height="0.9rem" />
        </>
      ) : error ? (
        <p className={styles.tileState} role="alert">
          <Icon name="alert" size={16} aria-hidden="true" />
          <span>{t('admin.kit.state.error')}</span>
          {onRetry && (
            <button type="button" className={styles.retry} onClick={onRetry}>
              {t('common.retry')}
            </button>
          )}
        </p>
      ) : (
        <>
          <div className={styles.tileBody}>
            <p className={styles.tileValue}>
              <span className={`${styles.bigNumber} ${empty ? styles.bigNumberMuted : ''}`}>
                {empty ? '–' : shown}
              </span>
              {!empty && unit && <span className={styles.unit}>{unit}</span>}
            </p>
            {spark && spark.length >= 2 && !empty && (
              <span className={styles.tileSpark}>
                <Sparkline data={spark} color="currentColor" />
                {sparkSummary && <span className="sr-only">{sparkSummary}</span>}
              </span>
            )}
          </div>
          {empty ? (
            <p className={styles.tileCaption}>{t('admin.kit.state.empty')}</p>
          ) : (
            <>
              <DeltaBadge change={change} goodWhen={goodWhen} compareLabel={compareLabel} />
              {caption && <p className={styles.tileCaption}>{caption}</p>}
            </>
          )}
        </>
      )}
    </div>
  );
}
