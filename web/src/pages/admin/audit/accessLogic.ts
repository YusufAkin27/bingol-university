// Mesaj erişim kaydı süzgeçleri: URL <-> durum <-> API sorgusu.
import { MESSAGE_ACCESS_KINDS, type MessageAccessQuery } from '../../../api/audit';

export const ACCESS_PAGE_SIZE = 20;
const DAY = /^\d{4}-\d{2}-\d{2}$/;

export interface AccessFilters {
  adminId?: number;
  targetUserId: string;
  conversationId: string;
  kind: string;
  q: string;
  from: string;
  to: string;
  page: number;
}

export const num = (s: string | null) => (s && /^\d+$/.test(s) ? s : '');

export function accessFiltersFromParams(sp: URLSearchParams): AccessFilters {
  const page = Number.parseInt(sp.get('page') ?? '0', 10);
  const adminId = Number.parseInt(sp.get('adminId') ?? '', 10);
  const kind = sp.get('kind') ?? '';
  const from = sp.get('from') ?? '';
  const to = sp.get('to') ?? '';
  return {
    adminId: Number.isFinite(adminId) ? adminId : undefined,
    targetUserId: num(sp.get('targetUserId')),
    conversationId: num(sp.get('conversationId')),
    kind: (MESSAGE_ACCESS_KINDS as readonly string[]).includes(kind) ? kind : '',
    q: sp.get('q') ?? '',
    from: DAY.test(from) ? from : '',
    to: DAY.test(to) ? to : '',
    page: Number.isFinite(page) && page > 0 ? page : 0,
  };
}

export function accessFiltersToParams(f: AccessFilters): URLSearchParams {
  const out = new URLSearchParams();
  if (f.adminId !== undefined) out.set('adminId', String(f.adminId));
  if (f.targetUserId) out.set('targetUserId', f.targetUserId);
  if (f.conversationId) out.set('conversationId', f.conversationId);
  if (f.kind) out.set('kind', f.kind);
  if (f.q) out.set('q', f.q);
  if (f.from) out.set('from', f.from);
  if (f.to) out.set('to', f.to);
  if (f.page > 0) out.set('page', String(f.page));
  return out;
}

export function accessFiltersToQuery(f: AccessFilters): MessageAccessQuery {
  const q: MessageAccessQuery = { page: f.page, size: ACCESS_PAGE_SIZE };
  if (f.adminId !== undefined) q.adminId = f.adminId;
  if (f.targetUserId) q.targetUserId = Number(f.targetUserId);
  if (f.conversationId) q.conversationId = Number(f.conversationId);
  if (f.kind) q.kind = f.kind;
  if (f.q) q.q = f.q;
  if (f.from) q.from = f.from;
  if (f.to) q.to = f.to;
  return q;
}
