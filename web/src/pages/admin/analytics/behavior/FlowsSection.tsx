import { useQuery } from '@tanstack/react-query';
import { getBehaviorFlows } from '../../../../api/analyticsBehavior';
import { qk } from '../../../../api/queryKeys';
import { Card, EmptyState, RankedBars, ResponsiveTable, type Column } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import analytics from '../analytics.module.css';
import styles from './behavior.module.css';
import { formatInt, formatPct, heat, screenLabel, type Range } from './format';
import { Boundary, HeatCell } from './shared';

type DropRow = { screen: string; entered: number; left: number; leftRate: number };

export default function FlowsSection({ range }: { range: Range }) {
  const { t } = useI18n();
  const q = useQuery({
    queryKey: qk.analytics.behavior('flows', range),
    queryFn: () => getBehaviorFlows(range),
  });
  const num = (v: string) => <span className={analytics.num}>{v}</span>;

  return (
    <Boundary query={q} subject={t('admin.bh.sub.flows')} height={360}>
      {(d) => {
        const nothing =
          d.topTransitions.length === 0 && d.entryScreens.length === 0 && d.exitScreens.length === 0 && d.dropOff.length === 0;
        if (nothing) {
          return <EmptyState icon="chart" title={t('admin.bh.flows.emptyTitle')} description={t('admin.bh.flows.emptyBody')} />;
        }
        const dropCols: Column<DropRow>[] = [
          { key: 'screen', header: t('admin.bh.col.screen'), card: { priority: 1 }, render: (r) => screenLabel(r.screen) },
          { key: 'entered', header: t('admin.bh.col.entered'), align: 'end', card: { priority: 2 }, render: (r) => num(formatInt(r.entered)) },
          { key: 'left', header: t('admin.bh.col.left'), align: 'end', card: { priority: 3 }, render: (r) => num(formatInt(r.left)) },
          {
            key: 'leftRate',
            header: t('admin.bh.col.leftRate'),
            align: 'end',
            render: (r) => <HeatCell text={num(formatPct(r.leftRate))} ratio={heat(r.leftRate, 1)} tone="warn" />,
          },
        ];
        return (
          <div className={styles.stack}>
            <Card title={t('admin.bh.flows.transitions')} data-search-anchor="anl-behavior-flows">
              <p className={analytics.muted}>{t('admin.bh.flows.transitionsHint')}</p>
              <RankedBars
                ariaLabel={t('admin.bh.flows.transitions')}
                limit={10}
                truncateAt={48}
                emptyLabel={t('admin.bh.flows.emptyTitle')}
                items={d.topTransitions.map((x, i) => ({
                  key: `${x.from}>${x.to}#${i}`,
                  label: `${screenLabel(x.from)} → ${screenLabel(x.to)}`,
                  value: x.count,
                }))}
              />
            </Card>
            <div className={analytics.grid2}>
              <Card title={t('admin.bh.flows.entries')}>
                <p className={analytics.muted}>{t('admin.bh.flows.entriesHint')}</p>
                <RankedBars
                  ariaLabel={t('admin.bh.flows.entries')}
                  limit={10}
                  showShare
                  emptyLabel={t('admin.bh.flows.emptyTitle')}
                  items={d.entryScreens.map((x) => ({ key: x.screen, label: screenLabel(x.screen), value: x.sessions }))}
                />
              </Card>
              <Card title={t('admin.bh.flows.exits')}>
                <p className={analytics.muted}>{t('admin.bh.flows.exitsHint')}</p>
                <RankedBars
                  ariaLabel={t('admin.bh.flows.exits')}
                  limit={10}
                  showShare
                  emptyLabel={t('admin.bh.flows.emptyTitle')}
                  items={d.exitScreens.map((x) => ({ key: x.screen, label: screenLabel(x.screen), value: x.sessions }))}
                />
              </Card>
            </div>
            <Card title={t('admin.bh.flows.dropOff')}>
              <p className={analytics.muted}>{t('admin.bh.flows.dropOffHint')}</p>
              <ResponsiveTable
                caption={t('admin.bh.flows.dropOff')}
                columns={dropCols}
                rows={d.dropOff}
                rowKey={(r) => r.screen}
              />
            </Card>
          </div>
        );
      }}
    </Boundary>
  );
}
