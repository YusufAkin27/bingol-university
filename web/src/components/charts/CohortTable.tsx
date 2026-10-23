import { useI18n } from '../../i18n/I18nProvider';
import styles from './charts.module.css';

export interface CohortRow {
  /** Satır etiketi (örn. hafta başlangıcı) */
  label: string;
  size: number;
  /** Sütun başına yüzde (0-100) */
  values: (number | null)[];
}

interface Props {
  rows: CohortRow[];
  /** Sütun başlıkları (örn. ['D1','D7','D30']) */
  columns: string[];
  sizeLabel: string;
  ariaLabel: string;
  emptyLabel?: string;
}

/** Isı haritası benzeri kohort tablosu: hücre rengi yüzdeyle yoğunlaşır, değer her hücrede yazılıdır. */
export function CohortTable({ rows, columns, sizeLabel, ariaLabel, emptyLabel }: Props) {
  const { t, formatNumber } = useI18n();
  if (rows.length === 0) {
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
    <div className={styles.cohortWrap}>
      <table className={styles.cohort} aria-label={ariaLabel}>
        <thead>
          <tr>
            <th scope="col" />
            <th scope="col">{sizeLabel}</th>
            {columns.map((c) => (
              <th key={c} scope="col">
                {c}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.label}>
              <th scope="row" className="ltr">
                {r.label}
              </th>
              <td>{formatNumber(r.size)}</td>
              {r.values.map((v, i) => {
                if (v === null || v === undefined)
                  return (
                    <td key={i} className={styles.cohortEmpty}>
                      –
                    </td>
                  );
                const a = Math.min(Math.max(v, 0), 100) / 100;
                return (
                  <td
                    key={i}
                    style={{
                      background: `color-mix(in srgb, var(--chart-1) ${Math.round(8 + a * 80)}%, var(--surface))`,
                      color: a > 0.5 ? 'var(--primary-contrast)' : 'var(--text)',
                    }}
                  >
                    %{formatNumber(Math.round(v))}
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
