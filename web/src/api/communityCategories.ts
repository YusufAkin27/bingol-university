// Kulüp kategorileri (yönetici). Uçlar: /admin/community-categories (liste, ekle, güncelle, aktif/pasif, sil, sıra).
// Kategori anahtarı (key) oluşturulduktan sonra değişmez; kulüp satırlarında saklanan değer budur.
import { api } from './client';

export interface CommunityCategory {
  id: number;
  key: string;
  nameTr: string;
  nameEn: string;
  nameAr: string;
  icon: string | null;
  sortOrder: number;
  active: boolean;
  /** Bu kategoriyi kullanan (silinmemiş) kulüp sayısı. */
  usageCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface CommunityCategoryList {
  items: CommunityCategory[];
  activeCount: number;
  maxActive: number;
}

export interface CommunityCategoryInput {
  /** Yalnızca oluştururken; boşsa Türkçe addan üretilir. */
  key?: string;
  nameTr: string;
  nameEn?: string;
  nameAr?: string;
  icon?: string;
  active?: boolean;
}

export const communityCategoryKeys = {
  all: ['community-categories'] as const,
  list: () => ['community-categories', 'list'] as const,
};

export const listCommunityCategories = () => api.get<CommunityCategoryList>('/admin/community-categories');
export const createCommunityCategory = (b: CommunityCategoryInput) =>
  api.post<CommunityCategory>('/admin/community-categories', b);
export const updateCommunityCategory = (id: number, b: CommunityCategoryInput) =>
  api.put<CommunityCategory>(`/admin/community-categories/${id}`, b);
export const setCommunityCategoryActive = (id: number, active: boolean) =>
  api.patch<CommunityCategory>(`/admin/community-categories/${id}/active`, { active });
export const deleteCommunityCategory = (id: number) => api.del(`/admin/community-categories/${id}`);
export const reorderCommunityCategories = (ids: number[]) =>
  api.put<CommunityCategoryList>('/admin/community-categories/order', { ids });
