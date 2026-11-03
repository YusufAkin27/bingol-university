import type { UseQueryResult } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { Button, ErrorState, Skeleton } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import styles from './behavior.module.css';
import {
  activePreset,
  clampRange,
  MAX_RANGE_DAYS,
  presetRange,
  RANGE_PRESETS,
  rangeDays,
  type Range,
} from './format';

/** Tarih aralığı çubuğu: hazır seçimler (7/14/30/45 gün) + özel aralık (en çok 45 gün, ters seçim düzeltilir). */
export function BehaviorRangeBar({ value, onChange }: { value: Range; onChange: (r: Range) => void }) {
  const { t } = useI18n();
  const active = activePreset(value);
  const days = rangeDays(value);
  const today = presetRange(1).to;
  return (
    <div className={styles.rangeBar} data-search-anchor="anl-behavior-range">
      <div className={styles.presets} role="group" aria-label={t('admin.bh.range.label')}>
        {RANGE_PRESETS.map((d) => (
          <Button
            key={d}
            size="sm"
            variant={active === d ? 'primary' : 'secondary'}
            aria-pressed={active === d}
            onClick={() => onChange(presetRange(d))}
          >
            {t('admin.bh.range.lastDays', { n: String(d) })}
          </Button>
        ))}
      </div>
      <label className={styles.dateField}>
        <span>{t('admin.bh.range.from')}</span>
        <input
          type="date"
          value={value.from}
          max={value.to || today}
          onChange={(e) => e.target.value && onChange(clampRange({ from: e.target.value, to: value.to }))}
        />
      </label>
      <label className={styles.dateField}>
        <span>{t('admin.bh.range.to')}</span>
        <input
          type="date"
          value={value.to}
          min={value.from || undefined}
          max={today}
          onChange={(e) => e.target.value && onChange(clampRange({ from: value.from, to: e.target.value }))}
        />
      </label>
      <p className={styles.rangeHint}>
        {t('admin.bh.range.hint', { days: String(days), max: String(MAX_RANGE_DAYS) })}
      </p>
    </div>
  );
}

/** Sorgu durumlarını yönetir: yükleniyor (iskelet), hata (neden + tekrar dene), veri. */
export function Boundary<T>({
  query,
  subject,
  height = 200,
  children,
}: {
  query: UseQueryResult<T>;
  subject: string;
  height?: number;
  children: (data: T) => ReactNode;
}) {
  if (query.isError && !query.data) {
    return <ErrorState compact subject={subject} error={query.error} onRetry={() => void query.refetch()} />;
  }
  if (!query.data) {
    return (
      <div aria-busy="true">
        <Skeleton height={height} width="100%" radius="var(--radius-sm)" style={{ display: 'block' }} />
      </div>
    );
  }
  return <>{children(query.data)}</>;
}

/** Sayı + ısı çubuğu hücresi (çubuk süs; değer her zaman yazılıdır). */
export function HeatCell({ text, ratio, tone = 'primary' }: { text: ReactNode; ratio: number; tone?: 'primary' | 'warn' }) {
  return (
    <span className={styles.heatCell}>
      <span className={styles.heatText}>{text}</span>
      <span className={styles.heatTrack} aria-hidden="true">
        <span
          className={`${styles.heatFill} ${tone === 'warn' ? styles.heatWarn : ''}`}
          style={{ inlineSize: `${Math.round(Math.max(0, Math.min(1, ratio)) * 100)}%` }}
        />
      </span>
    </span>
  );
}

/** Sayfa tabanlı listelerde toplam sayfa sayısı. */
export const totalPagesOf = (total: number, size: number) => Math.max(1, Math.ceil(total / size));
