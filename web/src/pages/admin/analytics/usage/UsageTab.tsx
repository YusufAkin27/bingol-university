// Analitik > Kullanım sekmesi: en çok gezilen sayfalar, eylemler, akış, saat ısı haritası, platform/sürüm ve özellik benimseme.
// API: /api/admin/analytics/usage/* (api/usage.ts). Yalnız toplulaştırılmış, kimliksiz veri; ağır kütüphane yok (CSS/SVG).
import { useQuery } from '@tanstack/react-query';
import { qk } from '../../../../api/queryKeys';
import type { DateRange } from '../../../../api/types';
import {
  getUsageActions,
  getUsageFeatures,
  getUsageFlow,
  getUsageHourly,
  getUsageScreens,
  getUsageSegments,
  getUsageSummary,
  type UsageSegmentItem,
} from '../../../../api/usage';
import { DonutChart } from '../../../../components/charts';
import {
  Badge,
  Button,
  Card,
  EmptyState,
  Icon,
  Insight,
  ProgressRing,
  RankedBars,
  StatTile,
  Table,
  type Column,
} from '../../../../components/ui';
import { Sparkline } from '../../../../components/ui/Card';
import { useI18n } from '../../../../i18n/I18nProvider';
import { Async } from '../parts';
import analytics from '../analytics.module.css';
import { useKeyLabel, useUt } from './dict';
import {
  DOW_LABELS,
  DOW_LONG,
  flowRows,
  formatSeconds,
  heatGrid,
  isEmptyUsage,
  orderSegments,
  toCsv,
  usageCsvRows,
} from './transform';
import styles from './usage.module.css';

function downloadCsv(name: string, text: string) {
  // Excel'de Türkçe karakterler için BOM; bağlantı hemen bırakılır
  const blob = new Blob(['﻿', text], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

export default function UsageTab({ range }: { range: DateRange }) {
  const i18n = useI18n();
  const { formatNumber } = i18n;
  const ut = useUt();
  const label = useKeyLabel();
  const q = (name: string) => ({ queryKey: qk.analytics.usage(name, range) });
  const summary = useQuery({ ...q('summary'), queryFn: () => getUsageSummary(range) });
  const screens = useQuery({ ...q('screens'), queryFn: () => getUsageScreens(range) });
  const actions = useQuery({ ...q('actions'), queryFn: () => getUsageActions(range) });
  const flow = useQuery({ ...q('flow'), queryFn: () => getUsageFlow(range) });
  const hourly = useQuery({ ...q('hourly'), queryFn: () => getUsageHourly(range) });
  const segments = useQuery({ ...q('segments'), queryFn: () => getUsageSegments(range) });
  const features = useQuery({ ...q('features'), queryFn: () => getUsageFeatures(range) });

  const n = (v: number) => formatNumber(v, { maximumFractionDigits: 1 });
  const loaded = screens.data && actions.data && flow.data && hourly.data;
  const empty = !!loaded && isEmptyUsage({ screens: screens.data, actions: actions.data, flow: flow.data, hourly: hourly.data });
  const kAnon = segments.data?.kAnonymity ?? 10;

  function exportCsv() {
    const text = toCsv(
      usageCsvRows({
        screens: screens.data,
        actions: actions.data,
        flow: flow.data,
        hourly: hourly.data,
        segments: segments.data,
        features: features.data,
        screenLabel: (k) => label('screen', k),
        actionLabel: (k) => label('action', k),
        featureLabel: (k) => label('feature', k),
      }),
    );
    downloadCsv(`${ut('admin.usage.exportName')}-${range.from ?? ''}_${range.to ?? ''}.csv`, text);
  }

  const segLabel = (it: UsageSegmentItem) =>
    it.key === 'other'
      ? ut('admin.usage.segments.other')
      : it.key === 'unknown'
        ? ut('admin.usage.segments.unknown')
        : it.key;

  return (
    <div className={analytics.panel} data-testid="usage-tab">
      <div className={styles.top}>
        <p className={styles.intro}>{ut('admin.usage.intro')}</p>
        <Button
          variant="secondary"
          size="sm"
          leftIcon={<Icon name="download" size={16} aria-hidden="true" />}
          onClick={exportCsv}
          disabled={!loaded || empty}
          data-search-anchor="usage-export"
        >
          {ut('admin.usage.export')}
        </Button>
      </div>

      <details className={analytics.kvkkBox}>
        <summary className={analytics.kvkkSummary}>
          <Icon name="shield" size={18} aria-hidden="true" />
          <span>{ut('admin.usage.kvkkShort')}</span>
        </summary>
        <p className={analytics.kvkk} role="note">
          <span>{ut('admin.usage.kvkk', { k: formatNumber(kAnon) })}</span>
        </p>
      </details>

      {empty && (
        <EmptyState icon="chart" title={ut('admin.usage.empty.title')} description={ut('admin.usage.empty.desc')} />
      )}

      {/* (a) vurgular */}
      <section data-search-anchor="usage-highlights" aria-label={ut('admin.usage.hl.title')}>
        <Async query={summary} height={120} title={ut('admin.usage.hl.title')}>
          {(s) => (
            <>
              <div className={styles.hlGrid}>
                <StatTile
                  label={ut('admin.usage.hl.screen')}
                  value={s.topScreen ? label('screen', s.topScreen) : ut('admin.usage.hl.none')}
                  caption={
                    s.topScreen && screens.data?.items[0]
                      ? ut('admin.usage.hl.screenCaption', { n: formatNumber(screens.data.items[0].views) })
                      : undefined
                  }
                  icon="chart"
                />
                <StatTile
                  label={ut('admin.usage.hl.session')}
                  value={formatSeconds(s.avgSessionSeconds) ?? ut('admin.usage.hl.none')}
                  caption={ut('admin.usage.hl.sessionCaption', { n: formatNumber(s.totalSessions) })}
                  icon="clock"
                />
                <StatTile
                  label={ut('admin.usage.hl.dau')}
                  value={n(s.avgDau)}
                  caption={ut('admin.usage.hl.dauCaption')}
                  spark={s.daily.map((d) => d.dau)}
                  icon="users"
                />
                <StatTile
                  label={ut('admin.usage.hl.action')}
                  value={s.topAction ? label('action', s.topAction) : ut('admin.usage.hl.none')}
                  caption={
                    s.topAction && actions.data?.items[0]
                      ? ut('admin.usage.hl.actionCaption', { n: formatNumber(actions.data.items[0].count) })
                      : undefined
                  }
                  icon="check"
                />
              </div>
              {s.totalScreenViews > 0 && (
                <Insight
                  className={styles.insight}
                  parts={ut('admin.usage.hl.insight', { dau: n(s.avgDau), views: formatNumber(s.totalScreenViews) })}
                />
              )}
              <p className={styles.note}>{ut('admin.usage.today')}</p>
            </>
          )}
        </Async>
      </section>

      {/* (b) en çok gezilen sayfalar */}
      <Card title={ut('admin.usage.screens.title')} data-search-anchor="usage-screens">
        <Async query={screens} height={260} title={ut('admin.usage.screens.title')}>
          {(d) => {
            const top = d.items[0];
            const max = Math.max(1, ...d.items.map((i) => i.views));
            const cols: Column<(typeof d.items)[number]>[] = [
              { key: 'screen', header: ut('admin.usage.screens.col.screen'), render: (r) => label('screen', r.screen) },
              { key: 'views', header: ut('admin.usage.screens.col.views'), align: 'end', render: (r) => <span className={styles.num}>{formatNumber(r.views)}</span> },
              { key: 'users', header: ut('admin.usage.screens.col.users'), align: 'end', render: (r) => <span className={styles.num}>{n(r.avgDailyUsers)}</span> },
              { key: 'avg', header: ut('admin.usage.screens.col.avg'), align: 'end', render: (r) => formatSeconds(r.avgSeconds) ?? '—' },
              { key: 'median', header: ut('admin.usage.screens.col.median'), align: 'end', render: (r) => formatSeconds(r.medianSeconds) ?? '—' },
              { key: 'exit', header: ut('admin.usage.screens.col.exit'), align: 'end', render: (r) => <span className={`${styles.num} ltr`}>%{n(r.exitPercent)}</span> },
            ];
            if (!top) return <EmptyState compact icon="chart" title={ut('admin.usage.empty.title')} description=" " />;
            const dur = formatSeconds(top.avgSeconds);
            return (
              <>
                <Insight
                  className={styles.insight}
                  parts={
                    dur
                      ? ut('admin.usage.screens.insight', { top: label('screen', top.screen), views: formatNumber(top.views), dur })
                      : ut('admin.usage.screens.insightNoDur', { top: label('screen', top.screen), views: formatNumber(top.views) })
                  }
                />
                <ol className={styles.rows} aria-label={ut('admin.usage.screens.title')}>
                  {d.items.slice(0, 10).map((s, idx) => {
                    const avg = formatSeconds(s.avgSeconds);
                    return (
                      <li key={s.screen} className={styles.row}>
                        <span className={`${styles.rank} ${idx === 0 ? styles.rankTop : ''}`}>{formatNumber(idx + 1)}</span>
                        <span className={styles.label}>{label('screen', s.screen)}</span>
                        <span className={styles.value}>{ut('admin.usage.screens.views', { n: formatNumber(s.views) })}</span>
                        <span className={styles.bar} aria-hidden="true">
                          <span className={styles.barFill} style={{ inlineSize: `${(s.views / max) * 100}%` }} />
                        </span>
                        <span className={styles.meta}>
                          {avg && <Badge tone="info">{ut('admin.usage.screens.avg', { dur: avg })}</Badge>}
                          <Badge tone={s.exitPercent >= 50 ? 'warning' : 'neutral'}>
                            {ut('admin.usage.screens.exit', { pct: n(s.exitPercent) })}
                          </Badge>
                        </span>
                        <span className={styles.spark} title={ut('admin.usage.screens.trend')}>
                          <Sparkline data={s.trend} width={72} height={24} label={ut('admin.usage.screens.trend')} />
                        </span>
                      </li>
                    );
                  })}
                </ol>
                <p className={styles.note}>{ut('admin.usage.screens.exitHint')}</p>
                <details className={styles.details} data-testid="usage-screens-table">
                  <summary className={styles.detailsSummary}>{i18n.t('admin.analytics.table.show')}</summary>
                  <Table caption={ut('admin.usage.screens.title')} columns={cols} rows={d.items} rowKey={(r) => r.screen} />
                </details>
              </>
            );
          }}
        </Async>
      </Card>

      <div className={analytics.grid2}>
        {/* (c) en çok yapılan eylemler */}
        <Card title={ut('admin.usage.actions.title')} data-search-anchor="usage-actions">
          <Async query={actions} height={260} title={ut('admin.usage.actions.title')}>
            {(d) => {
              const top = d.items[0];
              if (!top) return <EmptyState compact icon="chart" title={ut('admin.usage.empty.title')} description=" " />;
              const cols: Column<(typeof d.items)[number]>[] = [
                { key: 'action', header: ut('admin.usage.actions.col.action'), render: (r) => label('action', r.action) },
                { key: 'count', header: ut('admin.usage.actions.col.count'), align: 'end', render: (r) => <span className={styles.num}>{formatNumber(r.count)}</span> },
                { key: 'users', header: ut('admin.usage.actions.col.users'), align: 'end', render: (r) => <span className={styles.num}>{formatNumber(r.userDays)}</span> },
                { key: 'adoption', header: ut('admin.usage.actions.col.adoption'), align: 'end', render: (r) => <span className={`${styles.num} ltr`}>%{n(r.adoptionPercent)}</span> },
              ];
              return (
                <>
                  <Insight
                    className={styles.insight}
                    parts={ut('admin.usage.actions.insight', {
                      top: label('action', top.action),
                      count: formatNumber(top.count),
                      pct: n(top.adoptionPercent),
                    })}
                  />
                  <div className={styles.rings}>
                    {d.items.slice(0, 3).map((a) => (
                      <div key={a.action} className={styles.ringItem}>
                        <ProgressRing value={Math.min(100, a.adoptionPercent)} label={ut('admin.usage.actions.ring')} size={92} thickness={9} />
                        <span className={styles.ringName}>{label('action', a.action)}</span>
                      </div>
                    ))}
                  </div>
                  <RankedBars
                    ariaLabel={ut('admin.usage.actions.title')}
                    limit={6}
                    truncateAt={36}
                    items={d.items.map((a) => ({
                      key: a.action,
                      label: label('action', a.action),
                      value: a.count,
                      hint: ut('admin.usage.actions.userDays', { n: formatNumber(a.userDays) }),
                    }))}
                  />
                  <details className={styles.details} data-testid="usage-actions-table">
                    <summary className={styles.detailsSummary}>{i18n.t('admin.analytics.table.show')}</summary>
                    <Table caption={ut('admin.usage.actions.title')} columns={cols} rows={d.items} rowKey={(r) => r.action} />
                  </details>
                </>
              );
            }}
          </Async>
        </Card>

        {/* (d) akış */}
        <Card title={ut('admin.usage.flow.title')} data-search-anchor="usage-flow">
          <Async query={flow} height={260} title={ut('admin.usage.flow.title')}>
            {(d) => {
              const rows = flowRows(d);
              const top = rows[0];
              if (!top) return <EmptyState compact icon="chart" title={ut('admin.usage.empty.title')} description=" " />;
              return (
                <>
                  <Insight
                    className={styles.insight}
                    parts={ut('admin.usage.flow.insight', {
                      from: label('screen', top.from),
                      to: label('screen', top.to),
                      count: formatNumber(top.count),
                      pct: n(top.sharePercent),
                    })}
                  />
                  <ol className={styles.rows} aria-label={ut('admin.usage.flow.title')}>
                    {rows.slice(0, 12).map((r) => (
                      <li
                        key={`${r.from}>${r.to}`}
                        className={styles.flowRow}
                        aria-label={ut('admin.usage.flow.row', {
                          from: label('screen', r.from),
                          to: label('screen', r.to),
                          count: formatNumber(r.count),
                        })}
                      >
                        <span className={styles.flowHead}>
                          <span className={styles.flowPath}>
                            {label('screen', r.from)}
                            <Icon name="chevronRight" size={14} className={styles.arrow} aria-hidden="true" />
                            {label('screen', r.to)}
                          </span>
                          <span className={styles.value}>{formatNumber(r.count)}</span>
                        </span>
                        <span className={styles.bar} aria-hidden="true">
                          <span className={styles.barFill} style={{ inlineSize: `${r.widthPercent}%` }} />
                        </span>
                      </li>
                    ))}
                  </ol>
                  <p className={styles.note}>{ut('admin.usage.flow.note')}</p>
                </>
              );
            }}
          </Async>
        </Card>
      </div>

      {/* (e) saat x gün ısı haritası */}
      <Card title={ut('admin.usage.hourly.title')} data-search-anchor="usage-hourly">
        <Async query={hourly} height={240} title={ut('admin.usage.hourly.title')}>
          {(d) => {
            const grid = heatGrid(d, 'sessions');
            return (
              <>
                {d.peak && (
                  <Insight
                    className={styles.insight}
                    parts={ut('admin.usage.hourly.insight', {
                      day: DOW_LONG[d.peak.dow - 1] ?? '',
                      hour: String(d.peak.hour).padStart(2, '0'),
                      n: formatNumber(d.peak.sessions),
                    })}
                  />
                )}
                <div className={styles.heatWrap}>
                  <table className={styles.heat} aria-label={ut('admin.usage.hourly.title')}>
                    <thead>
                      <tr>
                        <th scope="col" />
                        {Array.from({ length: 24 }, (_, h) => (
                          <th key={h} scope="col" aria-label={`${h}:00`}>
                            {h % 6 === 0 ? h : ''}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {grid.map((row, di) => (
                        <tr key={di}>
                          <th scope="row">{DOW_LABELS[di]}</th>
                          {row.map((c) => (
                            <td
                              key={c.hour}
                              data-level={c.level}
                              title={ut('admin.usage.hourly.cell', {
                                day: DOW_LONG[di] ?? '',
                                hour: String(c.hour).padStart(2, '0'),
                                n: formatNumber(c.sessions),
                              })}
                            >
                              <span className="sr-only">{formatNumber(c.sessions)}</span>
                            </td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <div className={styles.legendRow} aria-hidden="true">
                  <span>{ut('admin.usage.hourly.legendLow')}</span>
                  {[0, 1, 2, 3, 4].map((l) => (
                    <span key={l} className={styles.legendStep} style={l === 0 ? undefined : { background: `var(--heat-${l}, color-mix(in srgb, var(--chart-1) ${l * 25}%, var(--surface)))` }} />
                  ))}
                  <span>{ut('admin.usage.hourly.legendHigh')}</span>
                </div>
                <p className={styles.note}>{ut('admin.usage.hourly.note')}</p>
              </>
            );
          }}
        </Async>
      </Card>

      {/* (f) platform / sürüm / fakülte / bölüm */}
      <Card title={ut('admin.usage.segments.title')} data-search-anchor="usage-segments">
        <Async query={segments} height={260} title={ut('admin.usage.segments.title')}>
          {(d) => {
            const platforms = orderSegments(d.platforms);
            const versions = orderSegments(d.versions);
            const topPlatform = platforms.find((p) => p.key !== 'unknown' && p.key !== 'other');
            const donut = (items: UsageSegmentItem[]) =>
              items.map((i) => ({ name: segLabel(i), value: i.userDays }));
            const bars = (items: UsageSegmentItem[]) =>
              orderSegments(items).map((i) => ({
                key: i.key,
                label: segLabel(i),
                value: i.userDays,
                hint: `%${n(i.percent)}`,
              }));
            return (
              <>
                {topPlatform && (
                  <Insight
                    className={styles.insight}
                    parts={ut('admin.usage.segments.insight', {
                      pct: n(topPlatform.percent),
                      platform: topPlatform.key === 'ios' ? 'iOS' : topPlatform.key === 'android' ? 'Android' : topPlatform.key,
                    })}
                  />
                )}
                <div className={styles.segGrid}>
                  <div>
                    <h3 className={styles.segTitle}>{ut('admin.usage.segments.platform')}</h3>
                    <DonutChart
                      data={donut(platforms.map((p) => ({ ...p, key: p.key === 'ios' ? 'iOS' : p.key === 'android' ? 'Android' : p.key })))}
                      ariaLabel={ut('admin.usage.segments.platform')}
                      height={220}
                      emptyLabel={ut('admin.usage.segments.empty')}
                    />
                  </div>
                  <div>
                    <h3 className={styles.segTitle}>{ut('admin.usage.segments.version')}</h3>
                    <DonutChart
                      data={donut(versions)}
                      ariaLabel={ut('admin.usage.segments.version')}
                      height={220}
                      emptyLabel={ut('admin.usage.segments.empty')}
                    />
                  </div>
                  <div>
                    <h3 className={styles.segTitle}>{ut('admin.usage.segments.faculty')}</h3>
                    <RankedBars
                      ariaLabel={ut('admin.usage.segments.faculty')}
                      limit={6}
                      truncateAt={34}
                      items={bars(d.faculties)}
                      emptyLabel={ut('admin.usage.segments.empty')}
                    />
                  </div>
                  <div>
                    <h3 className={styles.segTitle}>{ut('admin.usage.segments.department')}</h3>
                    <RankedBars
                      ariaLabel={ut('admin.usage.segments.department')}
                      limit={6}
                      truncateAt={34}
                      items={bars(d.departments)}
                      emptyLabel={ut('admin.usage.segments.empty')}
                    />
                  </div>
                </div>
                <p className={styles.note}>{ut('admin.usage.segments.k', { k: formatNumber(d.kAnonymity) })}</p>
              </>
            );
          }}
        </Async>
      </Card>

      {/* (g) özellik benimseme */}
      <Card title={ut('admin.usage.features.title')} data-search-anchor="usage-features">
        <Async query={features} height={200} title={ut('admin.usage.features.title')}>
          {(d) => {
            if (!d.asOf) return <EmptyState compact icon="info" title={ut('admin.usage.features.pending')} description=" " />;
            const top = d.items[0];
            const cols: Column<(typeof d.items)[number]>[] = [
              { key: 'feature', header: ut('admin.usage.features.col.feature'), render: (r) => label('feature', r.feature) },
              { key: 'users', header: ut('admin.usage.features.col.users'), align: 'end', render: (r) => <span className={styles.num}>{formatNumber(r.users)}</span> },
              {
                key: 'share',
                header: ut('admin.usage.features.col.share'),
                align: 'end',
                render: (r) => (
                  <span className={styles.share}>
                    <span className={styles.shareBar} aria-hidden="true">
                      <span className={styles.shareFill} style={{ inlineSize: `${Math.min(100, r.percentOfMau)}%` }} />
                    </span>
                    <span className={`${styles.num} ltr`}>%{n(r.percentOfMau)}</span>
                  </span>
                ),
              },
            ];
            return (
              <>
                {top && top.users > 0 && (
                  <Insight
                    className={styles.insight}
                    parts={ut('admin.usage.features.insight', { top: label('feature', top.feature), pct: n(top.percentOfMau) })}
                  />
                )}
                <Table caption={ut('admin.usage.features.title')} columns={cols} rows={d.items} rowKey={(r) => r.feature} />
                <p className={styles.note}>
                  {ut('admin.usage.features.asOf', { date: i18n.formatDate(d.asOf, { day: 'numeric', month: 'long' }), mau: formatNumber(d.mau) })}
                </p>
              </>
            );
          }}
        </Async>
      </Card>
    </div>
  );
}
