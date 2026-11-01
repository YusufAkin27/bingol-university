// Yığılmış oran çubuğu + renk açıklaması: iki-üç parçalı dağılımı (örn. "yönetici gizledi / sistem gizledi") sayı duvarı olmadan gösterir.
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './yaptirim.module.css';

export interface MixPart {
  key: string;
  label: string;
  value: number;
}

const COLORS = [styles.chart1, styles.chart2, styles.chart3, styles.chart4, styles.chart5];

export function MixBar({ parts, ariaLabel }: { parts: MixPart[]; ariaLabel: string }) {
  const { formatNumber } = useI18n();
  const total = parts.reduce((n, p) => n + Math.max(0, p.value), 0);
  if (total <= 0) return null;
  const summary = parts
    .filter((p) => p.value > 0)
    .map((p) => `${p.label}: ${formatNumber(p.value)}`)
    .join(', ');
  return (
    <div>
      <div className={styles.mix} role="img" aria-label={`${ariaLabel}. ${summary}`}>
        {parts.map((p, i) =>
          p.value > 0 ? (
            <span key={p.key} className={`${styles.mixPart} ${COLORS[i % COLORS.length]}`} style={{ flexGrow: p.value }} />
          ) : null,
        )}
      </div>
      <ul className={styles.legend}>
        {parts.map((p, i) => (
          <li key={p.key}>
            <span className={`${styles.swatch} ${COLORS[i % COLORS.length]}`} aria-hidden="true" />
            <span>{p.label}</span>
            <strong>{formatNumber(p.value)}</strong>
          </li>
        ))}
      </ul>
    </div>
  );
}
