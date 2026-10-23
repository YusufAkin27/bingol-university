import { useI18n } from '../../i18n/I18nProvider';
import { lastDays } from '../../lib/date';
import { Button } from './Button';
import styles from './DateRangePicker.module.css';

export interface DateRangeValue {
  from: string;
  to: string;
}

interface Props {
  value: DateRangeValue;
  onChange: (next: DateRangeValue) => void;
  presets?: number[];
}

/** İki tarih alanı + hızlı seçimler (7/30/90 gün). Değerler `yyyy-MM-dd`. */
export function DateRangePicker({ value, onChange, presets = [7, 30, 90] }: Props) {
  const { t } = useI18n();
  const active = presets.find((d) => {
    const r = lastDays(d);
    return r.from === value.from && r.to === value.to;
  });
  const presetLabel = (d: number) =>
    d === 7
      ? t('common.range.last7')
      : d === 30
        ? t('common.range.last30')
        : d === 90
          ? t('common.range.last90')
          : `${d}`;
  return (
    <div className={styles.wrap}>
      <div className={styles.presets} role="group" aria-label={t('common.date')}>
        {presets.map((d) => (
          <Button
            key={d}
            size="sm"
            variant={active === d ? 'primary' : 'secondary'}
            aria-pressed={active === d}
            onClick={() => onChange(lastDays(d))}
          >
            {presetLabel(d)}
          </Button>
        ))}
      </div>
      <label className={styles.field}>
        <span>{t('common.from')}</span>
        <input
          type="date"
          value={value.from}
          max={value.to || undefined}
          onChange={(e) => onChange({ ...value, from: e.target.value })}
        />
      </label>
      <label className={styles.field}>
        <span>{t('common.to')}</span>
        <input
          type="date"
          value={value.to}
          min={value.from || undefined}
          onChange={(e) => onChange({ ...value, to: e.target.value })}
        />
      </label>
    </div>
  );
}
