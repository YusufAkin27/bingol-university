// Yönetici sohbet görüntüleyicisinin saf mantığı (testlenebilir): sayfa birleştirme, balon yönü, yukarı kaydırmada yükleme.
import type {
  AdminChatAttachment,
  AdminChatConversation,
  AdminChatMessage,
  AdminChatMessagePage,
  AdminMediaItem,
  ChatKind,
  ChatPerson,
} from '../../../api/types';
import { paths } from '../../../paths';

/** Yukarıdan bu kadar piksel kala (scrollTop <= eşik) eski sayfa istenir. */
export const LOAD_OLDER_THRESHOLD_PX = 120;
export const MESSAGE_PAGE_SIZE = 50;

/**
 * useInfiniteQuery sayfaları "önce en yeni" sırasındadır (ilk sayfa en yeni 50 mesaj; sonrakiler daha eski).
 * Her sayfa kendi içinde eskiden yeniye sıralıdır. Ekranda eskiden yeniye tek liste gerekir.
 */
export function flattenPages(pages: AdminChatMessagePage[]): AdminChatMessage[] {
  const seen = new Set<number>();
  const out: AdminChatMessage[] = [];
  for (const page of [...pages].reverse()) {
    for (const m of page.items) {
      if (!seen.has(m.id)) {
        seen.add(m.id);
        out.push(m);
      }
    }
  }
  return out;
}

/** Sonraki (daha eski) sayfa imleci; yoksa undefined (react-query "devam yok" olarak okur). */
export function nextBeforeParam(last: AdminChatMessagePage): number | undefined {
  return last.nextBefore ?? undefined;
}

export type BubbleSide = 'self' | 'peer';

/** Açılan kullanıcının mesajı bir yanda ('self'), karşı taraflar diğer yanda ('peer'); Arapçada CSS ayna yapar. */
export function bubbleSide(m: Pick<AdminChatMessage, 'mine'>): BubbleSide {
  return m.mine ? 'self' : 'peer';
}

/** Yukarı kaydırmada eski sayfayı yükle: eşiğe gelindi, devam var ve zaten istek yok. */
export function shouldLoadOlder(scrollTop: number, hasMore: boolean, fetching: boolean): boolean {
  return hasMore && !fetching && scrollTop <= LOAD_OLDER_THRESHOLD_PX;
}

/** Eski sayfa eklenince görünüm zıplamasın: yeni scrollTop = eski scrollTop + yükseklik farkı. */
export function restoredScrollTop(prevScrollTop: number, prevScrollHeight: number, newScrollHeight: number): number {
  return prevScrollTop + Math.max(0, newScrollHeight - prevScrollHeight);
}

/** Gün ayracı için yerel takvim günü anahtarı. */
export function dayKey(iso: string): string {
  const d = new Date(iso);
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

/** Önizleme uç yolu (sunucu `/api/...` döner; api istemcisi tabanı kendisi ekler). */
export function previewApiPath(url: string): string {
  return url.replace(/^\/api(?=\/)/, '');
}

// ---------- v2: tüm sohbetler, medya, süzgeçler ----------

/** Büyük görüntüleyicinin (lightbox) tek bir öğesi; ek ve toplu medya satırından türetilir. */
export interface LightboxItem {
  key: string;
  kind: string;
  previewUrl: string | null;
  thumbUrl: string | null;
  viewOnce: boolean;
  viewedBy: { id: number; displayName: string | null; at: string }[];
  purged: boolean;
  hidden: boolean;
  messageDeleted: boolean;
  suppressed: boolean;
  width: number;
  height: number;
  bytes: number;
  durationMs: number | null;
  senderName: string | null;
  createdAt: string;
  conversationTitle: string | null;
  /** "Sohbette göster" bağlantısı (varsa). */
  link: string | null;
}

export function personName(p: ChatPerson | null | undefined, fallback: string | null = null): string | null {
  return p?.displayName ?? fallback;
}

export function attachmentToItem(
  a: AdminChatAttachment,
  m: Pick<AdminChatMessage, 'senderName' | 'sender' | 'createdAt' | 'deleted' | 'suppressed'>,
  link: string | null,
  conversationTitle: string | null = null,
): LightboxItem {
  return {
    key: `a${a.id}`,
    kind: a.kind,
    previewUrl: a.previewUrl,
    thumbUrl: a.thumbUrl,
    viewOnce: !!a.viewOnce,
    viewedBy: a.viewedBy ?? [],
    purged: !!a.purged,
    hidden: a.hidden,
    messageDeleted: !!a.messageDeleted || m.deleted,
    suppressed: !!m.suppressed,
    width: a.width,
    height: a.height,
    bytes: a.bytes,
    durationMs: a.durationMs ?? null,
    senderName: personName(m.sender, m.senderName),
    createdAt: m.createdAt,
    conversationTitle,
    link,
  };
}

export function mediaToItem(x: AdminMediaItem, link: string | null): LightboxItem {
  return {
    key: `a${x.attachmentId}`,
    kind: x.kind,
    previewUrl: x.previewUrl,
    thumbUrl: x.thumbUrl,
    viewOnce: x.viewOnce,
    viewedBy: x.viewedBy,
    purged: x.purged,
    hidden: x.hidden,
    messageDeleted: x.messageDeleted,
    suppressed: x.suppressed,
    width: x.width,
    height: x.height,
    bytes: x.bytes,
    durationMs: x.durationMs,
    senderName: x.sender.displayName,
    createdAt: x.createdAt,
    conversationTitle: x.conversationTitle,
    link,
  };
}

/** Mesajlardaki tüm ekleri sırayla düz listeye çevirir (lightbox'ta yan yana gezinme). */
export function collectLightboxItems(
  messages: AdminChatMessage[],
  linkFor: (m: AdminChatMessage) => string | null,
): LightboxItem[] {
  const out: LightboxItem[] = [];
  for (const m of messages) for (const a of m.attachments) out.push(attachmentToItem(a, m, linkFor(m)));
  return out;
}

/** Sohbetin görünen adı: birebirde karşı taraf, diğerlerinde başlık. */
export function conversationName(
  c: { type: ChatKind; title: string | null; peer: ChatPerson | null },
  fallbackUser: string,
  fallbackGroup: string,
): string {
  if (c.type === 'DIRECT') return c.peer?.displayName ?? c.title ?? fallbackUser;
  return c.title ?? fallbackGroup;
}

export type ConvBadge = 'deleted' | 'left' | 'archived' | 'cleared' | 'shadow';

/** Sohbet listesi rozetleri (yalnız bilgi; hiçbir sohbet gizlenmez). */
export function conversationBadges(c: AdminChatConversation): ConvBadge[] {
  const out: ConvBadge[] = [];
  if (c.state?.hiddenByUser) out.push('deleted');
  if (c.left) out.push('left');
  if (c.state?.archived) out.push('archived');
  if (c.state?.cleared) out.push('cleared');
  if (c.lastMessage?.suppressed) out.push('shadow');
  return out;
}

/** İstemci tarafı arama: ad, başlık ve son mesaj önizlemesi (küçük/büyük harf duyarsız, tr yerel). */
export function filterConversations<T extends AdminChatConversation>(items: T[], q: string, nameOf: (c: T) => string): T[] {
  const needle = q.trim().toLocaleLowerCase('tr');
  if (!needle) return items;
  return items.filter((c) => `${nameOf(c)} ${c.lastMessage?.text ?? ''}`.toLocaleLowerCase('tr').includes(needle));
}

export function formatBytes(n: number): string {
  if (!Number.isFinite(n) || n < 0) return '—';
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  if (n < 1024 * 1024 * 1024) return `${(n / (1024 * 1024)).toFixed(1)} MB`;
  return `${(n / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

export function formatDuration(ms: number | null | undefined): string {
  if (ms == null || ms < 0) return '';
  const s = Math.round(ms / 1000);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

/** Makbuz işareti: SENT=✓, DELIVERED/READ=✓✓ (okundu ayrıca renklenir). */
export function receiptTicks(status: string | null | undefined): string {
  return status === 'DELIVERED' || status === 'READ' ? '✓✓' : status === 'SENT' ? '✓' : '';
}

/** Pozitif tamsayı sorgu parametresi; geçersizse null. */
export function parseId(v: string | null): number | null {
  if (!v) return null;
  const n = Number(v);
  return Number.isInteger(n) && n > 0 ? n : null;
}

/** Sonraki/önceki lightbox dizini (taşmaz). */
export function stepIndex(i: number, delta: 1 | -1, n: number): number {
  return Math.min(Math.max(i + delta, 0), Math.max(n - 1, 0));
}

/** Toplu medya/mesaj akışı: sonraki imleç (yoksa undefined). */
export function nextCursorParam(last: { nextCursor: number | null }): number | undefined {
  return last.nextCursor ?? undefined;
}

/** Bir mesajın sohbette gösterileceği yönetici bağlantısı (gönderen kullanıcının görünümü). */
export function viewerLink(senderId: number | null | undefined, conversationId: number | undefined, messageId: number): string | null {
  if (!senderId || !conversationId) return null;
  return paths.admin.userMessages(senderId, conversationId, messageId);
}
