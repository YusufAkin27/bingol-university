// 2FA sayfası: haftalık benimseme eğilimi (tembel yüklenir; recharts ayrı parçada).
// API: GET /api/admin/two-factor/users?page&size=100 (en yeni açan üstte sıralıdır; son 8 haftayı kapsayana dek en çok 5 sayfa okunur).
// Not: sunucuda geçmiş sayaç yok; eğilim `enabledAt` tarihlerinden kurulur. Korumayı sonradan kapatanlar listede olmadığı için sayılmaz.
import { useQuery } from '@tanstack/react-query';
import { listTwoFactorUsers } from '../../../api/twoFactor';
import { qk } from '../../../api/queryKeys';
import { BarChart, ChartPanel } from '../../../components/charts';
import { useI18n } from '../../../i18n/I18nProvider';
import { compareTrend, weeklyEnablements } from '../users/insanData';
import { it } from '../users/insan';

const WEEKS = 8;
const PAGE = 100;
const MAX_PAGES = 5;

/** Son 8 haftanın başlangıcı: bu kadar eski kayda gelince daha geriye gitmeye gerek kalmaz. */
function windowStart(now = Date.now()): number {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  return d.getTime() - (WEEKS * 7 - 1) * 86_400_000;
}

async function loadEnablements() {
  const since = windowStart();
  const dates: { enabledAt: string | null }[] = [];
  let partial = false;
  for (let page = 0; page < MAX_PAGES; page++) {
    const r = await listTwoFactorUsers({ page, size: PAGE });
    dates.push(...r.items.map((u) => ({ enabledAt: u.enabledAt })));
    const oldest = r.items[r.items.length - 1]?.enabledAt;
    const reachedOld = !oldest || new Date(oldest).getTime() < since;
    if (reachedOld || page + 1 >= r.totalPages) break;
    if (page + 1 === MAX_PAGES) partial = true;
  }
  return { dates, partial };
}

export default function TwoFactorTrend() {
  const i18n = useI18n();
  const t = it(i18n);
  const { formatNumber, formatDate } = i18n;
  const q = useQuery({
    queryKey: [...qk.users.all, 'twoFactorTrend'],
    queryFn: loadEnablements,
    staleTime: 60_000,
  });
  const buckets = q.data ? weeklyEnablements(q.data.dates, WEEKS) : [];
  const total = buckets.reduce((s, b) => s + b.count, 0);
  const last = buckets[buckets.length - 1]?.count ?? 0;
  const prev = buckets[buckets.length - 2]?.count ?? 0;
  const tr = compareTrend(last, prev);
  const p = { now: formatNumber(last), prev: formatNumber(prev), pct: formatNumber(tr.pct ?? 0) };
  const sentence = !q.data
    ? undefined
    : total === 0
      ? t('admin.insan.tf.trend.empty')
      : tr.dir === 'none'
        ? t('admin.insan.tf.trend.none')
        : tr.dir === 'fromZero'
          ? t('admin.insan.tf.trend.fromZero', p)
          : tr.dir === 'same'
            ? t('admin.insan.tf.trend.same', p)
            : last === 0
              ? t('admin.insan.tf.trend.none')
              : tr.dir === 'up'
                ? t('admin.insan.tf.trend.more', p)
                : t('admin.insan.tf.trend.less', p);
  const data = buckets.map((b) => ({ week: formatDate(b.week, { day: 'numeric', month: 'short' }), count: b.count }));

  return (
    <ChartPanel
      title={t('admin.insan.tf.trend.title')}
      insight={sentence}
      loading={q.isLoading}
      error={q.isError}
      onRetry={() => void q.refetch()}
      empty={!!q.data && total === 0}
      emptyLabel={t('admin.insan.tf.trend.empty')}
      height={240}
      footnote={`${t('admin.insan.tf.trend.foot')}${q.data?.partial ? ` ${t('admin.insan.tf.trend.partial')}` : ''}`}
      table={{
        columns: [
          { key: 'week', header: t('admin.insan.tf.trend.col.week') },
          { key: 'n', header: t('admin.insan.tf.trend.col.count'), align: 'end' },
        ],
        rows: data.map((d) => ({ week: d.week, n: formatNumber(d.count) })),
      }}
    >
      <BarChart
        data={data}
        xKey="week"
        series={[{ key: 'count', label: t('admin.insan.tf.trend.series') }]}
        ariaLabel={t('admin.insan.tf.trend.aria')}
        height={240}
      />
    </ChartPanel>
  );
}
