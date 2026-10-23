import { api } from './client';
import type { AuditParams, AuditRow, Page } from './types';

export const listAudit = (p: AuditParams = {}) => api.get<Page<AuditRow>>('/admin/audit', { ...p });
