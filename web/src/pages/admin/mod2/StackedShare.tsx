// Yığılmış pay çubuğu: tek bir şeridin içinde parçaların oranı + altında "etiket · sayı · yüzde" açıklaması.
// Renk tek başına anlam taşımaz: her parçanın adı, sayısı ve yüzdesi yazılıdır (recharts gerektirmez).
import { useI18n } from '../../../i18n/I18nProvider';
import { useGt } from './dict';
import styles from './mod2.module.css';

export type ShareTone = 'success' | 'warning' | 'danger' | 'info' | 'neutral' | 'primary';

export interface ShareSegment {
  key: string;
  label: string;
  value: number;
  tone: ShareTone;
}

/** Parçaların toplamı ve yüzdeleri (sıfır toplamda hepsi 0). Yüzdeler yuvarlanır, bu yüzden toplamı 100 olmayabilir. */
export function shareStats(segments: Pick<ShareSegment, 'value'>[]): { total: number; pct: number[] } {
  const total = segments.reduce((s, x) => s + Math.max(0, x.value), 0);
  return { total, pct: segments.map((x) => (total > 0 ? Math.round((Math.max(0, x.value) / total) * 100) : 0)) };
}

export function StackedShare({
  segments,
  ariaLabel,
  className,
}: {
  segments: ShareSegment[];
  ariaLabel: string;
  className?: string;
}) {
  const { formatNumber } = useI18n();
  const t = useGt();
  const { total, pct } = shareStats(segments);
  if (total <= 0) {
    return <p className={styles.shareEmpty}>{t('admin.mod2.share.none')}</p>;
  }
  const summary = segments
    .map((s, i) => t('admin.mod2.share.item', { label: s.label, n: formatNumber(s.value), pct: formatNumber(pct[i]) }))
    .join(', ');
  return (
    <div className={`${styles.share} ${className ?? ''}`}>
      <div className={styles.shareBar} role="img" aria-label={`${ariaLabel}: ${summary}`}>
        {segments.map(
          (s) =>
            s.value > 0 && (
              <span
                key={s.key}
                className={`${styles.shareSeg} ${styles[`tone_${s.tone}`]}`}
                style={{ flexGrow: s.value }}
                title={`${s.label}: ${formatNumber(s.value)}`}
              />
            ),
        )}
      </div>
      <ul className={styles.shareLegend} aria-label={ariaLabel}>
        {segments.map((s, i) => (
          <li key={s.key} className={s.value === 0 ? styles.shareZero : undefined}>
            <span className={`${styles.dot} ${styles[`tone_${s.tone}`]}`} aria-hidden="true" />
            <span className={styles.shareLabel}>{s.label}</span>
            <strong className={styles.shareNum}>{formatNumber(s.value)}</strong>
            <span className={styles.sharePct}>{s.value > 0 && pct[i] === 0 ? '<1%' : `${formatNumber(pct[i])}%`}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
