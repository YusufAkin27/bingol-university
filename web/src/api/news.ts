import { api } from './client';
import { guardHeaders, type GuardOpts } from './guard';
import type { AdminNewsRow, NewsListParams, Page } from './types';

export const listNews = (p: NewsListParams = {}) => api.get<Page<AdminNewsRow>>('/admin/news', { ...p });
/** Gizli kayıtlar herkese açık liste, detay, arama ve favorilerde görünmez. */
export const setNewsHidden = (id: number, hidden: boolean, o?: GuardOpts) =>
  api.patch(`/admin/news/${id}`, { hidden }, guardHeaders(o));
