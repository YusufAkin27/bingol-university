// SAYFA: Erişim engelleri (/admin/security/access-bans)
// API: GET /api/admin/access-bans/stats ve liste/ekle/düzenle/sil/bulk/attempts/anonymizers uçları (api/accessBans.ts).
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { accessBanKeys, BAN_KINDS, getStats } from '../../api/accessBans';
import { ErrorState, PageHeader, StatCard, Tabs } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import styles from './accessbans/accessBans.module.css';
import { AnonymizersTab } from './accessbans/AnonymizersTab';
import { BansTab } from './accessbans/BansTab';
import { BulkTab } from './accessbans/BulkTab';
import { adminErrorMessage } from './campaigns/shared';

type TabId = 'bans' | 'bulk' | 'anon';

export default function AccessBansPage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  usePageTitle(t('admin.ab.title'));
  const [tab, setTab] = useState<TabId>('bans');
  const stats = useQuery({ queryKey: accessBanKeys.stats(), queryFn: getStats });

  return (
    <>
      <PageHeader title={t('admin.ab.title')} />
      <div className={styles.stack}>
        {stats.isError ? (
          <ErrorState compact description={adminErrorMessage(i18n, stats.error)} onRetry={() => void stats.refetch()} />
        ) : (
          <div className={styles.stats}>
            {BAN_KINDS.map((k) => (
              <StatCard
                key={k}
                title={t(`admin.ab.stat.${k}` as const)}
                loading={stats.isLoading}
                value={formatNumber(stats.data?.activeByKind[k] ?? 0)}
              />
            ))}
            <StatCard
              title={t('admin.ab.stat.blocked24h')}
              loading={stats.isLoading}
              value={formatNumber(stats.data?.blockedLast24h ?? 0)}
            />
          </div>
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
