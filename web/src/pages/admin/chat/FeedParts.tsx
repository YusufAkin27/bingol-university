// Toplu izleme alanının parçaları: kullanıcı seçici, ortak süzgeç çubuğu, medya ızgarası ve mesaj akışı.
// API: GET /api/admin/chat-media, /api/admin/chat-messages (imleç tabanlı; api/adminChat.ts).
import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { adminChatApi, qk, usersApi } from '../../../api';
import type { AdminFeedMessage } from '../../../api/types';
import {
  Avatar,
  Badge,
  Button,
  Checkbox,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  LoadMore,
  Select,
  Skeleton,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue } from '../../../lib/hooks';
import { adminErrorMessage } from '../campaigns/shared';
import { ChatBubble } from './ChatBubble';
import { chatReasonKey, useRejectOnReasonError } from './chatReason';
import { Lightbox } from './Lightbox';
import { MediaBadges, MediaThumb } from './MediaThumb';
import { collectLightboxItems, mediaToItem, nextCursorParam, parseId, viewerLink } from './chatLogic';
import styles from './chat.module.css';

export interface FeedFilterState {
  user: { id: number; name: string } | null;
  conversationId: string;
  from: string;
  to: string;
  kind: '' | 'IMAGE' | 'VIDEO';
  viewOnce: boolean;
  deleted: boolean;
  suppressed: boolean;
  hasMedia: boolean;
}

export const EMPTY_FILTERS: FeedFilterState = {
  user: null,
  conversationId: '',
  from: '',
  to: '',
  kind: '',
  viewOnce: false,
  deleted: false,
  suppressed: false,
  hasMedia: false,
};

/** Kullanıcı arama seçici (GET /api/admin/users?q=); tek kullanıcı seçilir. */
export function UserFilter({
  value,
  onChange,
}: {
  value: { id: number; name: string } | null;
  onChange: (u: { id: number; name: string } | null) => void;
}) {
  const { t } = useI18n();
  const [text, setText] = useState('');
  const q = useDebouncedValue(text.trim(), 300);
  const search = useQuery({
    queryKey: qk.adminChat.userSearch(q),
    queryFn: () => usersApi.listUsers({ q, size: 8 }),
    enabled: q.length >= 2 && !value,
  });
  if (value) {
    return (
      <div className={styles.picked} data-testid="picked-user">
        <Badge tone="primary">{value.name}</Badge>
        <Button variant="ghost" size="sm" onClick={() => onChange(null)}>
          {t('admin.chatFeed.filter.clearUser')}
        </Button>
      </div>
    );
  }
  const results = search.data?.items ?? [];
  return (
    <div>
      <Input
        type="search"
        value={text}
        placeholder={t('admin.chatFeed.filter.userPlaceholder')}
        aria-label={t('admin.chatFeed.filter.user')}
        onChange={(e) => setText(e.target.value)}
      />
      {q.length >= 2 && results.length > 0 && (
        <ul className={styles.pickResults}>
          {results.map((u) => (
            <li key={u.id}>
              <button
                type="button"
                onClick={() => {
                  onChange({ id: u.id, name: u.displayName });
                  setText('');
                }}
              >
                {u.displayName} <span className={styles.muted}>{u.email}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/** Süzgeç çubuğu; `tab` hangi alanların gösterileceğini belirler. */
export function FeedFilters({
  tab,
  value,
  onChange,
}: {
  tab: 'media' | 'messages';
  value: FeedFilterState;
  onChange: (next: FeedFilterState) => void;
}) {
  const { t } = useI18n();
  const set = (p: Partial<FeedFilterState>) => onChange({ ...value, ...p });
  return (
    <div className={styles.filters} role="search" aria-label={t('admin.chatFeed.filters')}>
      {tab === 'media' && (
        <FormField label={t('admin.chatFeed.filter.kind')}>
          <Select value={value.kind} onChange={(e) => set({ kind: e.target.value as FeedFilterState['kind'] })}>
            <option value="">{t('admin.chatFeed.filter.kindAll')}</option>
            <option value="IMAGE">{t('admin.chat.image')}</option>
            <option value="VIDEO">{t('admin.chat.media.video')}</option>
          </Select>
        </FormField>
      )}
      <FormField label={t('admin.chatFeed.filter.user')}>
        <UserFilter value={value.user} onChange={(user) => set({ user })} />
      </FormField>
      <FormField label={t('admin.chatFeed.filter.conversation')}>
        <Input
          inputMode="numeric"
          value={value.conversationId}
          placeholder="ID"
          onChange={(e) => set({ conversationId: e.target.value.replace(/\D/g, '') })}
        />
      </FormField>
      <FormField label={t('admin.chatFeed.filter.from')}>
        <Input type="date" value={value.from} onChange={(e) => set({ from: e.target.value })} />
      </FormField>
      <FormField label={t('admin.chatFeed.filter.to')}>
        <Input type="date" value={value.to} onChange={(e) => set({ to: e.target.value })} />
      </FormField>
      <div className={styles.checks}>
        {tab === 'media' && (
          <Checkbox
            label={t('admin.chatFeed.filter.viewOnce')}
            checked={value.viewOnce}
            onChange={(e) => set({ viewOnce: e.target.checked })}
          />
        )}
        <Checkbox
          label={t('admin.chatFeed.filter.deleted')}
          checked={value.deleted}
          onChange={(e) => set({ deleted: e.target.checked })}
        />
        {tab === 'messages' && (
          <>
            <Checkbox
              label={t('admin.chatFeed.filter.suppressed')}
              checked={value.suppressed}
              onChange={(e) => set({ suppressed: e.target.checked })}
            />
            <Checkbox
              label={t('admin.chatFeed.filter.hasMedia')}
              checked={value.hasMedia}
              onChange={(e) => set({ hasMedia: e.target.checked })}
            />
          </>
        )}
        <Button variant="ghost" size="sm" onClick={() => onChange(EMPTY_FILTERS)}>
          {t('admin.chatFeed.filter.reset')}
        </Button>
      </div>
    </div>
  );
}

/** Liste sonuna gelince sonraki sayfayı ister (IntersectionObserver yoksa yalnızca düğme çalışır). */
function useAutoLoad(enabled: boolean, load: () => void) {
  const ref = useRef<HTMLDivElement>(null);
  const loadRef = useRef(load);
  loadRef.current = load;
  useEffect(() => {
    const el = ref.current;
    if (!enabled || !el || typeof IntersectionObserver === 'undefined') return;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) loadRef.current();
    });
    io.observe(el);
    return () => io.disconnect();
  }, [enabled]);
  return ref;
}

export function MediaTab({ filters, reason }: { filters: FeedFilterState; reason: string }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const convId = parseId(useDebouncedValue(filters.conversationId, 400) || null);
  const f = useMemo(
    () => ({
      kind: filters.kind,
      viewOnce: filters.viewOnce,
      deleted: filters.deleted,
      userId: filters.user?.id ?? null,
      conversationId: convId,
      from: filters.from,
      to: filters.to,
    }),
    [filters, convId],
  );
  const q = useInfiniteQuery({
    queryKey: qk.adminChat.media(f),
    queryFn: ({ pageParam }) => adminChatApi.listChatMedia(f, reason, pageParam, 30),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: nextCursorParam,
    staleTime: 30_000,
  });
  // Sunucu sebebi kabul etmezse (400 REASON_REQUIRED) sebep silinir ve kapı yeniden sorar.
  useRejectOnReasonError(chatReasonKey.feed(), q.error);
  const items = useMemo(() => q.data?.pages.flatMap((p) => p.items) ?? [], [q.data]);
  const lbItems = useMemo(
    () => items.map((x) => mediaToItem(x, viewerLink(x.sender.id, x.conversationId, x.messageId))),
    [items],
  );
  const [lb, setLb] = useState<number | null>(null);
  const sentinel = useAutoLoad(!!q.hasNextPage && !q.isFetchingNextPage, () => void q.fetchNextPage());

  if (q.isError) return <ErrorState description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />;
  if (q.isLoading) return <Skeleton height="14rem" width="100%" />;
  if (items.length === 0) return <EmptyState icon="message" title={t('admin.chatFeed.media.empty')} description=" " />;
  return (
    <>
      <ul className={styles.grid} data-testid="media-grid">
        {items.map((x, i) => (
          <li key={x.attachmentId} className={styles.gridItem}>
            <MediaThumb tile item={lbItems[i]} onOpen={() => setLb(i)} />
            <MediaBadges item={lbItems[i]} />
            <span className={styles.cap}>
              <strong dir="auto">{x.sender.displayName ?? `#${x.sender.id}`}</strong>
              <span className={styles.muted} dir="auto">
                {x.conversationTitle ?? t(`admin.chat.type.${x.conversationType}`)}
              </span>
              <time className={styles.muted} dateTime={x.createdAt}>
                {formatDateTime(x.createdAt)}
              </time>
              {lbItems[i].link && <Link to={lbItems[i].link as string}>{t('admin.chat.showInChat')}</Link>}
            </span>
          </li>
        ))}
      </ul>
      <div ref={sentinel} aria-hidden="true" />
      <LoadMore hasMore={!!q.hasNextPage} loading={q.isFetchingNextPage} onLoadMore={() => void q.fetchNextPage()} />
      {lb !== null && <Lightbox items={lbItems} index={lb} onIndex={setLb} onClose={() => setLb(null)} />}
    </>
  );
}

export function MessagesTab({ filters, reason }: { filters: FeedFilterState; reason: string }) {
  const i18n = useI18n();
  const { t } = i18n;
  const convId = parseId(useDebouncedValue(filters.conversationId, 400) || null);
  const f = useMemo(
    () => ({
      userId: filters.user?.id ?? null,
      conversationId: convId,
      deleted: filters.deleted,
      suppressed: filters.suppressed,
      hasMedia: filters.hasMedia,
      from: filters.from,
      to: filters.to,
    }),
    [filters, convId],
  );
  const q = useInfiniteQuery({
    queryKey: qk.adminChat.feed(f),
    queryFn: ({ pageParam }) => adminChatApi.listChatMessages(f, reason, pageParam, 30),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: nextCursorParam,
    staleTime: Infinity,
    gcTime: 0,
    refetchOnWindowFocus: false,
  });
  useRejectOnReasonError(chatReasonKey.feed(), q.error);
  const rows = useMemo<AdminFeedMessage[]>(() => q.data?.pages.flatMap((p) => p.items) ?? [], [q.data]);
  // Akışta "mine" anlamsız: tüm mesajlar aynı yönde, gönderen adıyla gösterilir.
  const msgs = useMemo(() => rows.map((r) => ({ ...r.message, mine: false })), [rows]);
  const linkOf = (id: number) => {
    const r = rows.find((x) => x.message.id === id);
    return r ? viewerLink(r.message.senderId, r.conversation.id, r.message.id) : null;
  };
  const lbItems = useMemo(
    () => collectLightboxItems(msgs, (m) => viewerLink(m.senderId, rows.find((x) => x.message.id === m.id)?.conversation.id, m.id)),
    [msgs, rows],
  );
  const [lb, setLb] = useState<number | null>(null);
  const sentinel = useAutoLoad(!!q.hasNextPage && !q.isFetchingNextPage, () => void q.fetchNextPage());

  if (q.isError) return <ErrorState description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />;
  if (q.isLoading) return <Skeleton height="14rem" width="100%" />;
  if (rows.length === 0) return <EmptyState icon="message" title={t('admin.chatFeed.messages.empty')} description=" " />;
  return (
    <>
      <ul className={styles.feedList} data-testid="feed-list">
        {rows.map((r, i) => {
          const link = linkOf(r.message.id);
          const sender = r.message.sender?.displayName ?? r.message.senderName ?? `#${r.message.senderId}`;
          return (
            <li key={r.message.id} className={styles.feedRow} data-testid="feed-row">
              <div className={styles.feedHead}>
                <span className={styles.convTitle} dir="auto">
                  <Avatar name={sender} src={r.message.sender?.avatarUrl} size={24} /> {sender} →{' '}
                  {r.conversation.title ?? t(`admin.chat.type.${r.conversation.type}`)}
                </span>
                {link && <Link to={link}>{t('admin.chat.showInChat')}</Link>}
              </div>
              <ul className={styles.feedInner}>
                <ChatBubble
                  m={msgs[i]}
                  onOpenMedia={(aid) => {
                    const k = lbItems.findIndex((x) => x.key === `a${aid}`);
                    if (k >= 0) setLb(k);
                  }}
                />
              </ul>
            </li>
          );
        })}
      </ul>
      <div ref={sentinel} aria-hidden="true" />
      <LoadMore hasMore={!!q.hasNextPage} loading={q.isFetchingNextPage} onLoadMore={() => void q.fetchNextPage()} />
      {lb !== null && <Lightbox items={lbItems} index={lb} onIndex={setLb} onClose={() => setLb(null)} />}
    </>
  );
}
