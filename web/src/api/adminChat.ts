import { api, apiFetch } from './client';
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
