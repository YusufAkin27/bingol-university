// SAYFA: Push altyapısı (/admin/push/ops)  [P14] — sekmeler: FCM durumu, Kuyruk, Cihazlar, Bildirim istatistikleri.
// API: GET /api/admin/push/fcm/status, POST .../fcm/validate; GET /api/admin/push/outbox (+ /{id}, POST /{id}/retry, /{id}/cancel,
//      /bulk), GET /api/admin/push/outbox/stats; GET /api/admin/push/devices/summary; GET /api/admin/notifications/stats
//      (api/adminPushOps.ts). Hiçbir uç push yükü, ham token ya da tam kullanıcı kimliği döndürmez.
import { SearchAnchor } from '../../search/anchor';
import { useUrlTab } from '../../search/useUrlTab';
import { PageHeader, Tabs } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { DevicesTab } from './pushops/DevicesTab';
import { FcmTab } from './pushops/FcmTab';
import { QueueTab } from './pushops/QueueTab';
import { StatsTab } from './pushops/StatsTab';

type TabId = 'fcm' | 'queue' | 'devices' | 'stats';
const TABS: TabId[] = ['fcm', 'queue', 'devices', 'stats'];

export default function PushOpsPage() {
  const { t } = useI18n();
  usePageTitle(t('admin.p14.title'));
  const [tab, setTab] = useUrlTab<TabId>(TABS, 'fcm'); // ?tab=queue: arama derin bağlantısı sekmeyi açar

  return (
    <>
      <PageHeader title={t('admin.p14.title')} description={t('admin.p14.desc')} />
      <Tabs
        label={t('admin.p14.tabs')}
        value={tab}
        onChange={(id) => setTab(id as TabId)}
        tabs={TABS.map((id) => ({ id, label: t(`admin.p14.tab.${id}`) }))}
      >
        {tab === 'fcm' && (
          <SearchAnchor id="tab-fcm">
            <FcmTab />
          </SearchAnchor>
        )}
        {tab === 'queue' && (
          <SearchAnchor id="tab-queue">
            <QueueTab />
          </SearchAnchor>
        )}
        {tab === 'devices' && (
          <SearchAnchor id="tab-devices">
            <DevicesTab />
          </SearchAnchor>
        )}
        {tab === 'stats' && (
          <SearchAnchor id="tab-stats">
            <StatsTab />
          </SearchAnchor>
        )}
      </Tabs>
    </>
  );
}
