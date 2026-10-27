import { api } from './client';
import type { AdminChatConversationPage, AdminChatMessagePage } from './types';

/**
 * Yalnızca JWT'li ADMIN. Her sayfa isteği sunucuda otomatik, değiştirilemez erişim denetim kaydına yazılır;
 * kayıt yazılamazsa içerik dönmez (503). Düz metin istemcide önbellekte kalır, depoya yazılmaz.
 */
export const listConversations = (userId: number, cursor?: number | null, size = 20) =>
  api.get<AdminChatConversationPage>(`/admin/users/${userId}/conversations`, { cursor, size });

/** `before`: şu ana kadar yüklenen en eski mesaj kimliği. Yanıt eskiden yeniye sıralıdır. */
export const getConversationMessages = (userId: number, conversationId: number, before?: number | null, size = 50) =>
  api.get<AdminChatMessagePage>(`/admin/users/${userId}/conversations/${conversationId}/messages`, { before, size });
