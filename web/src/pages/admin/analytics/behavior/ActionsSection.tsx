import { useQuery } from '@tanstack/react-query';
import { getBehaviorActions, type BehaviorAction } from '../../../../api/analyticsBehavior';
import { qk } from '../../../../api/queryKeys';
import { Card, EmptyState, RankedBars, ResponsiveTable, type Column } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import analytics from '../analytics.module.css';
import styles from './behavior.module.css';
import { actionLabel, formatDec, formatInt, screenLabel, type Range } from './format';
import { Boundary } from './shared';

export default function ActionsSection({ range }: { range: Range }) {
  const { t } = useI18n();
  const q = useQuery({
    queryKey: qk.analytics.behavior('actions', range),
    queryFn: () => getBehaviorActions(range),
  });
  const num = (v: string) => <span className={analytics.num}>{v}</span>;

  return (
    <Boundary query={q} subject={t('admin.bh.sub.actions')} height={320}>
      {(d) => {
        if (d.items.length === 0) {
          return <EmptyState icon="chart" title={t('admin.bh.actions.emptyTitle')} description={t('admin.bh.actions.emptyBody')} />;
        }
        const cols: Column<BehaviorAction>[] = [
          {
            key: 'kind',
            header: t('admin.bh.col.action'),
            card: { priority: 1 },
            render: (r) => (
              <span className={styles.screenName}>
                {actionLabel(r.kind)}
                <code className={`${styles.rawName} ltr`}>{r.kind}</code>
              </span>
            ),
          },
          { key: 'count', header: t('admin.bh.col.count'), align: 'end', card: { priority: 2 }, render: (r) => num(formatInt(r.count)) },
          { key: 'users', header: t('admin.bh.col.users'), align: 'end', card: { priority: 3 }, render: (r) => num(formatInt(r.users)) },
          {
            key: 'perUser',
            header: t('admin.bh.col.perUser'),
            align: 'end',
            render: (r) => num(r.users > 0 ? formatDec(r.count / r.users) : '—'),
          },
          {
            key: 'perScreen',
            header: t('admin.bh.col.byScreen'),
            render: (r) =>
              r.perScreen.length === 0 ? (
                <span className={analytics.muted}>—</span>
              ) : (
                <ul className={styles.chipList} aria-label={t('admin.bh.col.byScreen')}>
                  {r.perScreen.map((s) => (
                    <li key={s.screen} className={styles.chip}>
                      {screenLabel(s.screen)} <strong>{formatInt(s.count)}</strong>
                    </li>
                  ))}
                </ul>
              ),
          },
        ];
        return (
          <div className={styles.stack}>
            <Card title={t('admin.bh.actions.chart')} data-search-anchor="anl-behavior-actions">
              <RankedBars
                ariaLabel={t('admin.bh.actions.chart')}
                limit={8}
                showShare
                items={d.items.map((x) => ({ key: x.kind, label: actionLabel(x.kind), value: x.count }))}
              />
            </Card>
            <Card title={t('admin.bh.actions.table')}>
              <ResponsiveTable caption={t('admin.bh.actions.table')} columns={cols} rows={d.items} rowKey={(r) => r.kind} />
            </Card>
          </div>
        );
      }}
    </Boundary>
  );
}
