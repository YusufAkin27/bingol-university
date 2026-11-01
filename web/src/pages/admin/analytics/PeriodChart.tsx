// Analitik: günlük zaman serisi + tek cümle yorum + (isteğe bağlı) önceki dönem çizgisi. DAU, günlük kayıt ve kümülatif grafikleri bunu kullanır.
import type { ReactNode } from 'react';
import { LineAreaChart } from '../../../components/charts';
import { useCompareSentence, type Column, type InsightPart, type InsightTone } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useGt } from '../dashboard/dict';
import styles from './analytics.module.css';
import { ChartCard } from './parts';
import { mergePrevious, seriesStats } from './transform';

interface Point {
  date: string;
  value: number;
}

interface Props {
  title: string;
  /** Arama derin bağlantısı için bölüm kimliği (anl-...). */
  anchor: string;
  points: Point[];
  /** Önceki dönem (aynı uzunlukta); yoksa ya da kapalıysa tek çizgi çizilir. */
  prevPoints?: Point[];
  seriesLabel: string;
  color?: string;
  /** avg: günlük ortalama karşılaştırılır (giren kişi); sum: dönem toplamı (katılan kişi). */
  mode: 'avg' | 'sum';
  /** Cümledeki eylem: "girdi", "katıldı". */
  verb: string;
  /** Grafiğin üstündeki küçük kutular (haftalık/aylık aktif gibi). */
  extra?: ReactNode;
  /** Cümle yazılmasın (kümülatif seride "en yoğun gün" anlamsızdır). */
  noInsight?: boolean;
}

export function PeriodChart({ title, anchor, points, prevPoints, seriesLabel, color, mode, verb, extra, noInsight }: Props) {
  const { t, formatDate, formatNumber } = useI18n();
  const g = useGt();
  const sentence = useCompareSentence();
  const fmt = (v: string | number) => formatDate(String(v), { day: 'numeric', month: 'short' });

  const rows = mergePrevious(points, prevPoints, (p) => p.value);
  const hasPrev = !!prevPoints && prevPoints.length > 0;
  const stats = seriesStats(points.map((p) => p.value));
  const prevStats = hasPrev ? seriesStats(prevPoints.map((p) => p.value)) : null;

  let insight: { parts: InsightPart[]; tone: InsightTone } | null = null;
  if (!noInsight && stats.peakIndex >= 0 && stats.total > 0) {
    if (prevStats) {
      const cmp = sentence({
        nowLabel: g(mode === 'avg' ? 'admin.genel.anl.cmpNowAvg' : 'admin.genel.anl.cmpNowSum'),
        current: mode === 'avg' ? stats.avg : stats.total,
        thenLabel: g('admin.genel.anl.cmpThen'),
        previous: mode === 'avg' ? prevStats.avg : prevStats.total,
        unit: t('admin.v2p.unit.person'),
        verb,
      });
      insight = cmp;
    } else {
      const day = fmt(points[stats.peakIndex].date);
      insight = {
        tone: 'info',
        parts: [
          g(mode === 'avg' ? 'admin.genel.anl.plainAvg' : 'admin.genel.anl.plainSum', {
            n: formatNumber(mode === 'avg' ? stats.avg : stats.total),
            verb,
            day,
            peak: formatNumber(stats.peak),
          }),
        ],
      };
    }
  }

  const columns: Column<(typeof rows)[number]>[] = [
    { key: 'date', header: t('admin.analytics.table.date'), render: (r) => formatDate(r.date) },
    {
      key: 'value',
      header: seriesLabel,
      align: 'end',
      render: (r) => <span className={styles.num}>{formatNumber(r.value)}</span>,
    },
    ...(hasPrev
      ? [
          {
            key: 'prev',
            header: g('admin.genel.anl.prevSeries'),
            align: 'end' as const,
            render: (r: (typeof rows)[number]) => (
              <span className={styles.num}>{r.prev === undefined ? '—' : formatNumber(r.prev)}</span>
            ),
          },
        ]
      : []),
  ];

  return (
    <div data-search-anchor={anchor}>
      <ChartCard title={title} rows={rows} rowKey={(r) => r.date} columns={columns} insight={insight}>
        {extra}
        <LineAreaChart
          data={rows}
          xKey="date"
          area={!hasPrev}
          series={[
            { key: 'value', label: seriesLabel, color },
            ...(hasPrev ? [{ key: 'prev', label: g('admin.genel.anl.prevSeries'), color: 'var(--chart-4)' }] : []),
          ]}
          ariaLabel={title}
          formatX={fmt}
          emptyLabel={t('admin.analytics.chart.noData')}
        />
      </ChartCard>
    </div>
  );
}
