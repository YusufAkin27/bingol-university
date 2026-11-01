// SAYFA: Analitik (/admin/analytics?tab=overview|growth|engagement|retention|demographics&from=&to=&dim=)
// API: /api/admin/analytics/{overview,registrations,active-users,breakdown,engagement,retention,support,push,content} (api/analytics.ts).
// KVKK: yalnızca toplulaştırılmış veri gösterilir. Sekmeler, tarih aralığı ve demografi boyutu URL'dedir.
import { useMemo } from 'react';
import { useParams, useSearchParams } from 'react-router-dom';
import type { BreakdownDimension } from '../../api/types';
import { DateRangePicker, Icon, Insight, PageHeader, Switch, Tabs, type DateRangeValue } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { useGt } from './dashboard/dict';
import { lastDays } from '../../lib/date';
import { useSearchReveal } from '../../search/anchor';
import { usePageTitle } from '../../lib/hooks';
import styles from './analytics/analytics.module.css';
import DemographicsTab from './analytics/DemographicsTab';
import EngagementTab from './analytics/EngagementTab';
import GrowthTab from './analytics/GrowthTab';
import OverviewTab from './analytics/OverviewTab';
import RetentionTab from './analytics/RetentionTab';
import { clampRange, DIMENSIONS, parseTab, previousRange, rangeDays, TABS, type TabId } from './analytics/transform';

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const RANGE_TABS: TabId[] = ['overview', 'growth', 'engagement'];
const TAB_OF_ANCHOR: Record<string, TabId> = {
  'anl-today': 'overview',
  'anl-dau': 'overview',
  'anl-reg': 'overview',
  'anl-content': 'overview',
  'anl-support': 'overview',
  'anl-push': 'overview',
  'anl-compare-toggle': 'overview',
  'anl-growth-reg': 'growth',
  'anl-growth-cum': 'growth',
  'anl-daily': 'engagement',
  'anl-compare': 'growth',
  'anl-funnel': 'engagement',
  'anl-events': 'engagement',
  'anl-screens': 'engagement',
  'anl-retention': 'retention',
  'anl-demo-dims': 'demographics',
};

export default function AnalyticsPage() {
  const { t, formatDate, formatNumber } = useI18n();
  const g = useGt();
  usePageTitle(t('admin.analytics.title'));
  const [sp, setSp] = useSearchParams();
  const params = useParams();

  // `?tab=` önceliklidir; eski `/analytics/:tab` yolu da kabul edilir
  const tab = parseTab(sp.get('tab') ?? params.tab);
  const defaults = useMemo(() => lastDays(30), []);
  const rawFrom = DATE_RE.test(sp.get('from') ?? '') ? (sp.get('from') as string) : defaults.from;
  const rawTo = DATE_RE.test(sp.get('to') ?? '') ? (sp.get('to') as string) : defaults.to;
  // ters ya da 366 günden uzun aralık güvenli hâle getirilir (sunucu 400 döndürmesin)
  const { from, to, swapped, clipped } = useMemo(() => clampRange(rawFrom, rawTo), [rawFrom, rawTo]);
  // karşılaştırma varsayılan AÇIK; kapatmak için ?cmp=0
  const compare = sp.get('cmp') !== '0';
  const dimParam = sp.get('dim');
  const dimension: BreakdownDimension = (DIMENSIONS as readonly string[]).includes(dimParam ?? '')
    ? (dimParam as BreakdownDimension)
    : 'faculty';

  const patch = (changes: Record<string, string | null>) => {
    const next = new URLSearchParams(sp);
    for (const [k, v] of Object.entries(changes)) {
      if (v === null) next.delete(k);
      else next.set(k, v);
    }
    setSp(next, { replace: true });
  };

  // arama derin bağlantısı: anchor hangi sekmedeyse o sekme açılır (aynı sekmeyi tekrar atamak etkisizdir)
  useSearchReveal((anchor) => {
    const target = TAB_OF_ANCHOR[anchor];
    if (target && target !== tab) patch({ tab: target });
  });

  const range: DateRangeValue = useMemo(() => ({ from, to }), [from, to]);
  const prev = compare ? previousRange(range) : null;
  const shortDate = (d: string) => formatDate(d, { day: 'numeric', month: 'short' });
  const showRange = RANGE_TABS.includes(tab);

  return (
    <div>
      <PageHeader title={t('admin.analytics.title')} />
      <details className={styles.kvkkBox} data-search-anchor="anl-kvkk">
        <summary className={styles.kvkkSummary}>
          <Icon name="shield" size={18} aria-hidden="true" />
          <span>{t('admin.v2p.anl.kvkkShort')}</span>
        </summary>
        <p className={styles.kvkk} role="note">
          <span>{t('admin.analytics.kvkk')}</span>
        </p>
      </details>

      <Tabs
        label={t('admin.analytics.tabs.label')}
        value={tab}
        onChange={(id) => patch({ tab: id })}
        tabs={TABS.map((id) => ({ id, label: t(`admin.analytics.tab.${id}`) }))}
      >
        {showRange && (
          <div className={styles.controls} data-search-anchor="anl-range">
            <DateRangePicker
              value={range}
              onChange={(r) => patch({ from: r.from || null, to: r.to || null })}
            />
            {tab !== 'engagement' && (
              <div className={styles.compareToggle} data-search-anchor="anl-compare-toggle">
                <Switch
                  checked={compare}
                  onChange={(on) => patch({ cmp: on ? null : '0' })}
                  label={g('admin.genel.anl.compare')}
                />
              </div>
            )}
            <p className={styles.rangeNote} data-testid="range-note">
              {g('admin.genel.anl.rangeSummary', {
                days: formatNumber(rangeDays(range)),
                from: shortDate(from),
                to: shortDate(to),
              })}
              {prev && tab !== 'engagement' && (
                <> {g('admin.genel.anl.compareHint', { from: shortDate(prev.from), to: shortDate(prev.to) })}</>
              )}
            </p>
            {(swapped || clipped) && (
              <div className={styles.rangeNote}>
                <Insight tone="warn" parts={clipped ? g('admin.genel.anl.rangeClipped') : g('admin.genel.anl.rangeSwapped')} />
              </div>
            )}
          </div>
        )}
        {tab === 'overview' && <OverviewTab range={range} compare={compare} />}
        {tab === 'growth' && <GrowthTab range={range} compare={compare} />}
        {tab === 'engagement' && <EngagementTab range={range} />}
        {tab === 'retention' && <RetentionTab />}
        {tab === 'demographics' && (
          <DemographicsTab dimension={dimension} onDimensionChange={(d) => patch({ dim: d })} />
        )}
      </Tabs>
    </div>
  );
}
