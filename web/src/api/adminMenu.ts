import { api } from './client';

/**
 * Yemek menüsü fotoğrafı yönetimi (ADMIN). Uçlar: GET /api/admin/menu?from&to,
 * PUT /api/admin/menu/{date}/image (multipart alan `file`), DELETE /api/admin/menu/{date}/image (204).
 * Hatalar: 404 MENU_DAY_NOT_FOUND, doğrulama hataları `{code,message}`.
 */
export interface AdminMenuDay {
  /** yyyy-MM-dd */
  date: string;
  items: string[];
  imageUrl: string | null;
}

export interface MenuImageResult {
  date: string;
  imageUrl: string;
}

export const listMenu = (from: string, to: string) => api.get<AdminMenuDay[]>('/admin/menu', { from, to });

export const uploadMenuImage = (date: string, file: File) => {
  const form = new FormData();
  form.append('file', file);
  return api.putForm<MenuImageResult>(`/admin/menu/${date}/image`, form);
};

export const deleteMenuImage = (date: string) => api.del(`/admin/menu/${date}/image`);
