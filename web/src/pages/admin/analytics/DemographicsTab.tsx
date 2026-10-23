import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { getFaculties } from '../../../api/appInfo';
import { getBreakdown } from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import type { BreakdownDimension, BreakdownResponse } from '../../../api/types';
import { DonutChart } from '../../../components/charts';
import { Badge, Button, Card, EmptyState, Table, type Column } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import styles from './analytics.module.css';
import { Async, BarList } from './parts';
import { DIMENSIONS } from './transform';

type Item = BreakdownResponse['items'][number];

export default function DemographicsTab({
  dimension,
  onDimensionChange,
}: {
  dimension: BreakdownDimension;
  onDimensionChange: (d: BreakdownDimension) => void;
}) {
  const { t, td, formatNumber } = useI18n();
  const q = useQuery({ queryKey: qk.analytics.breakdown(dimension), queryFn: () => getBreakdown(dimension) });
  const faculties = useQuery({
    queryKey: qk.faculties,
    queryFn: getFaculties,
    staleTime: 5 * 60_000,
    enabled: dimension === 'faculty',
  });

  /** "Bilinmiyor" ve "diğer" açıkça gösterilir; enum boyutları seçili dilde çevrilir. */
  function labelOf(it: Item): string {
    if (it.key === 'unknown') return t('admin.analytics.demo.unknown');
    if (it.key === 'other') return t('admin.analytics.demo.other');
    switch (dimension) {
      case 'language':
        return td(`admin.users.lang.${it.key}`, it.label);
      case 'role':
        return td(`admin.users.role.${it.key.toUpperCase()}`, it.label);
      case 'status':
        return td(`admin.users.status.${it.key.toUpperCase()}`, it.label);
      case 'platform':
        return td(`admin.users.platform.${it.key.toUpperCase()}`, it.label);
      case 'classYear':
        return /^\d+$/.test(it.key) ? t('admin.analytics.demo.classYearValue', { n: formatNumber(Number(it.key)) }) : it.label;
      default:
        return it.label;
    }
  }

  const noFacultyList = dimension === 'faculty' && faculties.isSuccess && faculties.data.length === 0;

  return (
    <div className={styles.panel}>
      <div className={styles.dims} role="group" aria-label={t('admin.analytics.demo.dimension')}>
        {DIMENSIONS.map((d) => (
          <Button
            key={d}
            size="sm"
            variant={d === dimension ? 'primary' : 'secondary'}
            aria-pressed={d === dimension}
            onClick={() => onDimensionChange(d)}
          >
            {t(`admin.analytics.demo.${d}`)}
          </Button>
        ))}
      </div>

      <Card title={t(`admin.analytics.demo.${dimension}`)}>
        {noFacultyList && (
          <p className={styles.hintBox} role="note" data-testid="faculty-hint">
            {t('admin.analytics.demo.facultyHint')}{' '}
            <Link to={paths.admin.settings}>{t('admin.analytics.demo.facultyHintLink')}</Link>
          </p>
        )}
        <Async query={q} height={300}>
          {(d) => {
            if (d.items.length === 0 || d.total === 0) {
              return (
                <EmptyState compact icon="chart" title={t('admin.analytics.demo.empty')} description=" " />
              );
            }
            const items = d.items.map((i) => ({ ...i, text: labelOf(i) }));
            const columns: Column<(typeof items)[number]>[] = [
              {
                key: 'label',
                header: t('admin.analytics.demo.category'),
                render: (i) =>
                  i.key === 'unknown' ? (
                    <Badge tone="neutral">{i.text}</Badge>
                  ) : (
                    <span>{i.text}</span>
                  ),
              },
              {
                key: 'count',
                header: t('admin.analytics.demo.count'),
                align: 'end',
                render: (i) => <span className={styles.num}>{formatNumber(i.count)}</span>,
              },
              {
                key: 'percent',
                header: t('admin.analytics.demo.percent'),
                align: 'end',
                render: (i) => (
                  <span className={`${styles.num} ltr`}>%{formatNumber(i.percent, { maximumFractionDigits: 1 })}</span>
                ),
              },
            ];
            const donut = items.length <= 6;
            return (
              <>
                <p className={styles.muted} style={{ marginBlockEnd: 'var(--space-3)' }}>
                  {t('admin.analytics.demo.total', { n: formatNumber(d.total) })}
                  {dimension === 'platform' && <> {t('admin.analytics.demo.platformNote')}</>}
                </p>
                <div className={styles.demoBody}>
                  <div>
                    {donut ? (
                      <DonutChart
                        data={items.map((i) => ({ name: i.text, value: i.count }))}
                        ariaLabel={t(`admin.analytics.demo.${dimension}`)}
                        height={280}
                      />
                    ) : (
                      <BarList
                        ariaLabel={t(`admin.analytics.demo.${dimension}`)}
                        items={items.map((i) => ({
                          key: i.key,
                          label: i.text,
                          value: i.count,
                          percent: i.percent,
                          muted: i.key === 'unknown',
                        }))}
                      />
                    )}
                  </div>
                  <div data-testid="demo-table">
                    <Table
                      caption={t(`admin.analytics.demo.${dimension}`)}
                      columns={columns}
                      rows={items}
                      rowKey={(i) => i.key}
                    />
                  </div>
                </div>
              </>
            );
          }}
        </Async>
      </Card>
    </div>
  );
}
