// SAYFA: Kulüpler (/admin/communities) — "Tüm kulüpler" yönetimi + "Onay kuyruğu" (eski CommunitiesAdminPage) sekmeleri.
// API: GET /api/admin/communities?page= (liste), /{id} (ayrıntı), PATCH, close/reopen, DELETE, üyeler, devir, başvurular,
// davetler, CSV (api/adminCommunities.ts); onay kuyruğu için api/approvals.ts. Ayrıntı çekmecesi `?club=<id>` ile açılır.
import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { PageHeader, Tabs } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import CommunitiesAdminPage from './CommunitiesAdminPage';
import { ClubDrawer } from './clubs/ClubDrawer';
import { ClubList } from './clubs/ClubList';
import styles from './clubs/clubs.module.css';

type MainTab = 'all' | 'queue';

export default function ClubsManagePage() {
  const { t } = useI18n();
  usePageTitle(t('admin.p06.clubs.title'));
  const [params, setParams] = useSearchParams();
  const clubParam = Number(params.get('club'));
  // Onay kuyruğu bağlantıları (?status=...) doğrudan kuyruk sekmesini açar.
  const [tab, setTab] = useState<MainTab>(params.get('tab') === 'queue' || params.has('status') ? 'queue' : 'all');
  const [openId, setOpenId] = useState<number | null>(Number.isInteger(clubParam) && clubParam > 0 ? clubParam : null);

  function open(id: number | null) {
    setOpenId(id);
    const next = new URLSearchParams(params);
    if (id === null) next.delete('club');
    else next.set('club', String(id));
    setParams(next, { replace: true });
  }

  return (
    <div>
      <PageHeader title={t('admin.p06.clubs.title')} description={t('admin.p06.clubs.subtitle')} />
      <div className={styles.tabsWrap}>
        <Tabs
          label={t('admin.p06.clubs.tabs')}
          value={tab}
          tabs={[
            { id: 'all', label: t('admin.p06.clubs.tab.all') },
            { id: 'queue', label: t('admin.p06.clubs.tab.queue') },
          ]}
          onChange={(id) => setTab(id as MainTab)}
        />
      </div>
      {tab === 'all' ? <ClubList onOpen={open} /> : <CommunitiesAdminPage embedded />}
      {openId !== null && <ClubDrawer id={openId} onClose={() => open(null)} />}
    </div>
  );
}
