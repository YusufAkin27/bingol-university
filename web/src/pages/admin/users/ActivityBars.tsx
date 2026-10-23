import { useI18n } from '../../../i18n/I18nProvider';
import styles from './users.module.css';

interface Props {
  data: { day: string; opens: number }[];
}

/** Günlük açılış sayıları için hafif çubuk grafik (recharts gerektirmez); değerler başlık ve metin listesinde de verilir. */
export function ActivityBars({ data }: Props) {
  const { t, formatDate, formatNumber } = useI18n();
  if (data.length === 0) return <p className={styles.hint}>{t('admin.users.detail.noActivity')}</p>;
  const sorted = [...data].sort((a, b) => a.day.localeCompare(b.day));
  const max = Math.max(...sorted.map((d) => d.opens), 1);
  const total = sorted.reduce((s, d) => s + d.opens, 0);
  const label = `${t('admin.users.detail.activity')}: ${t('admin.users.detail.opens', { n: formatNumber(total) })}`;
  return (
    <div>
      <div className={styles.bars} role="img" aria-label={label}>
        {sorted.map((d) => (
          <span
            key={d.day}
            className={styles.bar}
            style={{ height: `${Math.max(6, (d.opens / max) * 100)}%` }}
            title={`${formatDate(d.day)}: ${t('admin.users.detail.opens', { n: formatNumber(d.opens) })}`}
          />
        ))}
      </div>
      <div className={styles.barAxis} aria-hidden="true">
        <span>{formatDate(sorted[0].day, { day: 'numeric', month: 'short' })}</span>
        <span>{formatDate(sorted[sorted.length - 1].day, { day: 'numeric', month: 'short' })}</span>
      </div>
    </div>
  );
}
