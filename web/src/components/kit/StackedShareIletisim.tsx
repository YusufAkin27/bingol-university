// Yığılmış dağılım çubuğu (recharts GEREKTİRMEZ): bir bütünün parçalarını tek şeritte gösterir.
// Renk tek başına anlam taşımaz: her parça farklı DESEN + açıklama satırında metin, değer ve yüzde taşır.
// Kullanım: talep durumları, kuyruk sağlığı, bastırma nedenleri, kampanya durumları.
import { useId } from 'react';
import { Icon } from '../ui/Icon';
import { useI18n } from '../../i18n/I18nProvider';
import styles from './StackedShareIletisim.module.css';

export type ShareTone = 'success' | 'warning' | 'danger' | 'info' | 'neutral' | 'primary';

export interface ShareSegment {
  key: string;
  label: string;
  value: number;
  tone: ShareTone;
  /** Açıklama satırında etiketin altına yazılan kısa not. */
  hint?: string;
}

export interface StackedShareProps {
  segments: ShareSegment[];
  /** Şeridin erişilebilir adı: "Talep durumu dağılımı". */
  ariaLabel: string;
  /** Verilirse açıklama satırları düğme olur (örn. süzgeçi o duruma çevirmek için). */
  onSelect?: (key: string) => void;
  /** Seçili parça (düğme kipinde vurgulanır). */
  selectedKey?: string | null;
  /** Değer yazısı (varsayılan: yerel sayı). */
  formatValue?: (n: number) => string;
  className?: string;
}

const TONE_CLASS: Record<ShareTone, string> = {
  success: styles.success,
  warning: styles.warning,
  danger: styles.danger,
  info: styles.info,
  neutral: styles.neutral,
  primary: styles.primary,
};

/** Parça değerlerinin toplamı; negatif ve geçersiz değerler 0 sayılır. */
export function shareTotal(segments: ShareSegment[]): number {
  return segments.reduce((s, x) => s + (Number.isFinite(x.value) && x.value > 0 ? x.value : 0), 0);
}

export function StackedShare({
  segments,
  ariaLabel,
  onSelect,
  selectedKey,
  formatValue,
  className,
}: StackedShareProps) {
  const { formatNumber } = useI18n();
  const uid = useId();
  const fmt = formatValue ?? ((n: number) => formatNumber(n));
  const clean = segments.map((s) => ({ ...s, value: Number.isFinite(s.value) && s.value > 0 ? s.value : 0 }));
  const total = shareTotal(clean);
  const pct = (v: number) =>
    total > 0 ? formatNumber(v / total, { style: 'percent', maximumFractionDigits: 0 }) : '–';
  const summary = clean.map((s) => `${s.label}: ${fmt(s.value)} (${pct(s.value)})`).join(', ');

  return (
    <div className={`${styles.root} ${className ?? ''}`}>
      <div className={styles.bar} role="img" aria-label={`${ariaLabel}. ${summary}`}>
        {total === 0 ? (
          <span className={styles.emptyBar} />
        ) : (
          clean
            .filter((s) => s.value > 0)
            .map((s) => (
              <span
                key={s.key}
                className={`${styles.seg} ${TONE_CLASS[s.tone]}`}
                style={{ flexGrow: s.value }}
                title={`${s.label}: ${fmt(s.value)}`}
              />
            ))
        )}
      </div>
      <ul className={styles.legend} aria-label={ariaLabel}>
        {clean.map((s) => {
          const body = (
            <>
              <span className={`${styles.swatch} ${TONE_CLASS[s.tone]}`} aria-hidden="true" />
              <span className={styles.text}>
                <span className={styles.label}>{s.label}</span>
                {s.hint && <span className={styles.hint}>{s.hint}</span>}
              </span>
              <span className={styles.nums}>
                <strong className="ltr">{fmt(s.value)}</strong>
                <span className={styles.share}>{pct(s.value)}</span>
              </span>
              {onSelect && <Icon name="chevronRight" size={16} aria-hidden="true" className={styles.go} />}
            </>
          );
          return (
            <li key={s.key} id={`${uid}-${s.key}`}>
              {onSelect ? (
                <button
                  type="button"
                  className={`${styles.row} ${styles.rowBtn} ${selectedKey === s.key ? styles.rowOn : ''}`}
                  aria-pressed={selectedKey === s.key}
                  onClick={() => onSelect(s.key)}
                >
                  {body}
                </button>
              ) : (
                <div className={styles.row}>{body}</div>
              )}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
