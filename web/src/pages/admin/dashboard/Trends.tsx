import type { UseQueryResult } from '@tanstack/react-query';
import { ChartPanel, LineAreaChart } from '../../../components/charts';
import { useCompareSentence } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import type { ActiveUsersResponse, RegistrationsResponse } from '../../../api/types';
import styles from './dashboard.module.css';
import { weekCompare } from './transform';

interface Props {
  registrations: UseQueryResult<RegistrationsResponse>;
  activeUsers: UseQueryResult<ActiveUsersResponse>;
}

/**
 * Son 30 gün: kaç kişi katıldı, kaç kişi girdi. Her grafiğin üstünde tek cümlelik yorum vardır
 * (toplam, günlük ortalama, en yoğun gün). Recharts bu bileşenle birlikte tembel yüklenir; her panel bağımsız hata verir.
 */
export default function Trends({ registrations, activeUsers }: Props) {
  const { t, formatDate, formatNumber } = useI18n();
  const sentence = useCompareSentence();
  const fmt = (v: string | number) => formatDate(String(v), { day: 'numeric', month: 'short' });

  const reg = registrations.data?.points ?? [];
  const regTotal = reg.reduce((s, p) => s + p.count, 0);
  const regPeak = reg.reduce((best, p) => (p.count > (best?.count ?? -1) ? p : best), undefined as (typeof reg)[number] | undefined);

  const act = activeUsers.data?.points ?? [];
  const actAvg = act.length ? Math.round(act.reduce((s, p) => s + p.dau, 0) / act.length) : 0;
  const actPeak = act.reduce((best, p) => (p.dau > (best?.dau ?? -1) ? p : best), undefined as (typeof act)[number] | undefined);

  // Bu hafta (son 7 tamamlanmış gün) ile geçen hafta, gün gün üst üste: "bu hafta geçen haftadan iyi mi?"
  const week = weekCompare(act.map((p) => ({ date: p.date, value: p.dau })));
  const weekSentence = week.hasData
    ? sentence({
        nowLabel: t('admin.genel.week.now'),
        current: week.thisTotal,
        thenLabel: t('admin.genel.week.then'),
        previous: week.lastTotal,
        unit: t('admin.genel.week.unit'),
        verb: t('admin.genel.week.verb'),
      })
    : null;
  const weekday = (v: string | number) => formatDate(String(v), { weekday: 'short' });
  const weekDay = (v: string | number) => formatDate(String(v), { weekday: 'long', day: 'numeric', month: 'short' });

  return (
    <div className={styles.charts} data-search-anchor="dash-trends">
      <ChartPanel
        title={t('admin.v2p.dash.trend.signups')}
        insight={
          regPeak && regTotal > 0
            ? t('admin.v2p.dash.trend.signupsSentence', {
                total: formatNumber(regTotal),
                day: fmt(regPeak.date),
                peak: formatNumber(regPeak.count),
              })
            : undefined
        }
        loading={registrations.isLoading}
        error={registrations.isError}
        onRetry={() => void registrations.refetch()}
        empty={!!registrations.data && reg.length === 0}
        emptyLabel={t('admin.analytics.chart.noData')}
        height={200}
        table={{
          columns: [
            { key: 'day', header: t('admin.v2p.dash.trend.colDay') },
            { key: 'n', header: t('admin.v2p.dash.trend.colSignups'), align: 'end' },
          ],
          rows: reg.map((p) => ({ day: fmt(p.date), n: formatNumber(p.count) })),
        }}
      >
        <LineAreaChart
          data={reg}
          xKey="date"
          series={[{ key: 'count', label: t('admin.dashboard.trends.signupsSeries') }]}
          ariaLabel={t('admin.v2p.dash.trend.signups')}
          height={200}
          formatX={fmt}
          emptyLabel={t('admin.analytics.chart.noData')}
        />
      </ChartPanel>

      <ChartPanel
        title={t('admin.v2p.dash.trend.dau')}
        insight={
          actPeak && act.length > 0
            ? t('admin.v2p.dash.trend.dauSentence', {
                avg: formatNumber(actAvg),
                day: fmt(actPeak.date),
                peak: formatNumber(actPeak.dau),
              })
            : undefined
        }
        loading={activeUsers.isLoading}
        error={activeUsers.isError}
        onRetry={() => void activeUsers.refetch()}
        empty={!!activeUsers.data && act.length === 0}
        emptyLabel={t('admin.analytics.chart.noData')}
        height={200}
        table={{
          columns: [
            { key: 'day', header: t('admin.v2p.dash.trend.colDay') },
            { key: 'n', header: t('admin.v2p.dash.trend.colEntered'), align: 'end' },
          ],
          rows: act.map((p) => ({ day: fmt(p.date), n: formatNumber(p.dau) })),
        }}
      >
        <LineAreaChart
          data={act}
          xKey="date"
          series={[{ key: 'dau', label: t('admin.dashboard.trends.dauSeries'), color: 'var(--chart-3)' }]}
          ariaLabel={t('admin.v2p.dash.trend.dau')}
          height={200}
          formatX={fmt}
          emptyLabel={t('admin.analytics.chart.noData')}
        />
      </ChartPanel>

      <div className={styles.chartsWide} data-search-anchor="dash-week">
        <ChartPanel
          title={t('admin.genel.week.title')}
          insight={weekSentence?.parts}
          insightTone={weekSentence?.tone}
          loading={activeUsers.isLoading}
          error={activeUsers.isError}
          onRetry={() => void activeUsers.refetch()}
          empty={!!activeUsers.data && !week.hasData}
          emptyLabel={t('admin.genel.week.empty')}
          height={220}
          footnote={t('admin.genel.week.note')}
          table={{
            columns: [
              { key: 'day', header: t('admin.v2p.dash.trend.colDay') },
              { key: 'a', header: t('admin.genel.week.thisSeries'), align: 'end' },
              { key: 'b', header: t('admin.genel.week.lastSeries'), align: 'end' },
            ],
            rows: week.rows.map((r) => ({ day: weekDay(r.date), a: formatNumber(r.thisWeek), b: formatNumber(r.lastWeek) })),
          }}
        >
          <LineAreaChart
            data={week.rows}
            xKey="date"
            area={false}
            series={[
              { key: 'thisWeek', label: t('admin.genel.week.thisSeries'), color: 'var(--chart-1)' },
              { key: 'lastWeek', label: t('admin.genel.week.lastSeries'), color: 'var(--chart-4)' },
            ]}
            ariaLabel={t('admin.genel.week.title')}
            height={220}
            formatX={weekday}
            emptyLabel={t('admin.analytics.chart.noData')}
          />
        </ChartPanel>
      </div>
    </div>
  );
}
