// Kulüp ayrıntı çekmecesi: Genel, Üyeler, Başvurular, Gönderiler, Duyurular, Denetim, Tehlikeli bölge.
// Kaydedilmemiş form değişikliği varken sekme/çekmece kapatma `useUnsavedGuard` ile onaya bağlanır.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { getClub } from '../../../api/adminCommunities';
import { useUnsavedGuard } from '../../../components/admin/guard/useUnsavedGuard';
import { Badge, Drawer, ErrorState, Skeleton, StatusPill, Tabs } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { ClubAuditTab } from './ClubAuditTab';
import { ClubDangerTab } from './ClubDangerTab';
import { ClubGeneralTab } from './ClubGeneralTab';
import { ClubMembersTab } from './ClubMembersTab';
import { ClubRequestsTab } from './ClubRequestsTab';
import { ContentList } from './ContentList';
import { statusTone } from './clubsLogic';
import styles from './clubs.module.css';

export type ClubTab = 'general' | 'members' | 'requests' | 'posts' | 'announcements' | 'audit' | 'danger';
const TABS: ClubTab[] = ['general', 'members', 'requests', 'posts', 'announcements', 'audit', 'danger'];

export function ClubDrawer({ id, onClose }: { id: number; onClose: () => void }) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const [tab, setTab] = useState<ClubTab>('general');
  const [dirty, setDirty] = useState(false);
  const guard = useUnsavedGuard(dirty);
  const q = useQuery({ queryKey: ['communities', 'admin', 'detail', id], queryFn: () => getClub(id) });
  const d = q.data;

  return (
    <>
      <Drawer
        open
        size="lg"
        onClose={() => guard.confirmLeave(onClose)}
        title={d?.club.name ?? t('admin.p06.drawer.loading')}
      >
        {q.isError ? (
          <ErrorState description={adminError(i18n, q.error)} onRetry={() => void q.refetch()} />
        ) : q.isPending || !d ? (
          <Skeleton height="12rem" width="100%" />
        ) : (
          <>
            <div className={styles.head}>
              <div className={styles.headRow}>
                <StatusPill tone={statusTone(d.club.status)}>{t(`admin.p06.status.${d.club.status}`)}</StatusPill>
                <Badge>{formatNumber(d.club.memberCount)} {t('admin.p06.drawer.membersShort')}</Badge>
                {d.club.pendingCount > 0 && (
                  <Badge tone="warning">{t('admin.p06.drawer.pending', { n: d.club.pendingCount })}</Badge>
                )}
                {d.club.openReportCount > 0 && (
                  <Badge tone="danger">{t('admin.p06.drawer.reports', { n: d.club.openReportCount })}</Badge>
                )}
              </div>
            </div>
            <Tabs
              label={t('admin.p06.drawer.tabs')}
              value={tab}
              tabs={TABS.map((id2) => ({ id: id2, label: t(`admin.p06.tab.${id2}`) }))}
              onChange={(next) => guard.confirmLeave(() => setTab(next as ClubTab))}
            />
            {tab === 'general' && <ClubGeneralTab detail={d} onDirtyChange={setDirty} />}
            {tab === 'members' && <ClubMembersTab communityId={id} clubName={d.club.name} />}
            {tab === 'requests' && <ClubRequestsTab communityId={id} clubName={d.club.name} />}
            {tab === 'posts' && (
              <div className={styles.panel}>
                <ContentList communityId={id} kind="POST" />
              </div>
            )}
            {tab === 'announcements' && (
              <div className={styles.panel}>
                <ContentList communityId={id} kind="ANNOUNCEMENT" />
              </div>
            )}
            {tab === 'audit' && <ClubAuditTab communityId={id} />}
            {tab === 'danger' && <ClubDangerTab detail={d} />}
          </>
        )}
      </Drawer>
      {guard.dialog}
    </>
  );
}
