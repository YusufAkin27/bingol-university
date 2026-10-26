import { publicApi } from './client';

/** Herkese açık içerik uçları: haber/duyuru/etkinlik, yemek listesi, kaynak durumu. Bearer yok. */
export type NewsKind = 'HABER' | 'DUYURU' | 'ETKINLIK';

export interface NewsSummary {
  id: number;
  type: NewsKind;
  title: string;
  summary: string | null;
  imageUrl: string | null;
  /** yyyy-MM-dd */
  publishedDate: string | null;
  url: string | null;
}

export interface NewsDetail extends Omit<NewsSummary, 'summary'> {
  content: string | null;
}

export interface NewsPage {
  items: NewsSummary[];
  page: number;
  totalPages: number;
  totalItems: number;
}

export interface MenuDay {
  /** yyyy-MM-dd */
  date: string;
  items: string[];
}

export interface SourceStatus {
  maintenance: boolean;
  lastSuccessAt: string | null;
  lastAttemptAt: string | null;
  message: string | null;
}

export type StatusMap = Record<string, SourceStatus>;

export const NEWS_KINDS: NewsKind[] = ['HABER', 'DUYURU', 'ETKINLIK'];

export const getPublicNews = (p: { type?: NewsKind; page?: number; size?: number }) =>
  publicApi.get<NewsPage>('/news', { type: p.type, page: p.page ?? 0, size: p.size ?? 12 });

export const getPublicNewsItem = (id: number | string) => publicApi.get<NewsDetail>(`/news/${id}`);

/** month: yyyy-MM (boşsa sunucuda içinde bulunulan ay). */
export const getMenuMonth = (month?: string) => publicApi.get<MenuDay[]>('/menu', { month });

export const getSourceStatus = () => publicApi.get<StatusMap>('/status');
