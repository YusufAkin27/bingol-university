// Rapor kuyruğu görselleri: bekleme süresi dağılımı, aciliyet dağılımı ve şikâyet edilen tür sıralaması.
// Veri: ReportsPage'in yüklediği açık raporlar (ek istek yok). Sunucuda daha fazlası varsa bu açıkça yazılır.
import { useMemo } from 'react';
import type { ReportView } from '../../../api/types';
import { Insight, RankedBars } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useGt } from './dict';
import { AGE_BUCKETS, LEVELS, ageCounts, levelCounts } from './reportCharts';
import { StackedShare, type ShareSegment, type ShareTone } from './StackedShare';
import styles from './mod2.module.css';

const AGE_TONE: Record<string, ShareTone> = { fresh: 'success', d1_3: 'info', d3_7: 'warning', old: 'danger' };
const LEVEL_TONE: Record<string, ShareTone> = { URGENT: 'danger', HIGH: 'warning', NORMAL: 'neutral' };

export function ReportQueueCharts({
  items,
  hasMore,
  now,
  typeLabel,
}: {
  items: ReportView[];
  hasMore: boolean;
  /** Test edilebilirlik için dışarıdan verilebilir. */
  now?: number;
  typeLabel: (type: string) => string;
}) {
  const t = useGt();
  const { formatNumber } = useI18n();
  const at = now ?? Date.now();
  const ages = useMemo(() => ageCounts(items, at), [items, at]);
  const levels = useMemo(() => levelCounts(items), [items]);
  const typeBars = useMemo(() => {
    const m = new Map<string, number>();
    for (const r of items) m.set(r.targetType, (m.get(r.targetType) ?? 0) + 1);
    return [...m].map(([k, v]) => ({ key: k, label: typeLabel(k), value: v }));
  }, [items, typeLabel]);

  const ageSegs: ShareSegment[] = AGE_BUCKETS.map((b) => ({
    key: b,
    label: t(`admin.mod2.reports.age.${b}`),
    value: ages[b],
    tone: AGE_TONE[b],
  }));
  const levelSegs: ShareSegment[] = LEVELS.map((l) => ({
    key: l,
    label: t(`admin.mod2.reports.level.${l}`),
    value: levels[l],
    tone: LEVEL_TONE[l],
  }));

  return (
    <section aria-label={t('admin.mod2.reports.chartsLabel')} data-search-anchor="reports-charts">
      <Insight
        className={styles.clip}
        tone={ages.old > 0 ? 'warn' : 'good'}
        parts={
          ages.old > 0
            ? [{ text: t('admin.mod2.reports.sentenceOld', { n: formatNumber(ages.old) }), tone: 'warn' }]
            : [t('admin.mod2.reports.sentenceFresh')]
        }
      />
      <div className={styles.chartGrid}>
        <div className={styles.chartCard} data-search-anchor="reports-age-chart">
          <h2 className={styles.chartTitle}>{t('admin.mod2.reports.ageTitle')}</h2>
          <p className={styles.chartHint}>{t('admin.mod2.reports.ageHint')}</p>
          <StackedShare segments={ageSegs} ariaLabel={t('admin.mod2.reports.ageTitle')} />
        </div>
        <div className={styles.chartCard} data-search-anchor="reports-level-chart">
          <h2 className={styles.chartTitle}>{t('admin.mod2.reports.levelTitle')}</h2>
          <p className={styles.chartHint}>{t('admin.mod2.reports.levelHint')}</p>
          <StackedShare segments={levelSegs} ariaLabel={t('admin.mod2.reports.levelTitle')} />
        </div>
        {typeBars.length > 1 && (
          <div className={styles.chartCard} data-search-anchor="reports-type-chart">
            <h2 className={styles.chartTitle}>{t('admin.mod2.reports.typeTitle')}</h2>
            <RankedBars items={typeBars} limit={5} ariaLabel={t('admin.mod2.reports.typeTitle')} />
          </div>
        )}
      </div>
      {hasMore && <p className={styles.chartHint}>{t('admin.mod2.reports.partial', { n: formatNumber(items.length) })}</p>}
    </section>
  );
}
