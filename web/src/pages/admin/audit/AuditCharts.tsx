// Denetim kaydı özeti: zaman çizelgesi (kim ne zaman yoğundu), eylem türü dağılımı ve en çok işlem yapılan alanlar.
// recharts içerdiği için AuditPage bunu tembel yükler (React.lazy); sayfa ana paketine sızmaz.
import { useMemo } from 'react';
import type { AuditRowV2 } from '../../../api/audit';
import { BarChart } from '../../../components/charts/BarChart';
import { ChartPanel } from '../../../components/charts/ChartPanel';
import { DonutChart } from '../../../components/charts/DonutChart';
import { ErrorState } from '../../../components/ui/Feedback';
import { RankedBars } from '../../../components/ui/RankedBars';
import { useI18n } from '../../../i18n/I18nProvider';
import { bucketRows, summarize, VERB_CLASSES } from './auditStats';
import { useGt } from '../sys2Dict';
import styles from './audit2.module.css';

export default function AuditCharts({
  rows,
  loading,
  error,
  onRetry,
}: {
  rows: readonly AuditRowV2[] | undefined;
  loading: boolean;
  error: boolean;
  onRetry: () => void;
}) {
  const { td, formatNumber } = useI18n();
  const gt = useGt();
  const list = useMemo(() => rows ?? [], [rows]);
  const buckets = useMemo(() => bucketRows(list), [list]);
  const sum = useMemo(() => summarize(list, buckets), [list, buckets]);
  const empty = !loading && list.length === 0;

  const timelineData = buckets.buckets.map((b) => ({
    label: b.label,
    ok: b.total - b.denied,
    denied: b.denied,
  }));
  const unitName = gt(buckets.unit === 'hour' ? 'admin.sys2.audit.unit.hour' : 'admin.sys2.audit.unit.day');

  const verbData = VERB_CLASSES.map((v) => ({ name: gt(`admin.sys2.audit.verb.${v}`), value: sum.byVerb[v] })).filter(
    (d) => d.value > 0,
  );
  const writes = sum.byVerb.CREATE + sum.byVerb.CHANGE + sum.byVerb.DELETE;
  const writePct = sum.total > 0 ? Math.round((writes / sum.total) * 100) : 0;

  const resLabel = (r: string) => td(`admin.sys2.audit.res.${r}`, r);
  const topRes = sum.byResource[0];

  // Tek hata kutusu (üç panelde üç "Tekrar dene" olmasın)
  if (error) return <ErrorState compact subject={gt('admin.sys2.audit.summary')} onRetry={onRetry} />;

  return (
    <div className={styles.charts} data-testid="audit-charts" data-search-anchor="audit-charts">
      <ChartPanel
        className={styles.chartWide}
        title={gt('admin.sys2.audit.timeline.title', { unit: unitName })}
        insight={
          sum.busiest
            ? gt('admin.sys2.audit.timeline.insight', {
                unit: unitName,
                label: sum.busiest.label,
                n: formatNumber(sum.busiest.total),
              })
            : undefined
        }
        // yalnız reddedilenler örneğin beşte birini aşarsa dikkat çek (birkaç yetkisiz deneme olağandır)
        insightTone={sum.total > 0 && sum.denied / sum.total >= 0.2 ? 'warn' : 'info'}
        loading={loading}
        error={error}
        onRetry={onRetry}
        empty={empty}
        emptyLabel={gt('admin.sys2.audit.chartEmpty')}
        height={220}
        footnote={gt('admin.sys2.audit.sampleNote', { n: formatNumber(list.length) })}
        table={{
          columns: [
            { key: 'when', header: gt('admin.sys2.audit.col.when') },
            { key: 'ok', header: gt('admin.sys2.audit.legend.ok'), align: 'end' },
            { key: 'denied', header: gt('admin.sys2.audit.legend.denied'), align: 'end' },
          ],
          rows: timelineData.map((d) => ({ when: d.label, ok: formatNumber(d.ok), denied: formatNumber(d.denied) })),
        }}
      >
        <BarChart
          data={timelineData}
          xKey="label"
          stacked
          height={220}
          series={[
            { key: 'ok', label: gt('admin.sys2.audit.legend.ok') },
            { key: 'denied', label: gt('admin.sys2.audit.legend.denied'), color: 'var(--danger)' },
          ]}
          ariaLabel={gt('admin.sys2.audit.timeline.aria')}
        />
      </ChartPanel>

      <ChartPanel
        title={gt('admin.sys2.audit.verb.title')}
        insight={
          writes === 0
            ? gt('admin.sys2.audit.verb.insightReadOnly')
            : gt('admin.sys2.audit.verb.insight', { p: formatNumber(writePct), n: formatNumber(writes) })
        }
        insightTone="info"
        loading={loading}
        error={error}
        onRetry={onRetry}
        empty={empty}
        emptyLabel={gt('admin.sys2.audit.chartEmpty')}
        height={220}
        table={{
          columns: [
            { key: 'verb', header: gt('admin.sys2.audit.col.verb') },
            { key: 'n', header: gt('admin.sys2.audit.col.count'), align: 'end' },
          ],
          rows: verbData.map((d) => ({ verb: d.name, n: formatNumber(d.value) })),
        }}
      >
        <DonutChart data={verbData} height={220} ariaLabel={gt('admin.sys2.audit.verb.aria')} />
      </ChartPanel>

      <section className={styles.rankPanel} aria-labelledby="audit-res-title">
        <h2 id="audit-res-title" className={styles.rankTitle}>
          {gt('admin.sys2.audit.res.title')}
        </h2>
        {topRes && !loading && !error && (
          <p className={styles.rankInsight}>
            {gt('admin.sys2.audit.res.insight', { res: resLabel(topRes.resource), n: formatNumber(topRes.count) })}
          </p>
        )}
        <RankedBars
          ariaLabel={gt('admin.sys2.audit.res.title')}
          items={sum.byResource.map((r) => ({ key: r.resource, label: resLabel(r.resource), value: r.count }))}
          limit={5}
          showShare
          loading={loading}
          error={error}
          onRetry={onRetry}
          emptyLabel={gt('admin.sys2.audit.chartEmpty')}
          formatValue={(n) => gt('admin.sys2.audit.res.value', { n: formatNumber(n) })}
        />
      </section>
    </div>
  );
}
