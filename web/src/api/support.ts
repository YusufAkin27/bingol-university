import { api } from './client';
import type { AdminTicketSummary, CursorPage, StaffReplyResult, TicketDetail, TicketStatus } from './types';

export const listTickets = (
  p: { status?: TicketStatus; publicOnly?: boolean; cursor?: number | null; size?: number } = {},
) =>
  api.get<CursorPage<AdminTicketSummary>>('/admin/support/tickets', {
    status: p.status,
    publicOnly: p.publicOnly || undefined,
    cursor: p.cursor,
    size: p.size,
  });
export const getTicket = (id: number) => api.get<TicketDetail>(`/admin/support/tickets/${id}`);
/** `attachmentIds` yalnız ek varken gönderilir (en çok 4; kendi yüklediğiniz bekleyen ekler). */
export const replyTicket = (id: number, text: string, attachmentIds: number[] = []) =>
  api.post<StaffReplyResult>(
    `/admin/support/tickets/${id}/reply`,
    attachmentIds.length ? { text, attachmentIds } : { text },
  );
export const closeTicket = (id: number) => api.post(`/admin/support/tickets/${id}/close`);
