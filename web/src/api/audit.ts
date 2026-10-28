// Denetim kaydı v2 (P02, V630): GET /api/admin/audit (süzgeçler + hedef/sebep/özet/istek kimliği),
// GET /api/admin/audit/export.csv (en çok 50.000 satır; isteğin kendisi denetlenir),
// GET /api/admin/audit/message-access (sohbet içeriği erişim kayıtları; içerik dönmez).
import { api, apiBlob } from './client';
import type { AuditParams, AuditRow, Page } from './types';

/** v2 satırı: eski satırlarda yeni alanlar `null` (ya da hiç gelmez). */
export interface AuditRowV2 extends AuditRow {
  targetType?: string | null;
  targetId?: string | null;
  reason?: string | null;
  summary?: string | null;
  requestId?: string | null;
}

/** Süzgeçler: `from`/`to` `yyyy-MM-dd` (Europe/Istanbul günü, `to` o günü dahil); `status` tam kod (403) ya da sınıf (4xx). */
export interface AuditQuery extends AuditParams {
  from?: string;
  to?: string;
  targetType?: string;
  targetId?: string;
  status?: string;
}

/** Boş süzgeçleri atar (sunucuya yalnız dolu alanlar gider). */
export function cleanAuditQuery<T extends object>(p: T): Record<string, string | number> {
  const out: Record<string, string | number> = {};
  for (const [k, v] of Object.entries(p)) {
    if (v === undefined || v === null || v === '') continue;
    out[k] = v as string | number;
  }
  return out;
}

export const listAudit = (p: AuditQuery = {}) => api.get<Page<AuditRowV2>>('/admin/audit', cleanAuditQuery(p));

/** CSV (UTF-8 BOM). Sayfa parametreleri gönderilmez: tüm süzgeçlere uyan en yeni 50.000 satır. */
export const exportAuditCsv = (p: Omit<AuditQuery, 'page' | 'size'> = {}): Promise<Blob> =>
  apiBlob('/admin/audit/export.csv', { query: cleanAuditQuery(p) });

export type MessageAccessKind = 'LIST_PREVIEW' | 'VIEW_MESSAGES' | 'MEDIA' | 'FEED' | 'REPORT_CONTEXT';
export const MESSAGE_ACCESS_KINDS: readonly MessageAccessKind[] = [
  'LIST_PREVIEW',
  'VIEW_MESSAGES',
  'MEDIA',
  'FEED',
  'REPORT_CONTEXT',
];

export interface MessageAccessRow {
  id: number;
  adminId: number | null;
  adminEmail: string | null;
  conversationId: number | null;
  targetUserId: number | null;
  kind: MessageAccessKind | string;
  messageCount: number | null;
  fromMessageId: number | null;
  toMessageId: number | null;
  reason: string | null;
  ip: string | null;
  at: string;
}

export interface MessageAccessQuery {
  page?: number;
  size?: number;
  adminId?: number;
  targetUserId?: number;
  conversationId?: number;
  kind?: string;
  q?: string;
  from?: string;
  to?: string;
}

export const listMessageAccess = (p: MessageAccessQuery = {}) =>
  api.get<Page<MessageAccessRow>>('/admin/audit/message-access', cleanAuditQuery(p));
