// SAYFA: Kullanıcının sohbetleri ve TÜM mesajları (/admin/users/:id/messages?c=<sohbet>&m=<mesaj>)
// API: GET /api/admin/users/{id}/conversations?cursor&size ve .../conversations/{cid}/messages?before&size (api/adminChat.ts).
// Kullanıcının tüm sohbetleri (silinmiş/ayrılmış/arşivli dahil) ve sohbetteki herkesin mesajları gelir; silinmiş mesajlar,
// düzenleme geçmişi, gölge engelli (iletilmemiş) mesajlar ve tek gönderimlik ekler de görünür. Hiçbir şey gizlenmez.
// Sohbet içeriği SEBEP ister (>= 10 karakter; ReasonGate sorar, her istekte `X-Admin-Reason` ile gider).
// Her sayfa isteği sunucuda otomatik denetim kaydı üretir; düz metin yalnızca önbellekte (gcTime 0) tutulur, depoya yazılmaz.
// Mesajlar yeniden eskiye sayfalanır: en yeni 50 yüklenir, yukarı kaydırdıkça `before` imleciyle eskiler gelir.
// `?m=` verilirse hedef mesaj bulunana dek eski sayfalar yüklenir, mesaja kaydırılır ve vurgulanır.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { adminChatApi, qk } from '../../api';
import { Avatar, Badge, Button, EmptyState, ErrorState, Input, PageHeader, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { ChatBubble } from './chat/ChatBubble';
import { chatReasonKey, useRejectOnReasonError } from './chat/chatReason';
import { ReasonGate } from './chat/ReasonGate';
import { Lightbox } from './chat/Lightbox';
import {
  MESSAGE_PAGE_SIZE,
  collectLightboxItems,
  conversationBadges,
  conversationName,
  dayKey,
  filterConversations,
  flattenPages,
  nextBeforeParam,
  parseId,
  restoredScrollTop,
  shouldLoadOlder,
} from './chat/chatLogic';
import styles from './chat/chat.module.css';
import { adminErrorMessage } from './campaigns/shared';

/** Hedef mesaj aranırken en çok bu kadar eski sayfa istenir (50 mesaj/sayfa). */
const MAX_TARGET_FETCHES = 40;

export default function UserMessagesPage() {
  const { t } = useI18n();
  const userId = Number(useParams().id);
  usePageTitle(t('admin.chat.title'));
  return (
    <ReasonGate storeKey={chatReasonKey.user(userId)}>
      {(reason) => <UserMessagesView userId={userId} reason={reason} />}
    </ReasonGate>
  );
}

function UserMessagesView({ userId, reason }: { userId: number; reason: string }) {
  const i18n = useI18n();
  const { t, formatDate, formatNumber } = i18n;
  const [search, setSearch] = useSearchParams();
  const convId = parseId(search.get('c'));
  const mParam = parseId(search.get('m'));
  const [filter, setFilter] = useState('');
  const [lb, setLb] = useState<number | null>(null);

  const convs = useInfiniteQuery({
    queryKey: qk.adminChat.conversations(userId),
    queryFn: ({ pageParam }) => adminChatApi.listConversations(userId, reason, pageParam, 20),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
    enabled: Number.isInteger(userId) && userId > 0,
    staleTime: Infinity,
    gcTime: 0,
    refetchOnWindowFocus: false,
  });
  const convItems = useMemo(() => convs.data?.pages.flatMap((p) => p.items) ?? [], [convs.data]);
  const userName = convs.data?.pages[0]?.user.displayName ?? `#${userId}`;
  const visibleConvs = useMemo(
    () => filterConversations(convItems, filter, (c) => conversationName(c, t('admin.chat.unknownUser'), t('admin.chat.group'))),
    [convItems, filter, t],
  );

  const msgs = useInfiniteQuery({
    queryKey: qk.adminChat.messages(userId, convId ?? 0),
    queryFn: ({ pageParam }) => adminChatApi.getConversationMessages(userId, convId as number, reason, pageParam, MESSAGE_PAGE_SIZE),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: nextBeforeParam,
    enabled: convId !== null,
    staleTime: Infinity,
    gcTime: 0,
    refetchOnWindowFocus: false,
  });
  // Sunucu sebebi kabul etmezse (400 REASON_REQUIRED) sebep silinir ve kapı yeniden sorar.
  useRejectOnReasonError(chatReasonKey.user(userId), convs.error, msgs.error);
  const messages = useMemo(() => flattenPages(msgs.data?.pages ?? []), [msgs.data]);
  const info = msgs.data?.pages[0]?.conversation;
  const lbItems = useMemo(() => collectLightboxItems(messages, () => null), [messages]);

  // ---- hedef mesaj (?m=): bulunana dek eski sayfaları yükle, kaydır, vurgula ----
  const targetKey = convId !== null && mParam !== null ? `${convId}:${mParam}` : null;
  const targetPresent = mParam !== null && messages.some((x) => x.id === mParam);
  const targetDone = useRef<string | null>(null);
  const targetFetches = useRef(0);
  const pendingTarget = targetKey !== null && !targetPresent && targetDone.current !== targetKey;

  // Kaydırma: ilk yüklemede en alta (hedef yoksa); eski sayfa eklenince konumu koru
  const scroller = useRef<HTMLDivElement>(null);
  const restore = useRef<{ top: number; height: number } | null>(null);
  const initialDone = useRef<number | null>(null);
  useLayoutEffect(() => {
    const el = scroller.current;
    if (!el || messages.length === 0) return;
    if (targetKey && targetPresent && targetDone.current !== targetKey) {
      targetDone.current = targetKey;
      restore.current = null;
      initialDone.current = convId;
      document.getElementById(`msg-${mParam}`)?.scrollIntoView?.({ block: 'center' });
    } else if (restore.current) {
      el.scrollTop = restoredScrollTop(restore.current.top, restore.current.height, el.scrollHeight);
      restore.current = null;
    } else if (initialDone.current !== convId && !pendingTarget) {
      el.scrollTop = el.scrollHeight;
      initialDone.current = convId;
    }
  }, [messages.length, convId, targetKey, targetPresent, pendingTarget, mParam]);

  const { hasNextPage, isFetchingNextPage, fetchNextPage } = msgs;
  useEffect(() => {
    targetFetches.current = 0;
  }, [targetKey]);
  useEffect(() => {
    if (pendingTarget && hasNextPage && !isFetchingNextPage && !msgs.isLoading && targetFetches.current < MAX_TARGET_FETCHES) {
      targetFetches.current += 1;
      void fetchNextPage();
    }
  }, [pendingTarget, hasNextPage, isFetchingNextPage, msgs.isLoading, fetchNextPage, messages.length]);
  const targetMissing = targetKey !== null && !msgs.isLoading && !targetPresent && (!hasNextPage || targetFetches.current >= MAX_TARGET_FETCHES);

  const loadOlder = useCallback(() => {
    const el = scroller.current;
    if (el) restore.current = { top: el.scrollTop, height: el.scrollHeight };
    void fetchNextPage();
  }, [fetchNextPage]);
  const onScroll = () => {
    const el = scroller.current;
    if (el && !pendingTarget && shouldLoadOlder(el.scrollTop, !!hasNextPage, isFetchingNextPage)) loadOlder();
  };

  const select = (id: number) => {
    setLb(null);
    setSearch({ c: String(id) }, { replace: true });
  };
  const back = () => setSearch({}, { replace: true });
  const openMedia = (attachmentId: number) => {
    const i = lbItems.findIndex((x) => x.key === `a${attachmentId}`);
    if (i >= 0) setLb(i);
  };

  const chatTitle = info ? conversationName(info, t('admin.chat.unknownUser'), t('admin.chat.group')) : '';

  return (
    <>
      <PageHeader
        title={t('admin.chat.titleFor', { name: userName })}
        description={t('admin.chat.subtitle')}
        actions={
          <>
            <Link to={paths.admin.chatFeed}>{t('admin.chat.openFeed')}</Link>
            <Link to={paths.admin.user(userId)}>{t('admin.chat.backToUser')}</Link>
          </>
        }
      />
      <p className={styles.auditNote} data-testid="audit-note">
        {t('admin.chat.auditNote')}
      </p>
      <div className={styles.layout} data-open={convId !== null ? 'true' : 'false'}>
        <section className={`${styles.panel} ${styles.listPanel}`} aria-label={t('admin.chat.conversations')}>
          <div className={styles.panelHead}>
            <strong>{t('admin.chat.conversations')}</strong>
            {convItems.length > 0 && <span className={styles.muted}>{formatNumber(convItems.length)}</span>}
          </div>
          <div className={styles.panelSearch}>
            <Input
              type="search"
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              placeholder={t('admin.chat.search')}
              aria-label={t('admin.chat.search')}
            />
          </div>
          {convs.isError ? (
            <ErrorState compact description={adminErrorMessage(i18n, convs.error)} onRetry={() => void convs.refetch()} />
          ) : convs.isLoading ? (
            <Skeleton height="12rem" width="100%" />
          ) : convItems.length === 0 ? (
            <EmptyState compact icon="message" title={t('admin.chat.noConversations')} description=" " />
          ) : (
            <>
              {visibleConvs.length === 0 ? (
                <EmptyState compact icon="search" title={t('admin.chat.noMatch')} description=" " />
              ) : (
                <ul className={styles.convList} data-testid="conversation-list">
                  {visibleConvs.map((c) => {
                    const name = conversationName(c, t('admin.chat.unknownUser'), t('admin.chat.group'));
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
                              <Badge tone="primary">{t(`admin.chat.type.${c.type}`)}</Badge>
                              <Badge tone="neutral">{t('admin.chat.total', { n: formatNumber(c.totalMessages) })}</Badge>
                              {c.type !== 'DIRECT' && <Badge tone="info">{t('admin.chat.members', { n: c.memberCount })}</Badge>}
                              {conversationBadges(c).map((b) => (
                                <Badge key={b} tone={b === 'shadow' || b === 'deleted' ? 'danger' : 'warning'}>
                                  <span data-testid={`conv-badge-${b}`}>{t(`admin.chat.conv.${b}`)}</span>
                                </Badge>
                              ))}
                            </span>
                          </span>
                        </button>
                      </li>
                    );
                  })}
                </ul>
              )}
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

        <section className={`${styles.panel} ${styles.chatPanel}`} aria-label={t('admin.chat.messages')}>
          {convId === null ? (
            <EmptyState compact icon="message" title={t('admin.chat.pick')} description=" " />
          ) : msgs.isError ? (
            <ErrorState compact description={adminErrorMessage(i18n, msgs.error)} onRetry={() => void msgs.refetch()} />
          ) : msgs.isLoading ? (
            <Skeleton height="16rem" width="100%" />
          ) : (
            <>
              <div className={styles.panelHead}>
                <span className={styles.backBtn}>
                  <Button variant="ghost" size="sm" onClick={back}>
                    {t('admin.chat.back')}
                  </Button>
                </span>
                <strong dir="auto">{chatTitle}</strong>
                {info && <Badge tone="primary">{t(`admin.chat.type.${info.type}`)}</Badge>}
                {info?.left && <Badge tone="warning">{t('admin.chat.conv.left')}</Badge>}
                {info?.state?.hiddenByUser && <Badge tone="danger">{t('admin.chat.conv.deleted')}</Badge>}
                {info?.state?.archived && <Badge tone="warning">{t('admin.chat.conv.archived')}</Badge>}
                {info?.members && info.type !== 'DIRECT' && (
                  <span className={styles.muted} dir="auto">
                    {info.members.map((mm) => mm.person.displayName ?? `#${mm.person.id}`).join(', ')}
                  </span>
                )}
              </div>
              <div className={styles.scroller} ref={scroller} onScroll={onScroll} data-testid="message-scroller">
                {hasNextPage && (
                  <div className={styles.loadMore}>
                    <Button variant="secondary" loading={isFetchingNextPage} onClick={loadOlder}>
                      {t('admin.chat.loadOlder')}
                    </Button>
                  </div>
                )}
                {targetMissing && (
                  <p className={styles.muted} role="status" data-testid="target-missing">
                    {t('admin.chat.targetNotFound')}
                  </p>
                )}
                {messages.length === 0 ? (
                  <EmptyState compact icon="message" title={t('admin.chat.noMessages')} description=" " />
                ) : (
                  <ul className={styles.messages} data-testid="message-list">
                    {messages.map((m, i) => (
                      <MessageWithDay
                        key={m.id}
                        prev={messages[i - 1]?.createdAt}
                        m={m}
                        highlighted={targetKey !== null && m.id === mParam}
                        onOpenMedia={openMedia}
                      />
                    ))}
                  </ul>
                )}
              </div>
            </>
          )}
        </section>
      </div>
      {lb !== null && <Lightbox items={lbItems} index={lb} onIndex={setLb} onClose={() => setLb(null)} />}
    </>
  );
}

function MessageWithDay({
  m,
  prev,
  highlighted,
  onOpenMedia,
}: {
  m: Parameters<typeof ChatBubble>[0]['m'];
  prev: string | undefined;
  highlighted: boolean;
  onOpenMedia: (attachmentId: number) => void;
}) {
  const { formatDate } = useI18n();
  const newDay = !prev || dayKey(prev) !== dayKey(m.createdAt);
  return (
    <>
      {newDay && (
        <li className={styles.dayDivider} aria-hidden="true">
          {formatDate(m.createdAt)}
        </li>
      )}
      <ChatBubble m={m} highlighted={highlighted} onOpenMedia={onOpenMedia} />
    </>
  );
}
