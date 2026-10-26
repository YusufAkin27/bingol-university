// SAYFA: Analitik (/admin/analytics?tab=overview|growth|engagement|retention|demographics&from=&to=&dim=)
// API: /api/admin/analytics/{overview,registrations,active-users,breakdown,engagement,retention,support,push,content} (api/analytics.ts).
// KVKK: yalnızca toplulaştırılmış veri gösterilir. Sekmeler, tarih aralığı ve demografi boyutu URL'dedir.
import { useMemo } from 'react';
import { useParams, useSearchParams } from 'react-router-dom';
import type { BreakdownDimension } from '../../api/types';
import { DateRangePicker, Icon, PageHeader, Tabs, type DateRangeValue } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { lastDays } from '../../lib/date';
import { usePageTitle } from '../../lib/hooks';
import styles from './analytics/analytics.module.css';
import DemographicsTab from './analytics/DemographicsTab';
import EngagementTab from './analytics/EngagementTab';
import GrowthTab from './analytics/GrowthTab';
import OverviewTab from './analytics/OverviewTab';
import RetentionTab from './analytics/RetentionTab';
import { DIMENSIONS, parseTab, TABS, type TabId } from './analytics/transform';

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const RANGE_TABS: TabId[] = ['overview', 'growth', 'engagement'];

export default function AnalyticsPage() {
  const { t } = useI18n();
  usePageTitle(t('admin.analytics.title'));
  const [sp, setSp] = useSearchParams();
  const params = useParams();

  // `?tab=` önceliklidir; eski `/analytics/:tab` yolu da kabul edilir
  const tab = parseTab(sp.get('tab') ?? params.tab);
  const defaults = useMemo(() => lastDays(30), []);
  const from = DATE_RE.test(sp.get('from') ?? '') ? (sp.get('from') as string) : defaults.from;
  const to = DATE_RE.test(sp.get('to') ?? '') ? (sp.get('to') as string) : defaults.to;
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

  const range: DateRangeValue = { from, to };
  const showRange = RANGE_TABS.includes(tab);

  return (
    <div>
      <PageHeader title={t('admin.analytics.title')} />
      <p className={styles.kvkk} role="note">
        <Icon name="shield" size={18} />
        <span>{t('admin.analytics.kvkk')}</span>
      </p>

      <Tabs
        label={t('admin.analytics.tabs.label')}
        value={tab}
        onChange={(id) => patch({ tab: id })}
        tabs={TABS.map((id) => ({ id, label: t(`admin.analytics.tab.${id}`) }))}
      >
        {showRange && (
          <div className={styles.controls}>
            <DateRangePicker
              value={range}
              onChange={(r) => patch({ from: r.from || null, to: r.to || null })}
            />
          </div>
        )}
        {tab === 'overview' && <OverviewTab range={range} />}
        {tab === 'growth' && <GrowthTab range={range} />}
        {tab === 'engagement' && <EngagementTab range={range} />}
        {tab === 'retention' && <RetentionTab />}
        {tab === 'demographics' && (
          <DemographicsTab dimension={dimension} onDimensionChange={(d) => patch({ dim: d })} />
        )}
      </Tabs>
    </div>
  );
}
