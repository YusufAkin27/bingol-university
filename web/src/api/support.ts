import { api } from './client';
import type { AdminTicketSummary, CursorPage, TicketDetail, TicketStatus } from './types';

export const listTickets = (p: { status?: TicketStatus; cursor?: number | null; size?: number } = {}) =>
  api.get<CursorPage<AdminTicketSummary>>('/admin/support/tickets', {
    status: p.status,
    cursor: p.cursor,
    size: p.size,
  });
export const getTicket = (id: number) => api.get<TicketDetail>(`/admin/support/tickets/${id}`);
export const replyTicket = (id: number, text: string) =>
  api.post<TicketDetail>(`/admin/support/tickets/${id}/reply`, { text });
export const closeTicket = (id: number) => api.post(`/admin/support/tickets/${id}/close`);
