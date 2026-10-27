import { api } from './client';
import type {
  AdminChatConversationPage,
  AdminChatMessagePage,
  AdminFeedPage,
  AdminMediaPage,
  AdminMediaStats,
  ReportDetail,
} from './types';

/**
 * Yalnızca JWT'li ADMIN. Her sayfa isteği sunucuda otomatik, değiştirilemez erişim denetim kaydına yazılır;
 * kayıt yazılamazsa içerik dönmez (503). Düz metin istemcide önbellekte kalır, depoya yazılmaz.
 */
export const listConversations = (userId: number, cursor?: number | null, size = 20) =>
  api.get<AdminChatConversationPage>(`/admin/users/${userId}/conversations`, { cursor, size });

/** `before`: şu ana kadar yüklenen en eski mesaj kimliği. Yanıt eskiden yeniye sıralıdır. */
export const getConversationMessages = (userId: number, conversationId: number, before?: number | null, size = 50) =>
  api.get<AdminChatMessagePage>(`/admin/users/${userId}/conversations/${conversationId}/messages`, { before, size });

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
export const listChatMedia = (f: MediaFilters, cursor?: number | null, size = 30) =>
  api.get<AdminMediaPage>('/admin/chat-media', {
    cursor,
    size,
    kind: f.kind || undefined,
    viewOnce: f.viewOnce ? true : undefined,
    deleted: f.deleted ? true : undefined,
    userId: f.userId ?? undefined,
    conversationId: f.conversationId ?? undefined,
    from: f.from || undefined,
    to: f.to || undefined,
  });
export const chatMediaStats = () => api.get<AdminMediaStats>('/admin/chat-media/stats');

/** Tüm sohbetlerden mesaj akışı (imleç = mesaj kimliği, en yeni önce). */
export const listChatMessages = (f: MessageFilters, cursor?: number | null, size = 30) =>
  api.get<AdminFeedPage>('/admin/chat-messages', {
    cursor,
    size,
    userId: f.userId ?? undefined,
    conversationId: f.conversationId ?? undefined,
    deleted: f.deleted ? true : undefined,
    suppressed: f.suppressed ? true : undefined,
    hasMedia: f.hasMedia ? true : undefined,
    from: f.from || undefined,
    to: f.to || undefined,
  });

/** Şikâyet detayı + bağlamı (her çağrı denetim kaydı üretir). */
export const getReportDetail = (id: number) => api.get<ReportDetail>(`/admin/reports/${id}`);
