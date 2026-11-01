// Topluluk/akademik/içerik sayfaları ortak "özet şeridi" kapları: sayı kutuları ızgarası + tek cümlelik yorum.
// Yalnız yerleşim; sayı kutusu ve yorum kit bileşenleridir (StatTile, Insight).
import type { ReactNode } from 'react';
import { Badge } from '../../../components/ui/Badge';
import { useIsNarrow } from '../../../components/ui/useIsNarrow';
import styles from './summary.module.css';

/** Sayı kutuları ızgarası: telefonda 2 sütun, geniş ekranda otomatik sığar. */
export function SummaryGrid({ children, label }: { children: ReactNode; label?: string }) {
  return (
    <div className={styles.grid} role="group" aria-label={label}>
      {children}
    </div>
  );
}

/** Özet şeridi: yorum cümlesi üstte, sayı kutuları altta. */
export function SummaryStrip({
  insight,
  children,
  label,
}: {
  insight?: ReactNode;
  children?: ReactNode;
  label?: string;
}) {
  return (
    <section className={styles.strip} aria-label={label}>
      {insight}
      {children ? <SummaryGrid>{children}</SummaryGrid> : null}
    </section>
  );
}

/** Yığılmış yatay çubuk (renk + yazı): her parça etiketi ve sayısı altında yazılır. */
export interface StackPart {
  key: string;
  label: string;
  value: number;
  tone: 'success' | 'warning' | 'danger' | 'info' | 'neutral';
}

export function StackedBar({ parts, ariaLabel }: { parts: StackPart[]; ariaLabel: string }) {
  const total = parts.reduce((s, p) => s + p.value, 0);
  if (total <= 0) return null;
  return (
    <div className={styles.stack}>
      <div className={styles.stackBar} role="img" aria-label={ariaLabel}>
        {parts
          .filter((p) => p.value > 0)
          .map((p) => (
            <span key={p.key} className={`${styles.seg} ${styles[`seg_${p.tone}`]}`} style={{ flexGrow: p.value }} />
          ))}
      </div>
      <ul className={styles.stackLegend}>
        {parts
          .filter((p) => p.value > 0)
          .map((p) => (
            <li key={p.key}>
              <span className={`${styles.swatch} ${styles[`seg_${p.tone}`]}`} aria-hidden="true" />
              {p.label}: <strong>{p.value}</strong>
            </li>
          ))}
      </ul>
    </div>
  );
}

/** Doluluk çubuğu: değer/üst sınır, yüzde yazısı ve eşik rengi (dolu = uyarı). Renge ek olarak metin taşır. */
export function FillBar({
  value,
  max,
  label,
  tone,
}: {
  value: number;
  max: number;
  label: string;
  tone?: 'success' | 'warning' | 'danger' | 'info';
}) {
  const ratio = max > 0 ? Math.min(1, Math.max(0, value / max)) : 0;
  const pct = Math.round(ratio * 100);
  const auto = tone ?? (ratio >= 1 ? 'danger' : ratio >= 0.85 ? 'warning' : 'info');
  return (
    <span className={styles.fill}>
      <span
        className={styles.fillTrack}
        role="progressbar"
        aria-label={label}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={pct}
      >
        <span className={`${styles.fillBar} ${styles[`seg_${auto}`]}`} style={{ inlineSize: `${pct}%` }} />
      </span>
      <span className={styles.fillText}>{label}</span>
    </span>
  );
}

/**
 * Süzgeç kabı: geniş ekranda olduğu gibi gösterir; telefonda “Süzgeçler (2)” başlıklı katlanır kutuya alır
 * (liste ilk ekranda görünsün). Arama derin bağlantısı kapalı kutuyu otomatik açar (<details>).
 */
export function CollapsibleFilters({
  label,
  activeCount,
  children,
}: {
  label: string;
  activeCount: number;
  children: ReactNode;
}) {
  const narrow = useIsNarrow();
  if (!narrow) return <>{children}</>;
  return (
    <details className={styles.filters}>
      <summary className={styles.filtersSummary}>
        {label}
        {activeCount > 0 && <Badge tone="info">{activeCount}</Badge>}
      </summary>
      <div className={styles.filtersBody}>{children}</div>
    </details>
  );
}
