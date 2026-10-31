// P16: yönetici rol/izin matrisi. Uçlar: GET /admin/rbac/me|matrix|admins|changes, PUT /admin/rbac/users/{id}/profile,
// POST /admin/rbac/changes[/{id}/approve|reject] (backend: admin/rbac/RbacController). İzin anahtarları backend
// PermissionMatrix ile AYNIDIR; UI gizlemesi güvenlik değildir, asıl kontrol sunucudadır (403 ADMIN_PERMISSION_DENIED).
import { api } from './client';
import { guardHeaders, type GuardOpts } from './guard';

export type AdminProfile = 'FULL' | 'MODERATOR' | 'SUPPORT' | 'EDITOR' | 'VIEWER';

export const ADMIN_PROFILES: AdminProfile[] = ['FULL', 'MODERATOR', 'SUPPORT', 'EDITOR', 'VIEWER'];

/** İzin anahtarları (backend `PermissionMatrix` ile aynı). */
export type Permission =
  | 'dashboard.read'
  | 'analytics.read'
  | 'users.read'
  | 'users.pii'
  | 'users.write'
  | 'users.role'
  | 'users.delete'
  | 'users.verify'
  | 'users.export'
  | 'moderation.read'
  | 'moderation.write'
  | 'chat.read'
  | 'chat.write'
  | 'content.read'
  | 'content.write'
  | 'content.hide'
  | 'support.read'
  | 'support.write'
  | 'comms.read'
  | 'comms.write'
  | 'comms.send'
  | 'comms.single'
  | 'comms.announce'
  | 'legal.read'
  | 'legal.publish'
  | 'settings.read'
  | 'settings.write'
  | 'system.read'
  | 'system.write'
  | 'audit.read'
  | 'rbac.manage'
  | 'data.retention.read'
  | 'data.retention.export'
  | 'data.retention.purge'
  | 'admin.full';

export interface RbacMe {
  /** Basic auth yöneticisinde null. */
  userId: number | null;
  email: string | null;
  displayName: string | null;
  profile: AdminProfile;
  /** ADMIN_EMAILS'te sabitli hesap: her zaman FULL. */
  pinned: boolean;
  permissions: string[];
}

export interface MatrixEntry {
  permission: string;
  profiles: AdminProfile[];
}

export interface RbacMatrix {
  profiles: AdminProfile[];
  entries: MatrixEntry[];
}

export interface RbacAdminRow {
  id: number;
  email: string;
  displayName: string;
  profile: AdminProfile;
  pinned: boolean;
  status: string;
  lastSeenAt: string | null;
}

export type ChangeStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'EXPIRED';

export interface ProfileChange {
  id: number;
  targetUserId: number;
  targetEmail: string | null;
  targetName: string | null;
  fromProfile: AdminProfile | null;
  toProfile: AdminProfile;
  reason: string;
  proposedBy: number;
  proposedByEmail: string | null;
  proposedAt: string;
  expiresAt: string;
  status: ChangeStatus;
  decidedBy: number | null;
  decidedAt: string | null;
  decisionNote: string | null;
}

export const rbacKeys = {
  all: ['admin', 'rbac'] as const,
  me: ['admin', 'rbac', 'me'] as const,
  matrix: ['admin', 'rbac', 'matrix'] as const,
  admins: ['admin', 'rbac', 'admins'] as const,
  changes: (status?: ChangeStatus) => ['admin', 'rbac', 'changes', status ?? 'ALL'] as const,
  changesAll: ['admin', 'rbac', 'changes'] as const,
};

export const getRbacMe = () => api.get<RbacMe>('/admin/rbac/me');
export const getRbacMatrix = () => api.get<RbacMatrix>('/admin/rbac/matrix');
export const getRbacAdmins = () => api.get<RbacAdminRow[]>('/admin/rbac/admins');
export const getRbacChanges = (status?: ChangeStatus) =>
  api.get<ProfileChange[]>('/admin/rbac/changes', status ? { status } : undefined);

/** FULL'i ilgilendirmeyen profil atamasını doğrudan uygular (204). */
export const setAdminProfile = (userId: number, profile: AdminProfile, reason: string, o?: GuardOpts) =>
  api.put<void>(`/admin/rbac/users/${userId}/profile`, { profile, reason: reason.trim() }, guardHeaders({ ...o, reason }));

/** FULL'i düşürme / birini FULL yapma önerisi (ikinci FULL yönetici onaylar). */
export const proposeProfileChange = (userId: number, profile: AdminProfile, reason: string, o?: GuardOpts) =>
  api.post<ProfileChange>('/admin/rbac/changes', { userId, profile, reason: reason.trim() }, guardHeaders({ ...o, reason }));

export const approveProfileChange = (id: number, note?: string, o?: GuardOpts) =>
  api.post<ProfileChange>(`/admin/rbac/changes/${id}/approve`, { note: note?.trim() || undefined }, guardHeaders(o));

export const rejectProfileChange = (id: number, note?: string, o?: GuardOpts) =>
  api.post<ProfileChange>(`/admin/rbac/changes/${id}/reject`, { note: note?.trim() || undefined }, guardHeaders(o));

/** Doğrudan atama FULL'e dokunuyorsa (düşürme ya da FULL yapma) iki kişi onayı gerekir. */
export function needsTwoPerson(from: AdminProfile, to: AdminProfile): boolean {
  return from === 'FULL' || to === 'FULL';
}
