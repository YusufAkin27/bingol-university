import { api, publicApi } from './client';
import type { FaqAdminView, FaqGroup, FaqRequest } from './types';

export const listFaq = () => publicApi.get<FaqGroup[]>('/faq');

export const listFaqAdmin = () => api.get<FaqAdminView[]>('/admin/faq');
export const createFaq = (r: FaqRequest) => api.post<FaqAdminView>('/admin/faq', r);
export const updateFaq = (id: number, r: FaqRequest) => api.put<FaqAdminView>(`/admin/faq/${id}`, r);
export const deleteFaq = (id: number) => api.del(`/admin/faq/${id}`);
