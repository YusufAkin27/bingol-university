import { api } from './client';
import type {
  BulkResolveRequest,
  BulkResultRow,
  CursorPage,
  ReasonTemplate,
  ReportOrder,
  ReportStatus,
  ReportTargetType,
  ReportView,
  ResolveReportRequest,
} from './types';

/**
 * Rapor kuyruğu. `order=priority` modunda `cursor` SAYFA NUMARASIDIR (0'dan); diğer modlarda rapor kimliği.
 * Varsayılan sıra eski davranışla aynı: en yeni önce (`desc`).
 */
export const listReports = (
  p: {
    status?: ReportStatus;
    order?: ReportOrder;
    targetType?: ReportTargetType | null;
    cursor?: number | null;
    size?: number;
  } = {},
) =>
  api.get<CursorPage<ReportView>>('/admin/reports', {
    status: p.status ?? 'OPEN',
    order: p.order ?? 'desc',
    targetType: p.targetType ?? undefined,
    cursor: p.cursor,
    size: p.size,
  });
export const resolveReport = (id: number, r: ResolveReportRequest) =>
  api.post(`/admin/reports/${id}/resolve`, r);
/** En çok 100 kimlik; satır hataları `error` kodu olarak döner (200). */
export const bulkResolve = (r: BulkResolveRequest) =>
  api.post<BulkResultRow[]>('/admin/reports/bulk-resolve', r);
export const reasonTemplates = () => api.get<ReasonTemplate[]>('/admin/reports/reason-templates');
