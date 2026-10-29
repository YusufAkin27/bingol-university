import { api } from './client';

/**
 * Yemek menüsü fotoğrafı yönetimi (ADMIN). Uçlar: GET /api/admin/menu?from&to,
 * PUT /api/admin/menu/{date}/image (multipart alan `file`), DELETE /api/admin/menu/{date}/image (204).
 * Hatalar: 404 MENU_DAY_NOT_FOUND, doğrulama hataları `{code,message}`.
 * Kalori: PUT /api/admin/menu/{date}/calories `{items:[{name,kcal|null}]}` -> güncel gün (sıkı: 400 MENU_ITEM_NOT_FOUND /
 * MENU_KCAL_INVALID), PUT /api/admin/menu/calories `{days:[{date,items}]}` -> `{updated,cleared,unchanged,skipped}` (gevşek).
 */
export interface AdminMenuDish {
  name: string;
  /** Yöneticinin girdiği kalori (0-5000); girilmediyse null. */
  kcal: number | null;
}

export interface AdminMenuDay {
  /** yyyy-MM-dd */
  date: string;
  items: string[];
  imageUrl: string | null;
  /** `items` ile aynı sırada {ad, kcal}; eski sunucu yanıtında olmayabilir. */
  dishes?: AdminMenuDish[];
  /** Kalorisi bilinen yemeklerin toplamı; hiçbiri bilinmiyorsa null. */
  totalKcal?: number | null;
  /** Tüm yemeklerin kalorisi girilmiş mi (false ise toplam eksiktir). */
  kcalComplete?: boolean;
}

export interface KcalEntry {
  name: string;
  /** null = kaloriyi sil. */
  kcal: number | null;
}

export interface KcalBulkDay {
  date: string;
  items: KcalEntry[];
}

export interface KcalBulkResult {
  updated: number;
  cleared: number;
  unchanged: number;
  skipped: { date: string; name: string | null; reason: 'DAY_NOT_FOUND' | 'ITEM_NOT_FOUND' | 'NAME_INVALID' }[];
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

export const saveDayCalories = (date: string, items: KcalEntry[]) =>
  api.put<AdminMenuDay>(`/admin/menu/${date}/calories`, { items });

export const saveBulkCalories = (days: KcalBulkDay[]) => api.put<KcalBulkResult>('/admin/menu/calories', { days });
