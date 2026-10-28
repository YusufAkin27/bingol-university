import { api, apiBlob, apiFetch } from './client';
import { guardHeaders } from './guard';
import type {
  AdminChatConversationPage,
  AdminChatMessagePage,
  AdminFeedPage,
  AdminMediaPage,
  AdminMediaStats,
  ReportDetail,
} from './types';

/** `X-Admin-Reason` başlığı: Türkçe/Arapça karakter için yüzde-kodlu gönderilir (sunucu çözer). */
export function reasonHeaders(reason: string): { headers: Record<string, string> } {
  return { headers: { 'X-Admin-Reason': encodeURIComponent(reason.trim()) } };
}

/**
 * Yalnızca JWT'li ADMIN. Her sayfa isteği sunucuda otomatik, değiştirilemez erişim denetim kaydına yazılır;
 * kayıt yazılamazsa içerik dönmez (503). Düz metin istemcide önbellekte kalır, depoya yazılmaz.
 * İçerik açan uçlar SEBEP ister (>= 10 karakter): `X-Admin-Reason` başlığı (yüzde-kodlu); eksikse 400 REASON_REQUIRED.
 * Sebep her isteğe eklenir (sunucu durumsuzdur, sayfalama istekleri dahil).
 */
export const listConversations = (userId: number, reason: string, cursor?: number | null, size = 20) =>
  apiFetch<AdminChatConversationPage>(`/admin/users/${userId}/conversations`, {
    query: { cursor, size },
    ...reasonHeaders(reason),
  });

/** `before`: şu ana kadar yüklenen en eski mesaj kimliği. Yanıt eskiden yeniye sıralıdır. */
export const getConversationMessages = (
  userId: number,
  conversationId: number,
  reason: string,
  before?: number | null,
  size = 50,
) =>
  apiFetch<AdminChatMessagePage>(`/admin/users/${userId}/conversations/${conversationId}/messages`, {
    query: { before, size },
    ...reasonHeaders(reason),
  });

export interface MediaFilters {
  kind?: 'IMAGE' | 'VIDEO' | '';
  viewOnce?: boolean;
  deleted?: boolean;
  userId?: number | null;
  conversationId?: number | null;
  from?: string;
  to?: string;
}
export interface MessageFilters {
  userId?: number | null;
  conversationId?: number | null;
  deleted?: boolean;
  suppressed?: boolean;
  hasMedia?: boolean;
  from?: string;
  to?: string;
}

/** Tüm sohbet ekleri (imleç = ek kimliği, en yeni önce). Boş süzgeçler gönderilmez. */
export const listChatMedia = (f: MediaFilters, reason: string, cursor?: number | null, size = 30) =>
  apiFetch<AdminMediaPage>('/admin/chat-media', {
    query: {
      cursor,
      size,
      kind: f.kind || undefined,
      viewOnce: f.viewOnce ? true : undefined,
      deleted: f.deleted ? true : undefined,
      userId: f.userId ?? undefined,
      conversationId: f.conversationId ?? undefined,
      from: f.from || undefined,
      to: f.to || undefined,
    },
    ...reasonHeaders(reason),
  });
export const chatMediaStats = () => api.get<AdminMediaStats>('/admin/chat-media/stats');

/** Tüm sohbetlerden mesaj akışı (imleç = mesaj kimliği, en yeni önce). */
export const listChatMessages = (f: MessageFilters, reason: string, cursor?: number | null, size = 30) =>
  apiFetch<AdminFeedPage>('/admin/chat-messages', {
    query: {
      cursor,
      size,
      userId: f.userId ?? undefined,
      conversationId: f.conversationId ?? undefined,
      deleted: f.deleted ? true : undefined,
      suppressed: f.suppressed ? true : undefined,
      hasMedia: f.hasMedia ? true : undefined,
      from: f.from || undefined,
      to: f.to || undefined,
    },
    ...reasonHeaders(reason),
  });

/** Şikâyet detayı + bağlamı (her çağrı denetim kaydı üretir). Sohbet mesajı bağlamı açılıyorsa sebep gerekir. */
export const getReportDetail = (id: number, reason?: string | null) =>
  apiFetch<ReportDetail>(`/admin/reports/${id}`, reason ? reasonHeaders(reason) : {});

// ---------- P08: sohbet müdahalesi (docs/ADMIN_API.md "Sohbet müdahalesi (P08)") ----------
// İşlem sebebi (`X-Admin-Reason`) sohbet İÇERİĞİ görüntüleme sebebinden ayrıdır; ikisi ayrı alanlardır.

export interface MessageActionResult {
  id: number;
  conversationId: number;
  /** HIDDEN | VISIBLE | PURGED */
  state: 'HIDDEN' | 'VISIBLE' | 'PURGED';
  /** Kalıcı silme: geri alınamaz. */
  irreversible: boolean;
}
export interface BulkHideItem {
  id: number;
  ok: boolean;
  status: number;
  error: string | null;
}
export interface BulkHideResult {
  requested: number;
  done: number;
  failed: number;
  items: BulkHideItem[];
}
export interface ConversationStateResult {
  id: number;
  closed: boolean;
  closedAt: string | null;
  notified: number;
}
export interface MemberRemoval {
  conversationId: number;
  userId: number;
  removed: boolean;
}
export interface ConversationMemberMeta {
  userId: number;
  displayName: string | null;
  /** Maskeli: a***@bingol.edu.tr */
  email: string | null;
  role: string | null;
  joinedAt: string | null;
  leftAt: string | null;
  active: boolean;
}
/** Sohbet üst verisi (İÇERİK YOK). kind: DIRECT | GROUP | CLUB | EVENT. */
export interface ConversationMeta {
  id: number;
  type: 'DIRECT' | 'GROUP';
  kind: 'DIRECT' | 'GROUP' | 'CLUB' | 'EVENT';
  communityId: number | null;
  eventId: number | null;
  title: string | null;
  closed: boolean;
  closedAt: string | null;
  closedBy: number | null;
  closedReason: string | null;
  messageCount: number;
  activeMemberCount: number;
  openReportCount: number;
  createdAt: string | null;
  lastMessageAt: string | null;
  /** Kulüp/etkinlik odası: üyelik kaynağa bağlı, buradan çıkarılamaz. */
  membersManaged: boolean;
  membersTruncated: boolean;
  members: ConversationMemberMeta[];
}
export interface ExportMessage {
  id: number;
  createdAt: string;
  senderId: number;
  senderName: string | null;
  senderEmail: string | null;
  text: string | null;
  decryptError: string | null;
  status: string;
  editedAt: string | null;
  replyToMessageId: number | null;
  deletedAt: string | null;
}
export interface ConversationExport {
  conversationId: number;
  type: string;
  title: string | null;
  exportedAt: string;
  exportedBy: number;
  reason: string;
  messageCount: number;
  truncated: boolean;
  nextAfterId: number | null;
  messages: ExportMessage[];
}
export type ExportFormat = 'json' | 'csv';
/** Yasal dışa aktarma için en az sebep uzunluğu ve ikinci onay başlığı (sunucuyla aynı). */
export const EXPORT_REASON_MIN = 20;
export const EXPORT_MAX_MESSAGES = 5000;

const act = (reason: string, idempotencyKey?: string) => guardHeaders({ reason, idempotencyKey });

export const hideMessage = (id: number, reason: string, idempotencyKey?: string) =>
  api.post<MessageActionResult>(`/admin/messages/${id}/hide`, undefined, act(reason, idempotencyKey));
export const unhideMessage = (id: number, reason: string, idempotencyKey?: string) =>
  api.post<MessageActionResult>(`/admin/messages/${id}/unhide`, undefined, act(reason, idempotencyKey));
/** Kalıcı silme: içerik temizlenir, yer tutucu kalır; GERİ ALINAMAZ. */
export const purgeMessage = (id: number, reason: string, idempotencyKey?: string) =>
  api.del<MessageActionResult>(`/admin/messages/${id}`, act(reason, idempotencyKey));
/** En çok 200 mesaj; kısmi başarı (items[].error) döner. */
export const bulkHideMessages = (ids: number[], reason: string, idempotencyKey?: string) =>
  api.post<BulkHideResult>('/admin/messages/bulk-hide', { ids, reason }, act(reason, idempotencyKey));

/** Üst veri sebep istemez; `reason` verilirse (açık görüntüleme sebebi) denetim kaydına bağlanır. */
export const getConversationMeta = (conversationId: number, reason?: string) =>
  apiFetch<ConversationMeta>(`/admin/conversations/${conversationId}`, reason ? reasonHeaders(reason) : {});
export const closeConversation = (conversationId: number, reason: string, idempotencyKey?: string) =>
  api.post<ConversationStateResult>(`/admin/conversations/${conversationId}/close`, undefined, act(reason, idempotencyKey));
export const reopenConversation = (conversationId: number, reason: string, idempotencyKey?: string) =>
  api.post<ConversationStateResult>(`/admin/conversations/${conversationId}/reopen`, undefined, act(reason, idempotencyKey));
export const removeConversationMember = (conversationId: number, userId: number, reason: string, idempotencyKey?: string) =>
  api.del<MemberRemoval>(`/admin/conversations/${conversationId}/members/${userId}`, act(reason, idempotencyKey));

/**
 * Yasal talep dışa aktarımı: sebep >= 20 karakter + ikinci onay başlığı `X-Admin-Confirm` (sohbet kimliği).
 * Denetim kaydına yazılır ve mesaj içeriğini çözer; en çok 5000 mesaj, fazlası için `afterId`.
 */
export const exportConversationJson = (conversationId: number, reason: string, afterId?: number | null) =>
  apiFetch<ConversationExport>(`/admin/conversations/${conversationId}/export`, {
    query: { format: 'json', afterId: afterId ?? undefined },
    headers: { ...reasonHeaders(reason).headers, 'X-Admin-Confirm': String(conversationId) },
  });
export const exportConversationCsv = (conversationId: number, reason: string, afterId?: number | null) =>
  apiBlob(`/admin/conversations/${conversationId}/export`, {
    query: { format: 'csv', afterId: afterId ?? undefined },
    headers: { ...reasonHeaders(reason).headers, 'X-Admin-Confirm': String(conversationId) },
  });
