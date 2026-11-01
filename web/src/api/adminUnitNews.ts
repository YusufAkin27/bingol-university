// Birim haberleri yönetimi: docs/UNIT_NEWS_API.md "Yönetici uçları" (/api/admin/unit-news).
import { api } from './client';

export type UnitSourceKind = 'FACULTY' | 'INSTITUTE' | 'VOCATIONAL' | 'LANGUAGE';

export interface UnitSource {
  code: string;
  name: string;
  kind: UnitSourceKind;
  baseUrl: string;
  enabled: boolean;
  graduate: boolean;
  facultyKeys: string[];
  departmentCount: number;
  announcementCount: number;
  lastSuccessAt: string | null;
  lastAttemptAt: string | null;
  lastMessage: string | null;
  maintenance: boolean;
}

export interface UnitDepartment {
  slug: string;
  name: string;
  nameKey: string;
  hasOwnFeed: boolean;
}

export interface UnitAnnouncementRow {
  id: number;
  sourceCode: string;
  sourceName: string;
  unitName: string | null;
  title: string;
  url: string;
  publishedDate: string;
  attachmentCount: number;
  hidden: boolean;
}

/** Spring sayfa yanıtı (bu uçlarda `items/page` değil `content/number`). */
export interface UnitSpringPage<T> {
  content: T[];
  totalElements: number;
  totalPages: number;
  number: number;
  size: number;
}

export interface UnitAnnouncementParams {
  source?: string;
  q?: string;
  hidden?: boolean;
  page?: number;
  size?: number;
}

const BASE = '/admin/unit-news';

export const listSources = () => api.get<UnitSource[]>(`${BASE}/sources`);
export const updateSource = (code: string, body: { enabled: boolean; facultyKeys: string[] }) =>
  api.put(`${BASE}/sources/${encodeURIComponent(code)}`, body);
export const listDepartments = (code: string) =>
  api.get<UnitDepartment[]>(`${BASE}/sources/${encodeURIComponent(code)}/departments`);
/** 202: kaynak siteye istek atar, hız sınırlıdır. */
export const syncSource = (code: string) => api.post(`${BASE}/sources/${encodeURIComponent(code)}/sync`);
export const syncAll = () => api.post(`${BASE}/sync`);
export const listAnnouncements = (p: UnitAnnouncementParams = {}) =>
  api.get<UnitSpringPage<UnitAnnouncementRow>>(`${BASE}/announcements`, { ...p });
/** Gizli duyuru öğrencilere gösterilmez; gerekçe gerekmez. */
export const setAnnouncementHidden = (id: number, hidden: boolean) =>
  api.put(`${BASE}/announcements/${id}/hidden`, { hidden });
