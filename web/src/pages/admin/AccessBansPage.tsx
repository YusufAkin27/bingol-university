// SAYFA: Erişim engelleri (/admin/security/access-bans)
// API: GET /api/admin/access-bans/stats ve liste/ekle/düzenle/sil/bulk/attempts/anonymizers uçları (api/accessBans.ts).
import { useQuery } from '@tanstack/react-query';
import { accessBanKeys, BAN_KINDS, getStats } from '../../api/accessBans';
import { ErrorState, Insight, PageHeader, StatTile, Tabs } from '../../components/ui';
import { useUrlTab } from '../../search/useUrlTab';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import styles from './accessbans/accessBans.module.css';
import { AnonymizersTab } from './accessbans/AnonymizersTab';
import { BansTab } from './accessbans/BansTab';
import { BulkTab } from './accessbans/BulkTab';
import { adminErrorMessage } from './campaigns/shared';

type TabId = 'bans' | 'bulk' | 'anon';
const TAB_IDS = ['bans', 'bulk', 'anon'] as const;
const KIND_COLOR: Record<string, string> = {
  IP: 'var(--chart-1)',
  CIDR: 'var(--chart-2)',
  DEVICE: 'var(--chart-3)',
  USER: 'var(--chart-4)',
};

export default function AccessBansPage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  usePageTitle(t('admin.ab.title'));
  const [tab, setTab] = useUrlTab<TabId>(TAB_IDS, 'bans');
  const stats = useQuery({ queryKey: accessBanKeys.stats(), queryFn: getStats });
  const total = BAN_KINDS.reduce((sum, k) => sum + (stats.data?.activeByKind[k] ?? 0), 0);

  return (
    <>
      <PageHeader title={t('admin.ab.title')} />
      <div className={styles.stack}>
        {stats.isError ? (
          <ErrorState compact description={adminErrorMessage(i18n, stats.error)} onRetry={() => void stats.refetch()} />
        ) : (
          <section className={styles.summary} aria-label={t('admin.v2p.ab.summary')} data-search-anchor="ab-summary">
            {stats.data && (
              <Insight
                tone={stats.data.blockedLast24h > 0 ? 'warn' : 'good'}
                parts={t(stats.data.blockedLast24h > 0 ? 'admin.v2p.ab.sentence' : 'admin.v2p.ab.sentenceCalm', {
                  total: formatNumber(total),
                  n: formatNumber(stats.data.blockedLast24h),
                })}
              />
            )}
            <div className={styles.summaryGrid}>
              <StatTile
                label={t('admin.v2p.ab.blocked24h')}
                value={stats.data?.blockedLast24h}
                unit={t('admin.v2p.ab.times')}
                caption={t('admin.v2p.ab.blocked24hHint')}
                icon="shield"
                loading={stats.isLoading}
              />
              <div className={styles.kindCard} data-search-anchor="ab-kinds">
                <p className={styles.kindTitle}>{t('admin.v2p.ab.activeTitle', { n: formatNumber(total) })}</p>
                {total > 0 && (
                  <div className={styles.kindBar} aria-hidden="true">
                    {BAN_KINDS.map((k) => {
                      const n = stats.data?.activeByKind[k] ?? 0;
                      return n > 0 ? (
                        <span key={k} style={{ flexGrow: n, background: KIND_COLOR[k] }} className={styles.kindPart} />
                      ) : null;
                    })}
                  </div>
                )}
                <ul className={styles.kindLegend}>
                  {BAN_KINDS.map((k) => (
                    <li key={k}>
                      <span className={styles.swatch} style={{ background: KIND_COLOR[k] }} aria-hidden="true" />
                      <span>{t(`admin.ab.stat.${k}` as const)}</span>
                      <strong>{formatNumber(stats.data?.activeByKind[k] ?? 0)}</strong>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </section>
        )}
        <Tabs
          label={t('admin.ab.tabs')}
          value={tab}
          onChange={(id) => setTab(id as TabId)}
          tabs={[
            { id: 'bans', label: t('admin.ab.tab.bans') },
            { id: 'bulk', label: t('admin.ab.tab.bulk') },
            { id: 'anon', label: t('admin.ab.tab.anon') },
          ]}
        >
          {tab === 'bans' ? <BansTab /> : tab === 'bulk' ? <BulkTab /> : <AnonymizersTab />}
        </Tabs>
      </div>
    </>
  );
}
