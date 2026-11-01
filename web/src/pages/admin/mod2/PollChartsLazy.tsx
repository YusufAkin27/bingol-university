// Anket sonuç grafikleri (recharts). Yalnızca PollResultsViz tembel yükler: grafik parçası anket çekmecesi açılınca iner.
import { BarChart } from '../../../components/charts/BarChart';
import { DonutChart } from '../../../components/charts/DonutChart';
import type { OptionShare } from './pollCharts';

export default function PollCharts({
  kind,
  shares,
  ariaLabel,
  seriesLabel,
}: {
  kind: 'donut' | 'rating';
  shares: OptionShare[];
  ariaLabel: string;
  seriesLabel: string;
}) {
  if (kind === 'donut') {
    return <DonutChart ariaLabel={ariaLabel} height={230} data={shares.filter((s) => s.count > 0).map((s) => ({ name: s.name, value: s.count }))} />;
  }
  return (
    <BarChart
      ariaLabel={ariaLabel}
      height={200}
      xKey="name"
      series={[{ key: 'count', label: seriesLabel }]}
      data={shares.map((s) => ({ name: s.name, count: s.count }))}
    />
  );
}
