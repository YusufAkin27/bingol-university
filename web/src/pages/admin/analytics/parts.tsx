import type { UseQueryResult } from '@tanstack/react-query';
import { useId, useState, type ReactNode } from 'react';
import { Button, Card, ErrorState, Skeleton, Table, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';
import styles from './analytics.module.css';
import { cohortStyle, COHORT_LEVEL_MIX, isCohortMature } from './transform';

/** Sorgu durumlarını (yükleniyor / hata / veri) tek yerde yönetir; her kart bağımsızdır. */
export function Async<T>({
  query,
  children,
  height = 220,
}: {
  query: UseQueryResult<T>;
  children: (data: T) => ReactNode;
  height?: number;
}) {
  const i18n = useI18n();
  if (query.isError && !query.data) {
    return (
      <ErrorState compact description={errorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
    );
  }
  if (!query.data) {
    return <Skeleton height={height} width="100%" radius="var(--radius-sm)" style={{ display: 'block' }} />;
  }
  return <>{children(query.data)}</>;
}

interface ChartCardProps<T> {
  title: string;
  actions?: ReactNode;
  /** Grafiğin altında "tablo olarak göster" ile açılan erişilebilir veri tablosu. */
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string | number;
  children: ReactNode;
}

export function ChartCard<T>({ title, actions, columns, rows, rowKey, children }: ChartCardProps<T>) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const regionId = useId();
  return (
    <Card title={title} actions={actions}>
      {children}
      {rows.length > 0 && (
        <>
          <div className={styles.tableToggle}>
            <Button
              size="sm"
              variant="ghost"
              aria-expanded={open}
              aria-controls={regionId}
              onClick={() => setOpen((v) => !v)}
            >
              {open ? t('admin.analytics.table.hide') : t('admin.analytics.table.show')}
            </Button>
          </div>
          <div id={regionId} hidden={!open}>
            {open && (
              <div className={styles.tableWrap}>
                <Table caption={title} columns={columns} rows={rows} rowKey={rowKey} />
              </div>
            )}
          </div>
        </>
      )}
    </Card>
  );
}

export interface BarItem {
  key: string;
  label: string;
  value: number;
  percent?: number;
  muted?: boolean;
}

/** Kategori çubukları (CSS): uzun etiketler kırpılmadan alt satıra sarar, RTL'de otomatik yön değiştirir. */
export function BarList({ items, ariaLabel }: { items: BarItem[]; ariaLabel: string }) {
  const { formatNumber } = useI18n();
  const max = Math.max(...items.map((i) => i.value), 1);
  return (
    <ul className={styles.barList} aria-label={ariaLabel}>
      {items.map((i) => (
        <li key={i.key} className={styles.barRow}>
          <div className={styles.barHead}>
            <span className={`${styles.barLabel} ${i.muted ? styles.unknownTag : ''}`}>{i.label}</span>
            <span className={styles.barValue}>
              {formatNumber(i.value)}
              {i.percent !== undefined && (
                <span className={styles.barPct}>{formatNumber(i.percent, { maximumFractionDigits: 1 })}%</span>
              )}
            </span>
          </div>
          <div className={styles.barTrack} aria-hidden="true">
            <div
              className={`${styles.barFill} ${i.muted ? styles.barFillUnknown : ''}`}
              style={{ width: `${(i.value / max) * 100}%` }}
            />
          </div>
        </li>
      ))}
    </ul>
  );
}

export interface CohortData {
  weekStart: string;
  size: number;
  d1: number;
  d7: number;
  d30: number;
}

/** Kohort ısı haritası: D1/D7/D30; ölçülemeyen hücreler "–" gösterilir, her hücrede sayı yazılıdır. */
export function CohortHeat({ cohorts, today }: { cohorts: CohortData[]; today?: Date }) {
  const { t, formatNumber, formatDate } = useI18n();
  const cols = [
    { key: 'd1', days: 1, label: t('admin.analytics.retention.d1') },
    { key: 'd7', days: 7, label: t('admin.analytics.retention.d7') },
    { key: 'd30', days: 30, label: t('admin.analytics.retention.d30') },
  ] as const;
  return (
    <div>
      <div className={styles.cohortWrap}>
        <table className={styles.cohort} aria-label={t('admin.analytics.retention.title')}>
          <thead>
            <tr>
              <th scope="col">{t('admin.analytics.retention.week')}</th>
              <th scope="col">{t('admin.analytics.retention.size')}</th>
              {cols.map((c) => (
                <th key={c.key} scope="col">
                  {c.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {cohorts.map((c) => (
              <tr key={c.weekStart}>
                <th scope="row">{formatDate(c.weekStart, { day: 'numeric', month: 'short', year: 'numeric' })}</th>
                <td className={styles.num}>{formatNumber(c.size)}</td>
                {cols.map((col) => {
                  if (!isCohortMature(c.weekStart, col.days, today)) {
                    return (
                      <td
                        key={col.key}
                        className={styles.cohortPending}
                        title={t('admin.analytics.retention.pending')}
                        aria-label={t('admin.analytics.retention.pending')}
                      >
                        –
                      </td>
                    );
                  }
                  const v = c[col.key];
                  const s = cohortStyle(v);
                  return (
                    <td key={col.key} style={{ background: s.background, color: s.color }}>
                      <span className="ltr">%{formatNumber(Math.round(v))}</span>
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className={styles.legend} aria-hidden="true">
        <span>{t('admin.analytics.retention.legend')}</span>
        <span>0%</span>
        {COHORT_LEVEL_MIX.map((mix) => (
          <span
            key={mix}
            className={styles.legendStep}
            style={{ background: `color-mix(in srgb, var(--chart-1) ${mix}%, var(--surface))` }}
          />
        ))}
        <span>65%+</span>
      </div>
    </div>
  );
}
