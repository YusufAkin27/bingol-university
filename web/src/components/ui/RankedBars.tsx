import { useMemo, useState } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Icon } from './Icon';
import { Skeleton } from './Feedback';
import styles from './Kit.module.css';
import { Tooltip } from './Tooltip';

export interface RankedItem {
  key: string;
  label: string;
  value: number;
  /** Etiketin altındaki kısa not ("Bilgisayar Mühendisliği"). */
  hint?: string;
}

export interface RankedBarsProps {
  items: RankedItem[] | undefined;
  /** Liste için erişilebilir ad: "En çok mesaj atılan sohbetler". */
  ariaLabel: string;
  /** desc: en çok olan üstte (varsayılan); asc: en az olan üstte. */
  order?: 'desc' | 'asc';
  /** İlk gösterilen satır sayısı; fazlası "Tümünü göster" ile açılır. 0: hepsi. */
  limit?: number;
  formatValue?: (n: number) => string;
  /** Toplamdaki payı ("toplamın %12'si") da yaz. */
  showShare?: boolean;
  /** Bu uzunluktan uzun etiketler kırpılır ve ipucu ile tam gösterilir. */
  truncateAt?: number;
  loading?: boolean;
  error?: boolean;
  onRetry?: () => void;
  emptyLabel?: string;
  className?: string;
}

/** Yatay sıralı çubuk listesi: sıra numarası + etiket + değer yazısı + çubuk. Dar ekranda çubuk alt satıra iner. */
export function RankedBars({
  items,
  ariaLabel,
  order = 'desc',
  limit = 5,
  formatValue,
  showShare,
  truncateAt = 28,
  loading,
  error,
  onRetry,
  emptyLabel,
  className,
}: RankedBarsProps) {
  const { t, formatNumber } = useI18n();
  const [expanded, setExpanded] = useState(false);
  const fmt = formatValue ?? ((n: number) => formatNumber(n));

  const sorted = useMemo(() => {
    const list = [...(items ?? [])];
    list.sort((a, b) => (order === 'desc' ? b.value - a.value : a.value - b.value));
    return list;
  }, [items, order]);
  const total = useMemo(() => sorted.reduce((s, i) => s + Math.max(0, i.value), 0), [sorted]);
  const max = useMemo(() => Math.max(0, ...sorted.map((i) => i.value)), [sorted]);

  if (loading) {
    return (
      <div className={`${styles.ranked} ${className ?? ''}`} role="status" aria-busy="true" aria-label={t('common.loading')}>
        {[0, 1, 2].map((i) => (
          <Skeleton key={i} width="100%" height="2.4rem" />
        ))}
      </div>
    );
  }
  if (error) {
    return (
      <div className={styles.stateBox} role="alert">
        <Icon name="alert" size={20} />
        <span>{t('admin.kit.state.error')}</span>
        {onRetry && (
          <button type="button" className={styles.retry} onClick={onRetry}>
            {t('common.retry')}
          </button>
        )}
      </div>
    );
  }
  if (sorted.length === 0) {
    return (
      <div className={styles.stateBox}>
        <Icon name="info" size={20} />
        <span>{emptyLabel ?? t('admin.kit.state.empty')}</span>
      </div>
    );
  }

  const canFold = limit > 0 && sorted.length > limit;
  const visible = canFold && !expanded ? sorted.slice(0, limit) : sorted;

  return (
    <div className={className}>
      <ol className={styles.ranked} aria-label={ariaLabel}>
        {visible.map((it, idx) => {
          const pct = max > 0 ? Math.max(0, (it.value / max) * 100) : 0;
          const long = it.label.length > truncateAt;
          const labelNode = long ? (
            <Tooltip text={it.label}>
              <span className={styles.truncate} tabIndex={0}>
                {it.label}
              </span>
            </Tooltip>
          ) : (
            <span className={styles.truncate}>{it.label}</span>
          );
          return (
            <li key={it.key} className={styles.rankedRow}>
              <span className={`${styles.rank} ${idx === 0 ? styles.rankTop : ''}`}>
                {formatNumber(idx + 1)}
              </span>
              <span className={styles.rankLabel}>
                {labelNode}
                {it.hint && <span className={styles.rankHint}>{it.hint}</span>}
              </span>
              <span className={styles.rankValue}>
                {fmt(it.value)}
                {showShare && total > 0 && (
                  <span className={styles.rankShare}>
                    {t('admin.kit.ranked.share', { value: formatNumber(Math.round((it.value / total) * 100)) })}
                  </span>
                )}
              </span>
              <span className={styles.rankBar} aria-hidden="true">
                <span className={styles.rankFill} style={{ display: 'block', inlineSize: `${pct}%` }} />
              </span>
            </li>
          );
        })}
      </ol>
      {canFold && (
        <button
          type="button"
          className={styles.moreBtn}
          aria-expanded={expanded}
          onClick={() => setExpanded((v) => !v)}
        >
          {expanded
            ? t('admin.kit.ranked.showLess')
            : t('admin.kit.ranked.showAll', { count: formatNumber(sorted.length) })}
        </button>
      )}
    </div>
  );
}
