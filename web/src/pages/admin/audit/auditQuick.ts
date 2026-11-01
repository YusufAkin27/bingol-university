// Denetim kaydı hızlı süzgeç çipleri ve etkin süzgeç çipleri (saf mantık).
import { addDays } from './auditStats';
import type { AuditFilters } from './auditLogic';

export type QuickPresetId = 'today' | 'week' | 'denied' | 'errors' | 'deletes';
export const QUICK_PRESETS: QuickPresetId[] = ['today', 'week', 'denied', 'errors', 'deletes'];

/** Çip basılıyken sayfa 0'a döner; ilgili süzgeç alanları ayarlanır. */
export function presetPatch(id: QuickPresetId, today: string): Partial<AuditFilters> {
  switch (id) {
    case 'today':
      return { from: today, to: today };
    case 'week':
      return { from: addDays(today, -6), to: today };
    case 'denied':
      return { status: '403' };
    case 'errors':
      return { status: '5xx' };
    case 'deletes':
      return { method: 'DELETE' };
  }
}

/** Çip kapatılırken temizlenen alanlar. */
export function presetClearPatch(id: QuickPresetId): Partial<AuditFilters> {
  switch (id) {
    case 'today':
    case 'week':
      return { from: '', to: '' };
    case 'denied':
    case 'errors':
      return { status: '' };
    case 'deletes':
      return { method: '' };
  }
}

export function presetActive(id: QuickPresetId, f: AuditFilters, today: string): boolean {
  switch (id) {
    case 'today':
      return f.from === today && f.to === today;
    case 'week':
      return f.from === addDays(today, -6) && f.to === today;
    case 'denied':
      return f.status === '403';
    case 'errors':
      return f.status === '5xx';
    case 'deletes':
      return f.method === 'DELETE';
  }
}

export type FilterChipId = 'adminId' | 'method' | 'status' | 'q' | 'range' | 'targetType' | 'targetId';

export interface ActiveChip {
  id: FilterChipId;
  /** Süzgeç adı ("Yöntem") */
  nameKey: string;
  /** Değer ("DELETE") */
  value: string;
  clear: Partial<AuditFilters>;
}

/** Etkin süzgeçleri kaldırılabilir çip listesine çevirir (tarih aralığı tek çip). */
export function activeChips(f: AuditFilters, adminName?: (id: number) => string): ActiveChip[] {
  const out: ActiveChip[] = [];
  if (f.adminId !== undefined)
    out.push({ id: 'adminId', nameKey: 'admin.audit.filter.admin', value: adminName?.(f.adminId) ?? `#${f.adminId}`, clear: { adminId: undefined } });
  if (f.method) out.push({ id: 'method', nameKey: 'admin.audit.filter.method', value: f.method, clear: { method: '' } });
  if (f.status) out.push({ id: 'status', nameKey: 'admin.wp02.audit.filter.status', value: f.status, clear: { status: '' } });
  if (f.q) out.push({ id: 'q', nameKey: 'admin.sys2.audit.chip.q', value: f.q, clear: { q: '' } });
  if (f.from || f.to)
    out.push({
      id: 'range',
      nameKey: 'admin.sys2.audit.chip.range',
      value: f.from && f.to && f.from !== f.to ? `${f.from} – ${f.to}` : f.from || f.to,
      clear: { from: '', to: '' },
    });
  if (f.targetType) out.push({ id: 'targetType', nameKey: 'admin.wp02.audit.filter.targetType', value: f.targetType, clear: { targetType: '' } });
  if (f.targetId) out.push({ id: 'targetId', nameKey: 'admin.wp02.audit.filter.targetId', value: f.targetId, clear: { targetId: '' } });
  return out;
}
