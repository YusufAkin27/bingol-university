// Menü kalori grafiği: ayın her günü için toplam kalori çubuğu; eksik girilen günler çizgili/kesikli gösterilir.
// Çubuğa tıklayınca o günün satırı açılır (kalori düzenleme orada).
import { useMemo } from 'react';
import { Button, Insight, ProgressRing, ScrollShadow } from '../../../components/ui';
import type { AdminMenuDay } from '../../../api/adminMenu';
import { useI18n } from '../../../i18n/I18nProvider';
import { gt } from '../icerik/dict';
import { kcalSeries, type KcalBar } from './kcalChartLogic';
import styles from './menu.module.css';

export function MenuKcalChart({ days, onPick }: { days: AdminMenuDay[]; onPick: (date: string) => void }) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatDate, formatNumber } = i18n;
  const series = useMemo(() => kcalSeries(days), [days]);
  const label = (date: string) => formatDate(date, { day: 'numeric', month: 'long', weekday: 'long' });

  const barText = (b: KcalBar) =>
    b.state === 'none'
      ? t('admin.icerik.menu.kcal.bar.none', { date: label(b.date) })
      : b.state === 'partial'
        ? t('admin.icerik.menu.kcal.bar.partial', {
            date: label(b.date),
            kcal: formatNumber(b.kcal),
            missing: formatNumber(b.missing),
          })
        : t('admin.icerik.menu.kcal.bar.full', { date: label(b.date), kcal: formatNumber(b.kcal) });

  const tone = series.maxBar === null ? 'warn' : series.daysMissing > 0 ? 'warn' : 'good';
  const insight =
    series.maxBar === null
      ? t('admin.icerik.menu.kcal.insight.none')
      : series.daysMissing === 0
        ? t('admin.icerik.menu.kcal.insight.ok', {
            avg: formatNumber(series.avgFull ?? 0),
            date: formatDate(series.maxBar.date, { day: 'numeric', month: 'long' }),
            max: formatNumber(series.maxBar.kcal),
          })
        : series.avgFull === null
          ? t('admin.icerik.menu.kcal.insight.missingNoAvg', {
              dishes: formatNumber(series.dishTotal - series.dishKnown),
              days: formatNumber(series.daysMissing),
            })
          : t('admin.icerik.menu.kcal.insight.missing', {
              dishes: formatNumber(series.dishTotal - series.dishKnown),
              days: formatNumber(series.daysMissing),
              avg: formatNumber(series.avgFull),
            });

  return (
    <div className={styles.kchart} data-testid="menu-kcal-chart">
      <Insight tone={tone} parts={insight} />
      <div className={styles.kchartBody}>
        <div className={styles.kchartRing}>
          <ProgressRing
            value={series.dishKnown}
            max={Math.max(1, series.dishTotal)}
            size={104}
            thickness={10}
            tone={series.dishTotal > 0 && series.dishKnown === series.dishTotal ? 'success' : 'warning'}
            label={`${t('admin.icerik.menu.kcal.coverageValue', {
              known: formatNumber(series.dishKnown),
              all: formatNumber(series.dishTotal),
            })} ${t('admin.icerik.menu.kcal.coverage')}`}
          />
          {series.firstMissingDate && (
            <Button size="sm" variant="secondary" onClick={() => onPick(series.firstMissingDate!)}>
              {t('admin.icerik.menu.kcal.goFirst')}
            </Button>
          )}
        </div>
        <div className={styles.kchartMain}>
          {series.maxKcal > 0 && (
            <p className={styles.kchartAxis}>{t('admin.icerik.menu.kcal.axisMax', { kcal: formatNumber(series.maxKcal) })}</p>
          )}
          <ScrollShadow ariaLabel={t('admin.icerik.menu.kcal.chartLabel')}>
            <ul className={styles.kbars} style={{ minInlineSize: `${series.bars.length * 1.9}rem` }}>
              {series.bars.map((b) => (
                <li key={b.date} className={styles.kcol}>
                  <button
                    type="button"
                    className={`${styles.kbtn} ${styles[`kbar_${b.state}`]}`}
                    aria-label={`${barText(b)}. ${t('admin.icerik.menu.kcal.open')}`}
                    title={barText(b)}
                    onClick={() => onPick(b.date)}
                  >
                    <span className={styles.kfill} style={{ blockSize: b.state === 'none' ? undefined : `${Math.max(b.pct, 4)}%` }} />
                  </button>
                  <span className={styles.kday} aria-hidden="true">
                    {formatNumber(b.day)}
                  </span>
                </li>
              ))}
            </ul>
          </ScrollShadow>
          <ul className={styles.klegend}>
            <li>
              <span className={`${styles.ksw} ${styles.kbar_full}`} aria-hidden="true" />
              {t('admin.icerik.menu.kcal.legend.full')}
            </li>
            <li>
              <span className={`${styles.ksw} ${styles.kbar_partial}`} aria-hidden="true" />
              {t('admin.icerik.menu.kcal.legend.partial')}
            </li>
            <li>
              <span className={`${styles.ksw} ${styles.kbar_none}`} aria-hidden="true" />
              {t('admin.icerik.menu.kcal.legend.none')}
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}
