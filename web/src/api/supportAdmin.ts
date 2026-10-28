// Destek tamamlama (P12): yeniden açma, öncelik/atama, İÇ NOT (müşteriye görünmez), talep/geri bildirim silme,
// geri bildirim birleştirme, SSS sıralama, CSV. Sözleşme: docs/ADMIN_API.md "P12".
import { api, apiBlob } from './client';
import { guardHeaders, type GuardOpts } from './guard';
import type {
  FaqAdminView,
  FeedbackCategory,
  FeedbackStatus,
  TicketCategory,
  TicketStatus,
  TicketSummary,
} from './types';

export type TicketPriority = 'LOW' | 'NORMAL' | 'HIGH' | 'URGENT';
export const TICKET_PRIORITIES: TicketPriority[] = ['LOW', 'NORMAL', 'HIGH', 'URGENT'];

/** Liste satırındaki P12 alanları (eski sunucuda yok olabilir). */
export interface TicketRowExtra {
  priority?: TicketPriority;
  assigneeId?: number | null;
}

/** Yönetici mesaj satırı: `internal` = İÇ NOT (müşteriye görünmez). id'ler mesaj/not için ayrı sayılır. */
export interface AdminMessage {
  id: number;
  fromStaff: boolean;
  internal: boolean;
  text: string;
  createdAt: string;
  authorId: number | null;
}

export interface AdminTicketDetail {
  ticket: TicketSummary;
  messages: AdminMessage[];
  userId: number | null;
  userEmail: string | null;
  priority: TicketPriority;
  assigneeId: number | null;
  assigneeName: string | null;
}

export interface TicketPatch {
  priority?: TicketPriority;
  assigneeId?: number;
  /** true: atamayı kaldırır (assigneeId ile birlikte verilmez). */
  unassign?: boolean;
  category?: TicketCategory;
}

/** React anahtarı: mesaj ve not kimlikleri çakışabilir. */
export const messageKey = (m: Pick<AdminMessage, 'id' | 'internal'>) => `${m.internal ? 'n' : 'm'}${m.id}`;

/** Yönetici talep ayrıntısı (mesajlar + iç notlar + öncelik/atama). */
export const getTicketAdmin = (id: number) => api.get<AdminTicketDetail>(`/admin/support/tickets/${id}`);
export const reopenTicket = (id: number) => api.post<AdminTicketDetail>(`/admin/support/tickets/${id}/reopen`);
export const patchTicket = (id: number, p: TicketPatch) => api.patch<AdminTicketDetail>(`/admin/support/tickets/${id}`, p);
export const addTicketNote = (id: number, text: string) =>
  api.post<AdminMessage>(`/admin/support/tickets/${id}/notes`, { text: text.trim() });
/** Geri alınamaz: mesajlar, iç notlar ve (herkese açık talepte) durum bağlantıları silinir. */
export const deleteTicket = (id: number, o: GuardOpts) => api.del(`/admin/support/tickets/${id}`, guardHeaders(o));

export const deleteFeedback = (id: number, o: GuardOpts) => api.del(`/admin/support/feedback/${id}`, guardHeaders(o));
export interface MergeResult {
  sourceId: number;
  targetId: number;
  voteCount: number;
}
/** Kaynağın oyları hedefe taşınır (çift oy sayılmaz), kaynak silinir. */
export const mergeFeedback = (sourceId: number, targetId: number, o: GuardOpts & { reason: string }) =>
  api.post<MergeResult>('/admin/support/feedback/merge', { sourceId, targetId, reason: o.reason.trim() }, guardHeaders(o));

/** SSS sırası: kimlikler aynı dil + kategoride, yeni sıra = dizi sırası. */
export const reorderFaq = (ids: number[]) => api.put<FaqAdminView[]>('/admin/faq/order', { ids });

export interface TicketCsvFilters {
  status?: TicketStatus | '';
  category?: TicketCategory | '';
  priority?: TicketPriority | '';
  publicOnly?: boolean;
  from?: string;
  to?: string;
}
export interface FeedbackCsvFilters {
  status?: FeedbackStatus | '';
  category?: FeedbackCategory | '';
  from?: string;
  to?: string;
}

/** CSV: yalnız üst bilgi (iç notlar ve mesaj gövdeleri dışa aktarılmaz). */
export const exportTicketsCsv = (f: TicketCsvFilters = {}): Promise<Blob> =>
  apiBlob('/admin/support/tickets/export.csv', {
    query: {
      status: f.status || undefined,
      category: f.category || undefined,
      priority: f.priority || undefined,
      publicOnly: f.publicOnly || undefined,
      from: f.from || undefined,
      to: f.to || undefined,
    },
  });
export const exportFeedbackCsv = (f: FeedbackCsvFilters = {}): Promise<Blob> =>
  apiBlob('/admin/support/feedback/export.csv', {
    query: { status: f.status || undefined, category: f.category || undefined, from: f.from || undefined, to: f.to || undefined },
  });

