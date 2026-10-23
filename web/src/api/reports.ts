import { api } from './client';
import type { CursorPage, ReportStatus, ReportView, ResolveReportRequest } from './types';

export const listReports = (p: { status?: ReportStatus; cursor?: number | null; size?: number } = {}) =>
  api.get<CursorPage<ReportView>>('/admin/reports', {
    status: p.status ?? 'OPEN',
    cursor: p.cursor,
    size: p.size,
  });
export const resolveReport = (id: number, r: ResolveReportRequest) =>
  api.post(`/admin/reports/${id}/resolve`, r);
