import { Area, AreaChart, CartesianGrid, Legend, Line, LineChart, Tooltip, XAxis, YAxis } from 'recharts';
import { useI18n } from '../../i18n/I18nProvider';
import { axisProps, CHART_COLORS, ChartFrame, tooltipStyle } from './ChartFrame';

export interface Series {
  key: string;
  label: string;
  color?: string;
}

export interface LineAreaChartProps<T extends object> {
  data: T[];
  xKey: keyof T & string;
  series: Series[];
  ariaLabel: string;
  height?: number;
  /** true: dolgulu alan; false: yalnızca çizgi */
  area?: boolean;
  formatX?: (v: string | number) => string;
  emptyLabel?: string;
}

export function LineAreaChart<T extends object>({
  data,
  xKey,
  series,
  ariaLabel,
  height,
  area = true,
  formatX,
  emptyLabel,
}: LineAreaChartProps<T>) {
  const { dir, formatNumber } = useI18n();
  const rtl = dir === 'rtl';
  const common = { data, margin: { top: 8, right: 8, bottom: 0, left: 0 } };
  const axes = [
    <CartesianGrid key="g" stroke="var(--chart-grid)" strokeDasharray="3 3" vertical={false} />,
    <XAxis key="x" dataKey={xKey} reversed={rtl} tickFormatter={formatX} minTickGap={24} {...axisProps} />,
    <YAxis
      key="y"
      orientation={rtl ? 'right' : 'left'}
      tickFormatter={(v: number) => formatNumber(v)}
      width={44}
      allowDecimals={false}
      {...axisProps}
    />,
    <Tooltip key="t" formatter={(v: number) => formatNumber(v)} labelFormatter={formatX} {...tooltipStyle} />,
    series.length > 1 ? <Legend key="l" /> : null,
  ];
  return (
    <ChartFrame ariaLabel={ariaLabel} height={height} empty={data.length === 0} emptyLabel={emptyLabel}>
      {area ? (
        <AreaChart {...common}>
          {axes}
          {series.map((s, i) => {
            const c = s.color ?? CHART_COLORS[i % CHART_COLORS.length];
            return (
              <Area
                key={s.key}
                type="monotone"
                dataKey={s.key}
                name={s.label}
                stroke={c}
                fill={c}
                fillOpacity={0.16}
                strokeWidth={2}
                dot={false}
              />
            );
          })}
        </AreaChart>
      ) : (
        <LineChart {...common}>
          {axes}
          {series.map((s, i) => (
            <Line
              key={s.key}
              type="monotone"
              dataKey={s.key}
              name={s.label}
              stroke={s.color ?? CHART_COLORS[i % CHART_COLORS.length]}
              strokeWidth={2}
              dot={false}
            />
          ))}
        </LineChart>
      )}
    </ChartFrame>
  );
}
