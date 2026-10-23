import { api } from './client';
import type {
  AdminFeedbackView,
  CursorPage,
  FeedbackCategory,
  FeedbackStatus,
  UpdateFeedbackRequest,
} from './types';

export const listFeedback = (
  p: { status?: FeedbackStatus; category?: FeedbackCategory; cursor?: number | null; size?: number } = {},
) =>
  api.get<CursorPage<AdminFeedbackView>>('/admin/feedback', {
    status: p.status,
    category: p.category,
    cursor: p.cursor,
    size: p.size,
  });
/** Verilmeyen alanlar değişmez. */
export const updateFeedback = (id: number, r: UpdateFeedbackRequest) =>
  api.patch<AdminFeedbackView>(`/admin/feedback/${id}`, r);
