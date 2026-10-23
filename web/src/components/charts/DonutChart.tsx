import { Cell, Legend, Pie, PieChart, Tooltip } from 'recharts';
import { useI18n } from '../../i18n/I18nProvider';
import { CHART_COLORS, ChartFrame, tooltipStyle } from './ChartFrame';

export interface DonutDatum {
  name: string;
  value: number;
}

interface Props {
  data: DonutDatum[];
  ariaLabel: string;
  height?: number;
  emptyLabel?: string;
}

export function DonutChart({ data, ariaLabel, height = 260, emptyLabel }: Props) {
  const { formatNumber } = useI18n();
  const total = data.reduce((s, d) => s + d.value, 0);
  return (
    <ChartFrame
      ariaLabel={ariaLabel}
      height={height}
      empty={data.length === 0 || total === 0}
      emptyLabel={emptyLabel}
    >
      <PieChart>
        <Pie
          data={data}
          dataKey="value"
          nameKey="name"
          innerRadius="58%"
          outerRadius="85%"
          paddingAngle={2}
          stroke="var(--surface)"
          strokeWidth={2}
        >
          {data.map((d, i) => (
            <Cell key={d.name} fill={CHART_COLORS[i % CHART_COLORS.length]} />
          ))}
        </Pie>
        <Tooltip
          formatter={(v: number, n: string) => [
            `${formatNumber(v)} (${formatNumber(Math.round((v / total) * 100))}%)`,
            n,
          ]}
          {...tooltipStyle}
        />
        <Legend verticalAlign="bottom" iconType="circle" />
      </PieChart>
    </ChartFrame>
  );
}
