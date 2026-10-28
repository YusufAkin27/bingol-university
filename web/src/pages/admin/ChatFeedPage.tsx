// SAYFA: Sohbet medyası ve mesajlar (/admin/chat-feed) — tüm sohbetlerdeki fotoğraf/videoları ve mesajları ayrı bir alanda gösterir.
// API: GET /api/admin/chat-media/stats, /api/admin/chat-media, /api/admin/chat-messages (api/adminChat.ts). Her sayfa denetim kaydına yazılır.
// Sohbet içeriği SEBEP ister (ReasonGate; `X-Admin-Reason`). İstatistikler sebepsizdir.
// Silinmiş mesajlar, gölge engelli (iletilmemiş) mesajlar ve tek gönderimlik medya da listelenir; hiçbir şey gizlenmez.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { adminChatApi, qk } from '../../api';
import { PageHeader, StatCard, Tabs } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { chatReasonKey } from './chat/chatReason';
import { ReasonGate } from './chat/ReasonGate';
import { EMPTY_FILTERS, FeedFilters, MediaTab, MessagesTab, type FeedFilterState } from './chat/FeedParts';
import { formatBytes } from './chat/chatLogic';
import styles from './chat/chat.module.css';

export default function ChatFeedPage() {
  const { t, formatNumber } = useI18n();
  usePageTitle(t('admin.chatFeed.title'));
  const [tab, setTab] = useState<'media' | 'messages'>('media');
  const [filters, setFilters] = useState<FeedFilterState>(EMPTY_FILTERS);
  const stats = useQuery({ queryKey: qk.adminChat.mediaStats(), queryFn: adminChatApi.chatMediaStats, staleTime: 60_000 });
  const s = stats.data;
  const n = (v: number | undefined) => (v === undefined ? '—' : formatNumber(v));

  return (
    <>
      <PageHeader title={t('admin.chatFeed.title')} description={t('admin.chatFeed.subtitle')} />
      <p className={styles.auditNote}>{t('admin.chat.auditNote')}</p>
      <div className={styles.statGrid} data-testid="chat-stats">
        <StatCard title={t('admin.chatFeed.stats.images')} value={n(s?.imageCount)} loading={stats.isLoading} />
        <StatCard title={t('admin.chatFeed.stats.videos')} value={n(s?.videoCount)} loading={stats.isLoading} />
        <StatCard title={t('admin.chatFeed.stats.viewOnce')} value={n(s?.viewOnceCount)} loading={stats.isLoading} />
        <StatCard
          title={t('admin.chatFeed.stats.deleted')}
          value={n(s?.deletedMessageMediaCount)}
          loading={stats.isLoading}
        />
        <StatCard title={t('admin.chatFeed.stats.purged')} value={n(s?.purgedCount)} loading={stats.isLoading} />
        <StatCard
          title={t('admin.chatFeed.stats.size')}
          value={s ? formatBytes(s.totalBytes) : '—'}
          hint={s ? t('admin.chatFeed.stats.last24h', { n: formatNumber(s.last24h.imageCount + s.last24h.videoCount) }) : undefined}
          loading={stats.isLoading}
        />
      </div>
      <ReasonGate storeKey={chatReasonKey.feed()}>
        {(reason) => (
          <>
            <Tabs
              label={t('admin.chatFeed.tabs')}
              value={tab}
              onChange={(id) => setTab(id as 'media' | 'messages')}
              tabs={[
                { id: 'media', label: t('admin.chatFeed.tab.media') },
                { id: 'messages', label: t('admin.chatFeed.tab.messages') },
              ]}
            />
            <FeedFilters tab={tab} value={filters} onChange={setFilters} />
            {tab === 'media' ? (
              <MediaTab filters={filters} reason={reason} />
            ) : (
              <MessagesTab filters={filters} reason={reason} />
            )}
          </>
        )}
      </ReasonGate>
    </>
  );
}
