// Anket görselleri: liste üstü durum/kapsam dağılımı ve çekmecede sonuç grafiği (halka / puan çubukları + tek cümle yorum).
import { lazy, Suspense } from 'react';
import type { AdminPollStats, PollDetail } from '../../../api/adminPolls';
import { Insight, RankedBars, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useGt } from './dict';
import { leaders, optionShares, POLL_SCOPES, pollStateSegments, ratingAverage } from './pollCharts';
import { StackedShare } from './StackedShare';
import styles from './mod2.module.css';

const PollCharts = lazy(() => import('./PollChartsLazy'));

/** Liste üstü: anketlerin durum payı + hangi alanda açıldıkları. */
export function PollsOverview({ stats }: { stats: AdminPollStats }) {
  const t = useGt();
  const scopeBars = POLL_SCOPES.map((k) => ({ key: k, label: t(`admin.mod2.polls.scope.${k}`), value: stats.byScope?.[k] ?? 0 })).filter(
    (x) => x.value > 0,
  );
  return (
    <section className={styles.chartGrid} aria-label={t('admin.mod2.polls.stateTitle')}>
      <div className={styles.chartCard} data-search-anchor="polls-state-chart">
        <h2 className={styles.chartTitle}>{t('admin.mod2.polls.stateTitle')}</h2>
        <p className={styles.chartHint}>{t('admin.mod2.polls.stateHint')}</p>
        <StackedShare
          ariaLabel={t('admin.mod2.polls.stateTitle')}
          segments={pollStateSegments(stats, (k) => t(`admin.mod2.polls.state.${k}`))}
        />
      </div>
      {scopeBars.length > 1 && (
        <div className={styles.chartCard} data-search-anchor="polls-scope-chart">
          <h2 className={styles.chartTitle}>{t('admin.mod2.polls.scopeTitle')}</h2>
          <RankedBars items={scopeBars} limit={3} ariaLabel={t('admin.mod2.polls.scopeTitle')} />
        </div>
      )}
    </section>
  );
}

/** Çekmece: oyların dağılımı. Seçenek çoksa halka yerine mevcut çubuk listesi yeter. */
export function PollResultsViz({ poll }: { poll: PollDetail }) {
  const t = useGt();
  const { formatNumber } = useI18n();
  const shares = optionShares(poll, (n) => t('admin.p03.res.stars', { n }));
  const total = shares.reduce((s, x) => s + x.count, 0);
  if (!poll.resultsVisible && poll.results == null) return null;
  if (total === 0) {
    return <p className={styles.chartHint}>{t('admin.mod2.polls.noVotes')}</p>;
  }
  const top = leaders(shares);
  const avg = poll.type === 'RATING' ? ratingAverage(poll) : null;
  const parts =
    poll.type === 'RATING' && avg != null
      ? [{ text: t('admin.mod2.polls.ratingAvg', { avg: formatNumber(Math.round(avg * 10) / 10), n: formatNumber(total) }) }]
      : top.length === 1
        ? [{ text: t('admin.mod2.polls.leader', { name: top[0].name, pct: formatNumber(Math.round(top[0].percent)) }) }]
        : [{ text: t('admin.mod2.polls.tie', { names: top.map((x) => x.name).join(', ') }) }];
  const kind = poll.type === 'RATING' ? 'rating' : poll.type === 'SINGLE' && shares.length <= 8 ? 'donut' : null;
  return (
    <div className={styles.pollViz} data-testid="poll-viz" data-search-anchor="polls-results-chart">
      <Insight parts={parts} />
      {kind && (
        <Suspense fallback={<Skeleton height="12rem" width="100%" />}>
          <PollCharts
            kind={kind}
            shares={shares}
            ariaLabel={t(kind === 'donut' ? 'admin.mod2.polls.donutChart' : 'admin.mod2.polls.ratingChart')}
            seriesLabel={t('admin.p03.res.votes')}
          />
        </Suspense>
      )}
    </div>
  );
}
