import { api, apiFetchMeta, publicApi } from './client';
import { guardHeaders, type GuardOpts } from './guard';
import type { FaqAdminView, FaqGroup, FaqRequest } from './types';

export const listFaq = () => publicApi.get<FaqGroup[]>('/faq');

export const listFaqAdmin = () => api.get<FaqAdminView[]>('/admin/faq');

/** Sunucu sayfası en çok 50 kayıttır; devam varsa `X-Next-Cursor` başlığı sonraki sayfa numarasını verir. */
export interface FaqAdminPage {
  items: FaqAdminView[];
  nextCursor: number | null;
}
export async function listFaqAdminPage(cursor?: number): Promise<FaqAdminPage> {
  const { data, headers } = await apiFetchMeta<FaqAdminView[]>('/admin/faq', { query: { cursor, limit: 50 } });
  const raw = headers.get('X-Next-Cursor');
  const next = raw === null ? Number.NaN : Number(raw);
  return { items: data ?? [], nextCursor: Number.isFinite(next) ? next : null };
}
type Idem = GuardOpts;
const idemHeaders = guardHeaders;
export const createFaq = (r: FaqRequest, o?: Idem) => api.post<FaqAdminView>('/admin/faq', r, idemHeaders(o));
export const updateFaq = (id: number, r: FaqRequest, o?: Idem) =>
  api.put<FaqAdminView>(`/admin/faq/${id}`, r, idemHeaders(o));
export const deleteFaq = (id: number, o?: Idem) => api.del(`/admin/faq/${id}`, idemHeaders(o));
