import { useState } from 'react';
import type { AdminUserDetail } from '../../../api/types';
import { useCan } from '../../../auth/permissions';
import { Card, Tabs } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { ExportTab } from './ExportTab';
import { NotificationsTab } from './NotificationsTab';
import { ProfileTab } from './ProfileTab';
import { PushDevicesTab } from './PushDevicesTab';
import { SessionsTab } from './SessionsTab';
import styles from './users.module.css';

export type DeepTab = 'profile' | 'sessions' | 'devices' | 'notifications' | 'export';
const TABS: DeepTab[] = ['profile', 'sessions', 'devices', 'notifications', 'export'];

/** Sekmenin sunucuda istediği izin (AdminPermissionPolicy): oturum/cihaz = users.pii, dışa aktarma = users.export. */
export const TAB_PERM: Partial<Record<DeepTab, string>> = {
  sessions: 'users.pii',
  devices: 'users.pii',
  export: 'users.export',
};

/** P09: kullanıcı derin yönetimi sekmeleri (profil müdahalesi, oturumlar, cihazlar, bildirimler, KVKK dışa aktarma). */
export function UserDeepTabs({ user }: { user: AdminUserDetail }) {
  const { t } = useI18n();
  const [tab, setTab] = useState<DeepTab>('profile');
  const canPii = useCan(TAB_PERM.sessions);
  const canExport = useCan(TAB_PERM.export);
  // yetkisiz sekme hiç gösterilmez (A3-04): 403 "veriler yüklenemedi" yerine sade arayüz
  const visible = TABS.filter((id) => (id === 'sessions' || id === 'devices' ? canPii : id === 'export' ? canExport : true));

  if (user.status === 'DELETED') {
    return (
      <Card title={t('admin.p09.title')}>
        <p className={styles.hint}>{t('admin.p09.deleted')}</p>
      </Card>
    );
  }

  return (
    <Card title={t('admin.p09.title')}>
      <Tabs
        label={t('admin.p09.tabs')}
        value={tab}
        onChange={(id) => setTab(id as DeepTab)}
        tabs={visible.map((id) => ({ id, label: t(`admin.p09.tab.${id}`) }))}
      >
        {tab === 'profile' && <ProfileTab user={user} />}
        {tab === 'sessions' && <SessionsTab userId={user.id} />}
        {tab === 'devices' && <PushDevicesTab userId={user.id} />}
        {tab === 'notifications' && <NotificationsTab userId={user.id} />}
        {tab === 'export' && <ExportTab user={user} />}
      </Tabs>
    </Card>
  );
}
