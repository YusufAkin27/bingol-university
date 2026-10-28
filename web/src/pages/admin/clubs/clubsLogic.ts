// Kulüp yönetimi yardımcıları (saf fonksiyonlar; testlenebilir).
import type { Tone } from '../../../components/ui';
import type { ClubMember, ClubRole, ClubStatus, ClubUpdate, ClubDetail, ContentRow } from '../../../api/adminCommunities';

export const CLUB_STATUSES: ClubStatus[] = ['ACTIVE', 'PENDING_REVIEW', 'HIDDEN', 'REJECTED', 'DELETED'];
/** Rol seçici: sahiplik yalnız devirle verilir. */
export const ASSIGNABLE_ROLES: Exclude<ClubRole, 'OWNER'>[] = ['ADMIN', 'MODERATOR', 'MEMBER'];

export function statusTone(s: ClubStatus): Tone {
  switch (s) {
    case 'ACTIVE':
      return 'success';
    case 'PENDING_REVIEW':
      return 'warning';
    case 'HIDDEN':
    case 'REJECTED':
      return 'danger';
    default:
      return 'neutral';
  }
}

/** Sahibin rolü bu ekrandan değiştirilmez ve sahip çıkarılamaz (sunucu da reddeder: önce devir). */
export const isOwner = (m: Pick<ClubMember, 'role'>) => m.role === 'OWNER';
export const canChangeRole = (m: Pick<ClubMember, 'role' | 'status'>) => m.status === 'ACTIVE' && m.role !== 'OWNER';
export const canRemoveMember = (m: Pick<ClubMember, 'role'>) => m.role !== 'OWNER';

/** Form durumu (düzenleme sekmesi). */
export interface ClubForm {
  name: string;
  description: string;
  category: string;
  joinPolicy: 'OPEN' | 'APPROVAL';
  visibility: 'PUBLIC' | 'PRIVATE';
}

export function formFrom(d: ClubDetail): ClubForm {
  return {
    name: d.club.name,
    description: d.description ?? '',
    category: d.club.category ?? '',
    joinPolicy: d.club.joinPolicy,
    visibility: d.club.visibility,
  };
}

export const isDirty = (a: ClubForm, b: ClubForm) =>
  a.name.trim() !== b.name.trim() ||
  a.description.trim() !== b.description.trim() ||
  a.category !== b.category ||
  a.joinPolicy !== b.joinPolicy ||
  a.visibility !== b.visibility;

/** Yalnız değişen alanlar gönderilir (kısmi PATCH). Boş açıklama, açıklamayı temizler. */
export function diffToUpdate(base: ClubForm, next: ClubForm): ClubUpdate {
  const out: ClubUpdate = {};
  if (next.name.trim() !== base.name.trim()) out.name = next.name.trim();
  if (next.description.trim() !== base.description.trim()) out.description = next.description.trim();
  if (next.category !== base.category) out.category = next.category;
  if (next.joinPolicy !== base.joinPolicy) out.joinPolicy = next.joinPolicy;
  if (next.visibility !== base.visibility) out.visibility = next.visibility;
  return out;
}

/** Ad kuralı (sunucu ile aynı): 3-80 karakter. */
export const nameError = (name: string): 'short' | 'long' | null => {
  const n = name.trim().length;
  if (n < 3) return 'short';
  return n > 80 ? 'long' : null;
};

/** İçerik satırı özeti (liste): tek satıra sığdır. */
export function excerpt(text: string | null | undefined, max = 220): string {
  const flat = (text ?? '').replace(/\s+/g, ' ').trim();
  return flat.length > max ? `${flat.slice(0, max)}…` : flat;
}

export const canEditContent = (c: Pick<ContentRow, 'state'>) => c.state !== 'DELETED';

export function csvFilename(now = new Date()): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `kulupler-${now.getFullYear()}-${p(now.getMonth() + 1)}-${p(now.getDate())}.csv`;
}

/** Kulüp denetim eylemi -> okunur anahtar son eki (bilinmeyen eylem ham gösterilir). */
export const KNOWN_AUDIT_ACTIONS = [
  'ADMIN_CLUB_CLOSED',
  'ADMIN_CLUB_REOPENED',
  'ADMIN_CLUB_DELETED',
  'ADMIN_CLUB_EDITED',
  'ADMIN_OWNER_TRANSFER',
  'ADMIN_MEMBER_ROLE',
  'ADMIN_COVER_CHANGED',
  'ADMIN_POST_HIDDEN',
  'ADMIN_POST_UNHIDDEN',
  'ADMIN_POST_EDITED',
  'ADMIN_POST_DELETED',
  'COMMUNITY_DELETED',
  'MEMBER_REMOVED',
  'MEMBER_BANNED',
  'MEMBER_APPROVED',
  'MEMBER_REJECTED',
  'PERMISSIONS_SET',
  'PERMISSIONS_RESET',
  'TRANSFER_REQUESTED',
  'TRANSFER_ACCEPTED',
  'INVITE_CREATED',
  'INVITE_REVOKED',
  'ANNOUNCEMENT_POSTED',
] as const;
export type KnownAuditAction = (typeof KNOWN_AUDIT_ACTIONS)[number];
export const isKnownAction = (a: string): a is KnownAuditAction => (KNOWN_AUDIT_ACTIONS as readonly string[]).includes(a);
