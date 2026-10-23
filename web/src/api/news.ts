import { api } from './client';
import type { AdminNewsRow, NewsListParams, Page } from './types';

export const listNews = (p: NewsListParams = {}) => api.get<Page<AdminNewsRow>>('/admin/news', { ...p });
/** Gizli kayıtlar herkese açık liste, detay, arama ve favorilerde görünmez. */
export const setNewsHidden = (id: number, hidden: boolean) => api.patch(`/admin/news/${id}`, { hidden });
