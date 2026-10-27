import { api } from './client';

/** Kesfet gonderileri yonetici moderasyonu (ADMIN). Yazma islemleri sunucuda denetim kaydina yazilir. */
export interface AdminPostAuthor {
  id: number;
  displayName: string | null;
  email: string | null;
  avatarUrl: string | null;
}
export interface AdminPostMedia {
  id: number;
  kind: 'IMAGE' | 'VIDEO' | string;
  url: string;
  thumbUrl: string;
  width: number | null;
  height: number | null;
  durationMs: number | null;
  hidden: boolean;
}
export interface AdminPostRow {
  id: number;
  author: AdminPostAuthor;
  text: string | null;
  media: AdminPostMedia[];
  likeCount: number;
  commentCount: number;
  mediaCount: number;
  hidden: boolean;
  deleted: boolean;
  hiddenReason: string | null;
  createdAt: string;
  editedAt: string | null;
  hiddenAt: string | null;
  deletedAt: string | null;
  deletedBy: number | null;
}
export interface AdminPostCommentRow {
  id: number;
  postId: number;
  parentId: number | null;
  rootId: number | null;
  depth: number;
  author: AdminPostAuthor;
  replyToUserId: number | null;
  text: string | null;
  replyCount: number;
  hidden: boolean;
  deleted: boolean;
  createdAt: string;
  deletedAt: string | null;
}
export interface AdminPostPage {
  items: AdminPostRow[];
  nextCursor: number | null;
}
export interface AdminPostCommentPage {
  items: AdminPostCommentRow[];
  nextCursor: number | null;
}
export interface AdminPostDetail {
  post: AdminPostRow;
  comments: AdminPostCommentPage;
}
export interface AdminPostCounts {
  postCount: number;
  commentCount: number;
  likeCount: number;
  mediaCount: number;
  hiddenCount: number;
  deletedCount: number;
}
export interface AdminPostStats extends AdminPostCounts {
  last24h: AdminPostCounts;
}
export interface AdminPostFilters {
  q?: string;
  hidden?: boolean;
  deleted?: boolean;
  hasMedia?: boolean;
  from?: string;
  to?: string;
}

/** Bos suzgecler gonderilmez; imlec = gonderi kimligi (en yeni once). */
export const listPosts = (f: AdminPostFilters, cursor?: number | null, size = 20) =>
  api.get<AdminPostPage>('/admin/posts', {
    cursor,
    size,
    q: f.q?.trim() || undefined,
    hidden: f.hidden ? true : undefined,
    deleted: f.deleted ? true : undefined,
    hasMedia: f.hasMedia ? true : undefined,
    from: f.from || undefined,
    to: f.to || undefined,
  });
export const postStats = () => api.get<AdminPostStats>('/admin/posts/stats');
export const getPost = (id: number) => api.get<AdminPostDetail>(`/admin/posts/${id}`);
export const listPostComments = (id: number, cursor?: number | null, size = 30) =>
  api.get<AdminPostCommentPage>(`/admin/posts/${id}/comments`, { cursor, size });
export const hidePost = (id: number, reason?: string) =>
  api.post<AdminPostRow>(`/admin/posts/${id}/hide`, { reason: reason?.trim() || null });
export const unhidePost = (id: number) => api.post<AdminPostRow>(`/admin/posts/${id}/unhide`, {});
export const deletePost = (id: number) => api.del(`/admin/posts/${id}`);
export const hideComment = (id: number) => api.post<AdminPostCommentRow>(`/admin/comments/${id}/hide`, {});
export const unhideComment = (id: number) => api.post<AdminPostCommentRow>(`/admin/comments/${id}/unhide`, {});
export const deleteComment = (id: number) => api.del(`/admin/comments/${id}`);
