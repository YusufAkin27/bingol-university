// Üst göstergeler: toplam yer, kategori dağılımı (mini çubuklar) ve son güncelleme.
import { useMemo } from 'react';
import type { CampusPlace } from '../../../api/adminCampus';
import { RankedBars, StatTile } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { SummaryGrid } from '../community/Summary';
import { gt } from './dict';
import { categoryCounts, latestUpdate } from './logic';
import styles from './campus.module.css';

interface Props {
  places: CampusPlace[] | undefined;
  /** Ayar kaydının güncellenme zamanı (sunucu verirse). */
  configUpdatedAt?: string | null;
  loading: boolean;
  error: boolean;
  onRetry: () => void;
}

export function CampusSummary({ places, configUpdatedAt, loading, error, onRetry }: Props) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatNumber, formatDate } = i18n;

  const stats = useMemo(() => {
    if (!places) return null;
    const active = places.filter((p) => p.active).length;
    return {
      total: places.length,
      active,
      inactive: places.length - active,
      cats: categoryCounts(places),
      updated: latestUpdate(configUpdatedAt, ...places.map((p) => p.updatedAt)),
    };
  }, [places, configUpdatedAt]);

  return (
    <div data-search-anchor="campus-stats">
      <SummaryGrid label={t('admin.campus.stats')}>
        <StatTile
          icon="pin"
          label={t('admin.campus.stat.total')}
          value={stats?.total}
          caption={
            stats
              ? t('admin.campus.stat.totalCaption', {
                  active: formatNumber(stats.active),
                  inactive: formatNumber(stats.inactive),
                })
              : undefined
          }
          loading={loading}
          error={error}
          onRetry={onRetry}
        />
        <div className={styles.catTile} role="group" aria-label={t('admin.campus.stat.cats')}>
          <span className={styles.catTitle}>{t('admin.campus.stat.cats')}</span>
          <RankedBars
            ariaLabel={t('admin.campus.stat.catsAria')}
            items={stats?.cats.map((c) => ({
              key: c.category,
              label: t(`admin.campus.cat.${c.category}`),
              value: c.count,
            }))}
            limit={3}
            loading={loading}
            error={error}
            onRetry={onRetry}
            emptyLabel={t('admin.campus.stat.catsEmpty')}
          />
        </div>
        <StatTile
          icon="clock"
          label={t('admin.campus.stat.updated')}
          value={stats ? (stats.updated ? formatDate(stats.updated) : t('admin.campus.stat.updatedNone')) : undefined}
          caption={
            stats
              ? t(stats.updated ? 'admin.campus.stat.updatedCaption' : 'admin.campus.stat.updatedNoneCaption')
              : undefined
          }
          loading={loading}
          error={error}
          onRetry={onRetry}
        />
      </SummaryGrid>
    </div>
  );
}
