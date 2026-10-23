import { useI18n } from '../../i18n/I18nProvider';
import styles from './charts.module.css';

export interface FunnelStep {
  label: string;
  value: number;
}

interface Props {
  steps: FunnelStep[];
  ariaLabel: string;
  emptyLabel?: string;
}

/**
 * Dönüşüm hunisi: her adım ilk adıma oranla çubuk genişliği ve yüzde gösterir.
 * Anlam taşıyan değerler metin olarak da yazıldığı için ekran okuyucular için ek etiket gerekmez.
 */
export function FunnelChart({ steps, ariaLabel, emptyLabel }: Props) {
  const { t, formatNumber } = useI18n();
  const top = steps[0]?.value ?? 0;
  if (steps.length === 0 || top === 0) {
    return (
      <div
        className={styles.empty}
        style={{ height: 160 }}
        role="img"
        aria-label={`${ariaLabel}: ${emptyLabel ?? t('common.noResults')}`}
      >
        {emptyLabel ?? t('common.noResults')}
      </div>
    );
  }
  return (
    <ol className={styles.funnel} aria-label={ariaLabel}>
      {steps.map((s) => {
        const pct = Math.round((s.value / top) * 100);
        return (
          <li key={s.label} className={styles.funnelRow}>
            <div className={styles.funnelHead}>
              <span>{s.label}</span>
              <span className={styles.funnelValue}>
                {formatNumber(s.value)}
                <span className={styles.funnelPct}>%{formatNumber(pct)}</span>
              </span>
            </div>
            <div className={styles.funnelTrack} aria-hidden="true">
              <div className={styles.funnelBar} style={{ width: `${pct}%` }} />
            </div>
          </li>
        );
      })}
    </ol>
  );
}
