// Kaynak sağlığı ızgarası: haber/yemek ana kaynakları + birim siteleri tek bakışta (renk + simge + yazı).
// Veriyi sayfa verir; birim siteleri ayrı sorgudur, o başarısız olsa bile ana kaynaklar görünür.
import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import type { UseQueryResult } from '@tanstack/react-query';
import type { UnitSource } from '../../../api/adminUnitNews';
import { ErrorState, Insight, ProgressRing, Skeleton, StatusDot, useKitFormat, type StatusTone } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import { gt } from '../icerik/dict';
import { sortTiles, summarizeTiles, unitTiles, type GridTile, type SourceState } from './sourceGrid';
import styles from './sourceGrid.module.css';

const TONE: Record<SourceState, StatusTone> = {
  ok: 'success',
  stale: 'warning',
  maintenance: 'danger',
  never: 'warning',
  disabled: 'neutral',
};

const STATES: SourceState[] = ['ok', 'stale', 'maintenance', 'never', 'disabled'];

export function SourceHealthGrid({ core, units }: { core: GridTile[]; units: UseQueryResult<UnitSource[]> }) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatNumber } = i18n;
  const kf = useKitFormat();

  const unitList = useMemo(() => (units.data ? unitTiles(units.data) : []), [units.data]);
  const all = useMemo(() => [...core, ...unitList], [core, unitList]);
  const sum = summarizeTiles(all);
  const sortedUnits = useMemo(() => sortTiles(unitList), [unitList]);

  const insight =
    sum.watched === 0
      ? ''
      : sum.bad === 0
        ? t('admin.icerik.src.grid.insight.allGood', { n: formatNumber(sum.watched) })
        : t('admin.icerik.src.grid.insight.some', {
            n: formatNumber(sum.watched),
            ok: formatNumber(sum.ok),
            bad: formatNumber(sum.bad),
          });

  const tile = (g: GridTile) => {
    const inner = (
      <>
        <span className={styles.name} dir="auto">
          {g.label}
        </span>
        <StatusDot tone={TONE[g.state]}>{t(`admin.icerik.src.state.${g.state}`)}</StatusDot>
        <span className={styles.meta}>
          {g.lastAt ? t('admin.icerik.src.grid.last', { when: kf.relative(g.lastAt) }) : t('admin.icerik.src.grid.lastNever')}
        </span>
        {g.announcements !== undefined && (
          <span className={styles.meta}>{t('admin.icerik.src.grid.announcements', { n: formatNumber(g.announcements) })}</span>
        )}
      </>
    );
    const cls = `${styles.tile} ${styles[`s_${g.state}`]}`;
    return (
      <li key={g.key} className={styles.item} data-state={g.state}>
        {g.core ? (
          <div className={cls}>{inner}</div>
        ) : (
          <Link className={cls} to={paths.admin.unitNews} title={t('admin.icerik.src.grid.openUnit')}>
            {inner}
          </Link>
        )}
      </li>
    );
  };

  return (
    <section className={styles.wrap} aria-label={t('admin.icerik.src.grid.label')} data-search-anchor="sources-grid" data-testid="source-grid">
      <h2 className={styles.h}>{t('admin.icerik.src.grid.title')}</h2>
      <div className={styles.top}>
        <ProgressRing
          value={sum.ok}
          max={Math.max(1, sum.watched)}
          size={104}
          thickness={10}
          tone={sum.bad === 0 ? 'success' : 'warning'}
          center={`${formatNumber(sum.ok)}/${formatNumber(sum.watched)}`}
          label={t('admin.icerik.src.grid.ringLabel')}
          loading={units.isLoading && core.length === 0}
        />
        <div className={styles.topText}>
          {insight && <Insight tone={sum.bad === 0 ? 'good' : 'warn'} parts={insight} />}
          <ul className={styles.legend} aria-label={t('admin.icerik.src.legend.title')}>
            {STATES.filter((s) => sum.counts[s] > 0).map((s) => (
              <li key={s}>
                <StatusDot tone={TONE[s]} announceTone={false}>
                  {t(`admin.icerik.src.state.${s}`)}: <strong>{formatNumber(sum.counts[s])}</strong>
                </StatusDot>
              </li>
            ))}
          </ul>
        </div>
      </div>

      <h3 className={styles.sub}>{t('admin.icerik.src.grid.core')}</h3>
      <ul className={styles.grid}>{core.map(tile)}</ul>

      <h3 className={styles.sub}>
        {t('admin.icerik.src.grid.units', { n: formatNumber(units.data?.length ?? 0) })}
      </h3>
      {units.isError ? (
        <ErrorState
          inline
          subject={t('admin.icerik.src.grid.unitsErrorSubject')}
          error={units.error}
          onRetry={() => void units.refetch()}
        />
      ) : units.isLoading ? (
        <Skeleton height="9rem" width="100%" />
      ) : sortedUnits.length === 0 ? (
        <p className={styles.meta}>{t('admin.icerik.src.grid.unitsEmpty')}</p>
      ) : (
        <ul className={styles.grid}>{sortedUnits.map(tile)}</ul>
      )}
    </section>
  );
}
