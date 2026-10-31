import { api, apiFetch } from './client';
import { cleanReason, guardHeaders, type GuardOpts } from './guard';

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
  mediaCount: number;
  hidden: boolean;
  deleted: boolean;
  hiddenReason: string | null;
  createdAt: string;
  editedAt: string | null;
  hiddenAt: string | null;
  deletedAt: string | null;
  deletedBy: number | null;
  /** Bu gonderi icin acik (sonuclanmamis) sikayet sayisi. */
  openReportCount: number;
}
export interface AdminPostReport {
  id: number;
  reason: string;
  note: string | null;
  status: 'OPEN' | 'RESOLVED' | string;
  createdAt: string;
}
export interface AdminPostPage {
  items: AdminPostRow[];
  nextCursor: number | null;
}
export interface AdminPostDetail {
  post: AdminPostRow;
  reports: AdminPostReport[];
}
export interface AdminPostCounts {
  postCount: number;
  likeCount: number;
  mediaCount: number;
  hiddenCount: number;
  deletedCount: number;
}
export interface AdminPostStats extends AdminPostCounts {
  /** Acik sikayeti olan farkli gonderi sayisi. */
  openReportedCount: number;
  last24h: AdminPostCounts;
}
export type AdminPostStatus = 'ALL' | 'VISIBLE' | 'HIDDEN' | 'DELETED';
export interface AdminPostFilters {
  /** Gonderi metni, yazar adi veya e-postasi. */
  q?: string;
  status?: AdminPostStatus;
  /** Yazar kimligi (yalniz rakam). */
  authorId?: string;
  /** En az bu kadar acik sikayeti olanlar. */
  minReports?: string;
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
    status: f.status && f.status !== 'ALL' ? f.status : undefined,
    authorId: f.authorId && /^\d+$/.test(f.authorId.trim()) ? Number(f.authorId.trim()) : undefined,
    minReports: f.minReports && /^\d+$/.test(f.minReports.trim()) ? Number(f.minReports.trim()) : undefined,
    hasMedia: f.hasMedia ? true : undefined,
    from: f.from || undefined,
    to: f.to || undefined,
  });
export const postStats = () => api.get<AdminPostStats>('/admin/posts/stats');
export const getPost = (id: number) => api.get<AdminPostDetail>(`/admin/posts/${id}`);
// W1-B (T-013): gizle / göster / sil gerekçe ister (>= 5 karakter): `X-Admin-Reason` başlığı (+ gövdede `reason`).
export const hidePost = (id: number, reason: string, o?: Pick<GuardOpts, 'idempotencyKey'>) =>
  api.post<AdminPostRow>(`/admin/posts/${id}/hide`, { reason: cleanReason(reason) || null }, guardHeaders({ ...o, reason }));
export const unhidePost = (id: number, reason: string, o?: Pick<GuardOpts, 'idempotencyKey'>) =>
  api.post<AdminPostRow>(`/admin/posts/${id}/unhide`, { reason: cleanReason(reason) || null }, guardHeaders({ ...o, reason }));
/** Metni duzenler (bos metin = temizle); yazara bildirim gider. */
export const editPost = (id: number, text: string) => api.patch<AdminPostRow>(`/admin/posts/${id}`, { text });
/** Siler; gerekce yazara bildirilir, acik sikayetler sonuclanir. */
export const deletePost = (id: number, reason: string, o?: Pick<GuardOpts, 'idempotencyKey'>) =>
  apiFetch<void>(`/admin/posts/${id}`, {
    method: 'DELETE',
    body: { reason: cleanReason(reason) || null },
    ...guardHeaders({ ...o, reason }),
  });
