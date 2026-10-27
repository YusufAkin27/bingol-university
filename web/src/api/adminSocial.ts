import { api } from './client';

/** Sosyal moderasyon (ADMIN): hikayeler ve etiketler. Backend (BE5) sozlesmesi hazir olana dek tahmini. */
export interface AdminStory {
  id: number;
  author: { id: number; displayName: string | null; email: string | null };
  kind: string;
  caption: string | null;
  bodyText: string | null;
  viewCount: number;
  hidden: boolean;
  createdAt: string;
  expiresAt: string;
}
export interface AdminStoryPage {
  items: AdminStory[];
  nextCursor: number | null;
}
export interface TrendingTag {
  tag: string;
  display: string;
  postCount: number;
}

export const listStories = (hidden: boolean, cursor?: number | null, size = 20) =>
  api.get<AdminStoryPage>('/admin/stories', { cursor, size, hidden: hidden ? true : undefined });
export const hideStory = (id: number) => api.post<AdminStory>(`/admin/stories/${id}/hide`, {});
export const unhideStory = (id: number) => api.post<AdminStory>(`/admin/stories/${id}/unhide`, {});
export const deleteStory = (id: number) => api.del(`/admin/stories/${id}`);

export const trendingTags = () => api.get<{ items: TrendingTag[] }>('/admin/hashtags/trending');
export const bannedTags = () => api.get<{ items: string[] }>('/admin/hashtags/banned');
export const banTag = (tag: string) => api.post('/admin/hashtags/banned', { tag });
export const unbanTag = (tag: string) => api.del(`/admin/hashtags/banned/${encodeURIComponent(tag)}`);
