// Kullanıcı listesi grafikleri (tembel yüklenir; recharts ayrı parçada kalır): kayıt eğilimi, hesap durumu halkası, fakülte dağılımı.
// API (paralel): GET /api/admin/analytics/registrations (30 gün), GET /api/admin/analytics/breakdown?dimension=status|faculty|role.
import { useQueries } from '@tanstack/react-query';
import { useMemo } from 'react';
import { getBreakdown, getRegistrations } from '../../../api/analytics';
import { qk } from '../../../api/queryKeys';
import { ChartPanel, DonutChart, LineAreaChart } from '../../../components/charts';
import { Card, Insight, RankedBars } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { lastDaysIstanbul } from '../../../lib/date';
import { facultyRows, statusSlices, weekOverWeek } from './insanData';
import { it } from './insan';
import styles from './insan.module.css';

export default function UsersInsights() {
  const i18n = useI18n();
  const t = it(i18n);
  const { td, formatNumber, formatDate } = i18n;
  const range = useMemo(() => lastDaysIstanbul(30), []);
  const [reg, status, faculty, role] = useQueries({
    queries: [
      { queryKey: qk.analytics.registrations(range), queryFn: () => getRegistrations(range), staleTime: 60_000 },
      { queryKey: qk.analytics.breakdown('status'), queryFn: () => getBreakdown('status'), staleTime: 5 * 60_000 },
      { queryKey: qk.analytics.breakdown('faculty'), queryFn: () => getBreakdown('faculty'), staleTime: 5 * 60_000 },
      { queryKey: qk.analytics.breakdown('role'), queryFn: () => getBreakdown('role'), staleTime: 5 * 60_000 },
    ],
  });

  // --- kayıt eğilimi ---
  const points = reg.data?.points ?? [];
  const wow = weekOverWeek(points.map((p) => p.count));
  let regSentence: string | undefined;
  if (wow) {
    const p = { now: formatNumber(wow.now), prev: formatNumber(wow.prev), pct: formatNumber(wow.pct ?? 0) };
    regSentence =
      wow.dir === 'none'
        ? t('admin.insan.reg.noneNow')
        : wow.dir === 'fromZero'
          ? t('admin.insan.reg.fromZero', p)
          : wow.dir === 'same'
            ? t('admin.insan.reg.same', p)
            : wow.dir === 'up'
              ? t('admin.insan.reg.more', p)
              : wow.now === 0
                ? t('admin.insan.reg.noneNow')
                : t('admin.insan.reg.less', p);
  }

  // --- durum ---
  const slices = statusSlices(status.data);
  const total = slices.reduce((s, x) => s + x.value, 0);
  const val = (k: string) => slices.find((x) => x.key === k)?.value ?? 0;
  const susp = val('SUSPENDED');
  const admins = role.data?.items.find((i) => i.key === 'ADMIN')?.count ?? 0;
  const statusParams = {
    total: formatNumber(total),
    active: formatNumber(val('ACTIVE')),
    susp: formatNumber(susp),
    del: formatNumber(val('DELETED')),
  };
  const statusSentence =
    total === 0
      ? undefined
      : `${susp > 0 ? t('admin.insan.status.sentenceBad', statusParams) : t('admin.insan.status.sentence', statusParams)}${
          role.data && admins > 0 ? ` ${t('admin.insan.role.sentence', { admins: formatNumber(admins) })}` : ''
        }`;

  // --- fakülte ---
  const fac = facultyRows(faculty.data);
  const topFaculty = fac.rows[0];

  return (
    <div className={styles.charts} aria-label={t('admin.insan.charts.label')} data-search-anchor="users-charts">
      <div data-search-anchor="users-chart-registrations">
        <ChartPanel
          title={t('admin.insan.reg.title')}
          insight={regSentence}
          insightTone={wow?.dir === 'down' && (wow.pct ?? 0) >= 25 ? 'warn' : 'info'}
          loading={reg.isLoading}
          error={reg.isError}
          onRetry={() => void reg.refetch()}
          empty={!reg.isLoading && !reg.isError && points.length === 0}
          emptyLabel={t('admin.insan.chart.empty')}
          footnote={t('admin.insan.reg.foot')}
          height={260}
          table={{
            columns: [
              { key: 'day', header: t('admin.insan.reg.col.day') },
              { key: 'n', header: t('admin.insan.reg.col.count'), align: 'end' },
            ],
            rows: [...points].reverse().map((p) => ({ day: formatDate(p.date), n: formatNumber(p.count) })),
          }}
        >
          <LineAreaChart
            data={points}
            xKey="date"
            series={[{ key: 'count', label: t('admin.insan.reg.series') }]}
            ariaLabel={t('admin.insan.reg.aria')}
            height={260}
            formatX={(v) => formatDate(String(v), { day: 'numeric', month: 'short' })}
          />
        </ChartPanel>
      </div>

      <div data-search-anchor="users-chart-status">
        <ChartPanel
          title={t('admin.insan.status.title')}
          insight={statusSentence}
          insightTone={susp > 0 ? 'warn' : 'info'}
          loading={status.isLoading}
          error={status.isError}
          onRetry={() => void status.refetch()}
          empty={!status.isLoading && !status.isError && total === 0}
          emptyLabel={t('admin.insan.chart.empty')}
          height={260}
          table={{
            columns: [
              { key: 'state', header: t('admin.insan.status.col.state') },
              { key: 'n', header: t('admin.insan.status.col.count'), align: 'end' },
            ],
            rows: slices.map((s) => ({ state: td(`admin.users.status.${s.key}`), n: formatNumber(s.value) })),
          }}
        >
          <DonutChart
            data={slices.map((s) => ({ name: td(`admin.users.status.${s.key}`), value: s.value }))}
            ariaLabel={t('admin.insan.status.aria')}
            height={260}
          />
        </ChartPanel>
      </div>

      <div className={styles.chartsWide} data-search-anchor="users-chart-faculty">
        <Card title={t('admin.insan.faculty.title')}>
          <div className={styles.cardBody}>
            {!faculty.isLoading && !faculty.isError && topFaculty && (
              <Insight
                parts={t('admin.insan.faculty.sentence', {
                  name: topFaculty.label,
                  n: formatNumber(topFaculty.value),
                })}
              />
            )}
            <RankedBars
              ariaLabel={t('admin.insan.faculty.aria')}
              items={fac.rows.map((r) => ({ key: r.key, label: r.label, value: r.value }))}
              limit={6}
              truncateAt={80} // ipucu sarmalayıcısı dar ekranda etiketi taşırıyordu: uzun fakülte adı tek satırda kırpılır
              showShare
              formatValue={(n) => t('admin.insan.faculty.unit', { n: formatNumber(n) })}
              loading={faculty.isLoading}
              error={faculty.isError}
              onRetry={() => void faculty.refetch()}
              emptyLabel={t('admin.insan.faculty.empty')}
            />
            {fac.unset > 0 && <p className={styles.note}>{t('admin.insan.faculty.noneSet', { n: formatNumber(fac.unset) })}</p>}
          </div>
        </Card>
      </div>
    </div>
  );
}
