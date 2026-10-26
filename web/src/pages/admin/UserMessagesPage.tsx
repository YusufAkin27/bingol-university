// SAYFA: Kullanıcının mesajları (/admin/users/:id/messages?c=<konuşma>)
// API: GET /api/admin/users/{id}/conversations?cursor&size ve .../conversations/{cid}/messages?before&size (api/adminChat.ts).
// Her sayfa isteği sunucuda otomatik denetim kaydı üretir; düz metin yalnızca önbellekte (gcTime 0) tutulur, depoya yazılmaz.
// Mesajlar yeniden eskiye sayfalanır: en yeni 50 yüklenir, yukarı kaydırdıkça `before` imleciyle eskiler gelir.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useCallback, useLayoutEffect, useMemo, useRef } from 'react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { adminChatApi, qk } from '../../api';
import { Avatar, Badge, Button, EmptyState, ErrorState, PageHeader, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { ChatBubble } from './chat/ChatBubble';
import {
  MESSAGE_PAGE_SIZE,
  dayKey,
  flattenPages,
  nextBeforeParam,
  restoredScrollTop,
  shouldLoadOlder,
} from './chat/chatLogic';
import styles from './chat/chat.module.css';
import { adminErrorMessage } from './campaigns/shared';

export default function UserMessagesPage() {
  const i18n = useI18n();
  const { t, formatDate, formatNumber } = i18n;
  const params = useParams();
  const userId = Number(params.id);
  const [search, setSearch] = useSearchParams();
  const convId = search.get('c') ? Number(search.get('c')) : null;
  usePageTitle(t('admin.chat.title'));

  const convs = useInfiniteQuery({
    queryKey: qk.adminChat.conversations(userId),
    queryFn: ({ pageParam }) => adminChatApi.listConversations(userId, pageParam, 20),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    enabled: Number.isInteger(userId) && userId > 0,
    staleTime: Infinity,
    gcTime: 0,
    refetchOnWindowFocus: false,
  });
  const convItems = useMemo(() => convs.data?.pages.flatMap((p) => p.items) ?? [], [convs.data]);
  const userName = convs.data?.pages[0]?.user.displayName ?? `#${userId}`;

  const msgs = useInfiniteQuery({
    queryKey: qk.adminChat.messages(userId, convId ?? 0),
    queryFn: ({ pageParam }) => adminChatApi.getConversationMessages(userId, convId as number, pageParam, MESSAGE_PAGE_SIZE),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: nextBeforeParam,
    enabled: convId !== null && Number.isInteger(convId),
    staleTime: Infinity,
    gcTime: 0,
    refetchOnWindowFocus: false,
  });
  const messages = useMemo(() => flattenPages(msgs.data?.pages ?? []), [msgs.data]);
  const info = msgs.data?.pages[0]?.conversation;

  // Kaydırma: ilk yüklemede en alta; eski sayfa eklenince konumu koru
  const scroller = useRef<HTMLDivElement>(null);
  const restore = useRef<{ top: number; height: number } | null>(null);
  const initialDone = useRef<number | null>(null);
  useLayoutEffect(() => {
    const el = scroller.current;
    if (!el || messages.length === 0) return;
    if (restore.current) {
      el.scrollTop = restoredScrollTop(restore.current.top, restore.current.height, el.scrollHeight);
      restore.current = null;
    } else if (initialDone.current !== convId) {
      el.scrollTop = el.scrollHeight;
      initialDone.current = convId;
    }
  }, [messages.length, convId]);

  const { hasNextPage, isFetchingNextPage, fetchNextPage } = msgs;
  const loadOlder = useCallback(() => {
    const el = scroller.current;
    if (el) restore.current = { top: el.scrollTop, height: el.scrollHeight };
    void fetchNextPage();
  }, [fetchNextPage]);
  const onScroll = () => {
    const el = scroller.current;
    if (el && shouldLoadOlder(el.scrollTop, !!hasNextPage, isFetchingNextPage)) loadOlder();
  };

  const select = (id: number) => setSearch({ c: String(id) }, { replace: true });

  return (
    <>
      <PageHeader
        title={t('admin.chat.titleFor', { name: userName })}
        description={t('admin.chat.subtitle')}
        actions={<Link to={paths.admin.user(userId)}>{t('admin.chat.backToUser')}</Link>}
      />
      <div className={styles.layout}>
        <section className={styles.panel} aria-label={t('admin.chat.conversations')}>
          <div className={styles.panelHead}>
            <strong>{t('admin.chat.conversations')}</strong>
          </div>
          {convs.isError ? (
            <ErrorState compact description={adminErrorMessage(i18n, convs.error)} onRetry={() => void convs.refetch()} />
          ) : convs.isLoading ? (
            <Skeleton height="12rem" width="100%" />
          ) : convItems.length === 0 ? (
            <EmptyState compact icon="message" title={t('admin.chat.noConversations')} description=" " />
          ) : (
            <>
              <ul className={styles.convList} data-testid="conversation-list">
                {convItems.map((c) => {
                  const name = c.type === 'DIRECT' ? (c.peer?.displayName ?? t('admin.chat.unknownUser')) : (c.title ?? t('admin.chat.group'));
                  const last = c.lastMessage;
                  return (
                    <li key={c.id}>
                      <button
                        type="button"
                        className={styles.convBtn}
                        aria-current={c.id === convId ? 'true' : undefined}
                        onClick={() => select(c.id)}
                      >
                        <Avatar name={name} src={c.peer?.avatarUrl} size={40} />
                        <span className={styles.convBody}>
                          <span className={styles.convTop}>
                            <span className={styles.convTitle} dir="auto">
                              {name}
                            </span>
                            <span className={styles.muted}>{c.lastActivityAt ? formatDate(c.lastActivityAt) : ''}</span>
                          </span>
                          <span className={styles.preview} dir="auto">
                            {last
                              ? last.text !== null
                                ? `${last.deleted ? `[${t('admin.chat.badge.deleted')}] ` : ''}${last.text}`
                                : t('admin.chat.failed', { reason: last.error ?? '?' })
                              : t('admin.chat.noPreview')}
                          </span>
                          <span className={styles.badges}>
                            <Badge tone="neutral">{t('admin.chat.total', { n: formatNumber(c.totalMessages) })}</Badge>
                            {c.type === 'GROUP' && <Badge tone="info">{t('admin.chat.members', { n: c.memberCount })}</Badge>}
                            {c.left && <Badge tone="warning">{t('admin.chat.left')}</Badge>}
                          </span>
                        </span>
                      </button>
                    </li>
                  );
                })}
              </ul>
              {convs.hasNextPage && (
                <div className={styles.loadMore}>
                  <Button variant="secondary" loading={convs.isFetchingNextPage} onClick={() => void convs.fetchNextPage()}>
                    {t('admin.chat.moreConversations')}
                  </Button>
                </div>
              )}
            </>
          )}
        </section>

        <section className={styles.panel} aria-label={t('admin.chat.messages')}>
          {convId === null ? (
            <EmptyState compact icon="message" title={t('admin.chat.pick')} description=" " />
          ) : msgs.isError ? (
            <ErrorState compact description={adminErrorMessage(i18n, msgs.error)} onRetry={() => void msgs.refetch()} />
          ) : msgs.isLoading ? (
            <Skeleton height="16rem" width="100%" />
          ) : (
            <>
              <div className={styles.panelHead}>
                <strong dir="auto">
                  {info?.type === 'DIRECT' ? (info.peer?.displayName ?? t('admin.chat.unknownUser')) : (info?.title ?? t('admin.chat.group'))}
                </strong>
                {info?.left && <Badge tone="warning">{t('admin.chat.left')}</Badge>}
              </div>
              <div className={styles.scroller} ref={scroller} onScroll={onScroll} data-testid="message-scroller">
                {hasNextPage && (
                  <div className={styles.loadMore}>
                    <Button variant="secondary" loading={isFetchingNextPage} onClick={loadOlder}>
                      {t('admin.chat.loadOlder')}
                    </Button>
                  </div>
                )}
                {messages.length === 0 ? (
                  <EmptyState compact icon="message" title={t('admin.chat.noMessages')} description=" " />
                ) : (
                  <ul className={styles.messages} data-testid="message-list">
                    {messages.map((m, i) => (
                      <MessageWithDay key={m.id} prev={messages[i - 1]?.createdAt} m={m} />
                    ))}
                  </ul>
                )}
              </div>
            </>
          )}
        </section>
      </div>
    </>
  );
}

function MessageWithDay({ m, prev }: { m: Parameters<typeof ChatBubble>[0]['m']; prev: string | undefined }) {
  const { formatDate } = useI18n();
  const newDay = !prev || dayKey(prev) !== dayKey(m.createdAt);
  return (
    <>
      {newDay && (
        <li className={styles.dayDivider} aria-hidden="true">
          {formatDate(m.createdAt)}
        </li>
      )}
      <ChatBubble m={m} />
    </>
  );
}
