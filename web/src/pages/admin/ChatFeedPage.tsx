// SAYFA: Sohbet medyası ve mesajlar (/admin/chat-feed) — tüm sohbetlerdeki fotoğraf/videoları ve mesajları ayrı bir alanda gösterir.
// API: GET /api/admin/chat-media/stats, /api/admin/chat-media, /api/admin/chat-messages (api/adminChat.ts). Her sayfa denetim kaydına yazılır.
// Sohbet içeriği SEBEP ister (ReasonGate; `X-Admin-Reason`). İstatistikler sebepsizdir.
// Silinmiş mesajlar, gölge engelli (iletilmemiş) mesajlar ve tek gönderimlik medya da listelenir; hiçbir şey gizlenmez.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { adminChatApi, qk } from '../../api';
import { EmptyState, Insight, PageHeader, StatTile, Tabs } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { chatReasonKey } from './chat/chatReason';
import { ReasonGate } from './chat/ReasonGate';
import { EMPTY_FILTERS, FeedFilters, MediaTab, MessagesTab, type FeedFilterState } from './chat/FeedParts';
import { parseId } from './chat/chatLogic';
import { FilterFold, formatBytesLocal } from './moderation/v2';
import v2 from './moderation/v2.module.css';
import styles from './chat/chat.module.css';

export default function ChatFeedPage() {
  const { t, formatNumber } = useI18n();
  usePageTitle(t('admin.chatFeed.title'));
  const [tab, setTab] = useState<'media' | 'messages'>('media');
  const [filters, setFilters] = useState<FeedFilterState>(EMPTY_FILTERS);
  const stats = useQuery({ queryKey: qk.adminChat.mediaStats(), queryFn: adminChatApi.chatMediaStats, staleTime: 60_000 });
  const s = stats.data;
  // W1-B (T-015): sunucu süzgeçsiz akışı 400 FEED_FILTER_REQUIRED ile reddeder; süzgeç seçilmeden istek atılmaz.
  const hasFilter = filters.user !== null || parseId(filters.conversationId || null) !== null;
  const total = s ? s.imageCount + s.videoCount : 0;
  const imgPct = total > 0 && s ? Math.round((s.imageCount / total) * 100) : 0;
  const activeCount = [
    filters.kind !== '',
    filters.user !== null,
    filters.conversationId !== '',
    filters.from !== '',
    filters.to !== '',
    filters.viewOnce,
    filters.deleted,
    filters.suppressed,
    filters.hasMedia,
  ].filter(Boolean).length;

  return (
    <>
      <PageHeader title={t('admin.chatFeed.title')} description={t('admin.chatFeed.subtitle')} />
      <p className={styles.auditNote} data-search-anchor="chatfeed-audit-note">
        <strong>{t('admin.v2m.chat.auditLead')}</strong> {t('admin.chat.auditNote')}
      </p>
      <div className={v2.tiles} data-testid="chat-stats" data-search-anchor="chatfeed-stats">
        <StatTile
          label={t('admin.chatFeed.stats.images')}
          value={s?.imageCount}
          loading={stats.isLoading}
          error={stats.isError}
          onRetry={() => void stats.refetch()}
        />
        <StatTile
          label={t('admin.chatFeed.stats.videos')}
          value={s?.videoCount}
          loading={stats.isLoading}
          error={stats.isError}
          onRetry={() => void stats.refetch()}
        />
        <StatTile
          label={t('admin.v2m.chat.viewOnce')}
          value={s?.viewOnceCount}
          loading={stats.isLoading}
          error={stats.isError}
          caption={t('admin.v2m.chat.viewOnceHint')}
        />
        <StatTile
          label={t('admin.v2m.chat.deleted')}
          value={s?.deletedMessageMediaCount}
          loading={stats.isLoading}
          error={stats.isError}
          caption={t('admin.v2m.chat.deletedHint')}
        />
        <StatTile
          label={t('admin.v2m.chat.purged')}
          value={s?.purgedCount}
          loading={stats.isLoading}
          error={stats.isError}
          caption={t('admin.v2m.chat.purgedHint')}
        />
        <StatTile
          label={t('admin.chatFeed.stats.size')}
          value={s ? formatBytesLocal(s.totalBytes, formatNumber) : undefined}
          loading={stats.isLoading}
          error={stats.isError}
          caption={s ? t('admin.chatFeed.stats.last24h', { n: formatNumber(s.last24h.imageCount + s.last24h.videoCount) }) : undefined}
        />
      </div>
      {s && total > 0 && (
        <Insight
          className={v2.sentence}
          parts={[
            t('admin.v2m.chat.sentenceTotal', { n: formatNumber(total) }),
            ' ',
            { text: t('admin.v2m.chat.sentenceSplit', { img: formatNumber(imgPct), vid: formatNumber(100 - imgPct) }) },
            ' ',
            t('admin.v2m.chat.sentenceNew', { n: formatNumber(s.last24h.imageCount + s.last24h.videoCount) }),
          ]}
        />
      )}
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
            <FilterFold activeCount={activeCount} anchor="chatfeed-filters" defaultOpen={!hasFilter}>
              <FeedFilters tab={tab} value={filters} onChange={setFilters} />
            </FilterFold>
            {!hasFilter ? (
              <EmptyState
                compact
                icon="search"
                title={t('admin.wp02.chatFeed.filterRequired.title')}
                description={t('admin.v2m.chat.filterRequiredText')}
              />
            ) : tab === 'media' ? (
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
