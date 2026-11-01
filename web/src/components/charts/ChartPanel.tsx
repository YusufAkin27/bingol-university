import { useId, useState, type ReactElement, type ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Button } from '../ui/Button';
import { ChartLegend, type LegendItem } from '../ui/ChartLegend';
import { EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { Insight, type InsightPart, type InsightTone } from '../ui/Insight';
import { ChartDescriptionContext } from './ChartFrame';
import styles from './ChartPanel.module.css';

export interface ChartTableColumn {
  key: string;
  header: string;
  align?: 'start' | 'end';
}

export interface ChartTableData {
  columns: ChartTableColumn[];
  rows: Record<string, ReactNode>[];
}

export interface ChartPanelProps {
  /** Düz Türkçe başlık: "Günlük giren kişi" (DAU değil). */
  title: string;
  /** Başlığın altındaki tek cümlelik yorum: "Bugün 120 kişi girdi, dün 98 idi: %22 fazla". */
  insight?: InsightPart[] | string;
  insightTone?: InsightTone;
  /** Grafik bileşeni (LineAreaChart, BarChart, DonutChart, FunnelChart...). Çerçevesi yorumu aria-describedby ile bağlar. */
  children: ReactElement;
  /** Grafik verisinin tablo hâli: "Veriyi tablo olarak göster" düğmesiyle açılır (erişilebilir alternatif). */
  table?: ChartTableData;
  legend?: LegendItem[];
  /** Başlığın yanındaki eylemler (dışa aktar, aralık seçici...). */
  actions?: ReactNode;
  loading?: boolean;
  error?: boolean;
  onRetry?: () => void;
  /** Veri yok: grafik yerine anlaşılır boş durum. */
  empty?: boolean;
  emptyLabel?: string;
  /** Grafiğin altına küçük açıklama ("Veriler her gece yenilenir"). */
  footnote?: ReactNode;
  /** Yükleme iskeletinin yüksekliği (px). */
  height?: number;
  className?: string;
}

/**
 * Grafik paneli: başlık + tek cümlelik yorum + grafik + renk açıklaması + "veriyi tablo olarak göster".
 * Yükleniyor/boş/hata hâlleri anlaşılır cümlelerle gelir. Grafiğe ayrıca `ariaLabel` verin (ChartFrame).
 */
export function ChartPanel({
  title,
  insight,
  insightTone,
  children,
  table,
  legend,
  actions,
  loading,
  error,
  onRetry,
  empty,
  emptyLabel,
  footnote,
  height = 260,
  className,
}: ChartPanelProps) {
  const { t } = useI18n();
  const uid = useId();
  const titleId = `${uid}-title`;
  const insightId = `${uid}-insight`;
  const tableId = `${uid}-table`;
  const [showTable, setShowTable] = useState(false);
  const hasInsight = !!insight && insight.length > 0;
  const ready = !loading && !error && !empty;

  return (
    <section className={`${styles.panel} ${className ?? ''}`} aria-labelledby={titleId}>
      <header className={styles.head}>
        <h2 id={titleId} className={styles.title}>
          {title}
        </h2>
        {actions && <div className={styles.actions}>{actions}</div>}
      </header>
      {hasInsight && ready && <Insight id={insightId} parts={insight} tone={insightTone} />}
      <div className={styles.body}>
        {loading ? (
          <div role="status" aria-label={t('admin.kit.chart.loading')}>
            <Skeleton width="100%" height={height} radius="var(--radius-md)" />
          </div>
        ) : error ? (
          <ErrorState compact onRetry={onRetry} />
        ) : empty ? (
          <EmptyState icon="chart" compact title={emptyLabel ?? t('admin.kit.state.emptyChart')} />
        ) : (
          <ChartDescriptionContext.Provider value={hasInsight ? insightId : undefined}>
            {children}
          </ChartDescriptionContext.Provider>
        )}
      </div>
      {ready && legend && legend.length > 0 && <ChartLegend items={legend} />}
      {ready && table && (
        <div className={styles.tableArea}>
          <Button
            variant="ghost"
            size="md"
            aria-expanded={showTable}
            aria-controls={tableId}
            onClick={() => setShowTable((v) => !v)}
          >
            {t(showTable ? 'admin.kit.chart.hideTable' : 'admin.kit.chart.showTable')}
          </Button>
          <div id={tableId} hidden={!showTable}>
            {showTable && (
              <div className={styles.tableScroll} tabIndex={0} role="region" aria-label={title}>
                <table className={styles.table}>
                  <caption className="sr-only">{t('admin.kit.chart.tableCaption', { title })}</caption>
                  <thead>
                    <tr>
                      {table.columns.map((c) => (
                        <th key={c.key} scope="col" className={c.align === 'end' ? styles.end : undefined}>
                          {c.header}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {table.rows.map((row, i) => (
                      <tr key={i}>
                        {table.columns.map((c) => (
                          <td key={c.key} className={c.align === 'end' ? styles.end : undefined}>
                            {row[c.key]}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}
      {footnote && <p className={styles.footnote}>{footnote}</p>}
    </section>
  );
}
