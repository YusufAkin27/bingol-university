// Yönetici kulüp yönetimi + kulüp içeriği moderasyonu (P06/P10). Sözleşme: docs/changes/clubadmin.md
// Uçlar: /api/admin/communities (liste/ayrıntı/düzenle/kapat/aç/sil/üyeler/devir/istekler/davetler),
// /api/admin/community-posts (kulüp gönderisi + duyurusu moderasyonu). Yıkıcı uçlar `X-Admin-Reason` + Idempotency-Key ister.
import { api, apiBlob } from './client';
import { guardHeaders, type GuardOpts } from './guard';

export type ClubStatus = 'PENDING_REVIEW' | 'ACTIVE' | 'REJECTED' | 'HIDDEN' | 'DELETED';
export type ClubJoinPolicy = 'OPEN' | 'APPROVAL';
export type ClubVisibility = 'PUBLIC' | 'PRIVATE';
export type ClubRole = 'OWNER' | 'ADMIN' | 'MODERATOR' | 'MEMBER';
export type ClubMemberStatus = 'ACTIVE' | 'PENDING' | 'BANNED';

/** Sayfa tabanlı yanıt (`total` = toplam kayıt). */
export interface ClubPage<T> {
  items: T[];
  page: number;
  size: number;
  total: number;
  totalPages: number;
}

export interface ClubRow {
  id: number;
  name: string;
  slug: string;
  category: string | null;
  status: ClubStatus;
  visibility: ClubVisibility;
  joinPolicy: ClubJoinPolicy;
  ownerId: number;
  ownerName: string | null;
  ownerEmail: string | null;
  coverUrl: string | null;
  logoUrl: string | null;
  memberCount: number;
  pendingCount: number;
  openReportCount: number;
  eventCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface ClubStaff {
  userId: number;
  displayName: string | null;
  email: string | null;
  role: ClubRole;
}

export interface ClubAuditRow {
  id: number;
  action: string;
  actorId: number | null;
  actorName: string | null;
  targetUserId: number | null;
  targetName: string | null;
  detail: string | null;
  at: string;
}

export interface ClubReportRow {
  id: number;
  reason: string;
  note: string | null;
  status: string;
  createdAt: string;
}

export interface ClubCapabilities {
  canEdit: boolean;
  canClose: boolean;
  canReopen: boolean;
  canDelete: boolean;
  canTransfer: boolean;
  canApprove: boolean;
}

export interface ClubDetail {
  club: ClubRow;
  description: string | null;
  reviewNote: string | null;
  staff: ClubStaff[];
  bannedCount: number;
  statusHistory: ClubAuditRow[];
  openReports: ClubReportRow[];
  recentAudit: ClubAuditRow[];
  capabilities: ClubCapabilities;
}

export interface ClubMember {
  userId: number;
  displayName: string | null;
  email: string | null;
  avatarUrl: string | null;
  role: ClubRole;
  status: ClubMemberStatus;
  accountStatus: string | null;
  joinedAt: string;
  customPermissions: boolean;
}

/** İşlem sonucu: `irreversible` true ise geri alınamaz. */
export interface ClubActionResult {
  id: number;
  status: ClubStatus;
  irreversible: boolean;
  notified: number;
}

export interface ClubMemberResult {
  communityId: number;
  userId: number;
  result: string;
}

export interface ClubInvite {
  id: number;
  codeHint: string;
  createdBy: number;
  maxUses: number | null;
  usedCount: number;
  expiresAt: string;
  revoked: boolean;
  state: string;
}

export interface ClubCursorAudit {
  items: {
    id: number;
    action: string;
    actorId: number | null;
    actorName: string | null;
    targetUserId: number | null;
    targetName: string | null;
    detail: string | null;
    createdAt: string;
  }[];
  nextCursor: number | null;
}

// ---- liste / ayrıntı ----

export interface ClubFilters {
  /** Boş = silinmişler hariç; ALL = hepsi. */
  status: ClubStatus | 'ALL' | '';
  category: string;
  q: string;
  visibility: ClubVisibility | '';
  joinPolicy: ClubJoinPolicy | '';
  /** Yalnız açık raporu olanlar. */
  reportedOnly: boolean;
  sort: 'createdAt' | 'name' | 'memberCount' | 'openReports';
  dir: 'asc' | 'desc';
}

export const EMPTY_CLUB_FILTERS: ClubFilters = {
  status: '',
  category: '',
  q: '',
  visibility: '',
  joinPolicy: '',
  reportedOnly: false,
  sort: 'createdAt',
  dir: 'desc',
};

function clubQuery(f: ClubFilters) {
  return {
    status: f.status || undefined,
    category: f.category.trim() || undefined,
    q: f.q.trim() || undefined,
    visibility: f.visibility || undefined,
    joinPolicy: f.joinPolicy || undefined,
    minReports: f.reportedOnly ? 1 : undefined,
  };
}

export const listClubs = (f: ClubFilters, page: number, size = 20) =>
  api.get<ClubPage<ClubRow>>('/admin/communities', { ...clubQuery(f), sort: f.sort, dir: f.dir, page, size });
/** CSV (UTF-8 BOM, en çok 50.000 satır); sayfa/sıralama yok sayılır. */
export const exportClubsCsv = (f: ClubFilters): Promise<Blob> =>
  apiBlob('/admin/communities/export.csv', { query: clubQuery(f) });
export const getClub = (id: number) => api.get<ClubDetail>(`/admin/communities/${id}`);

export interface ClubUpdate {
  name?: string;
  description?: string;
  category?: string;
  joinPolicy?: ClubJoinPolicy;
  visibility?: ClubVisibility;
}
export const updateClub = (id: number, body: ClubUpdate, o?: GuardOpts) =>
  api.patch<ClubDetail>(`/admin/communities/${id}`, body, guardHeaders(o));

// ---- durum ----

export const closeClub = (id: number, o: GuardOpts) =>
  api.post<ClubActionResult>(`/admin/communities/${id}/close`, undefined, guardHeaders(o));
export const reopenClub = (id: number, o: GuardOpts) =>
  api.post<ClubActionResult>(`/admin/communities/${id}/reopen`, undefined, guardHeaders(o));
/** Yumuşak silme, GERİ ALINAMAZ. */
export const deleteClub = (id: number, o: GuardOpts) =>
  api.del<ClubActionResult>(`/admin/communities/${id}`, guardHeaders(o));
export const transferClub = (id: number, targetUserId: number, keepAsAdmin: boolean, o: GuardOpts) =>
  api.post<ClubActionResult>(`/admin/communities/${id}/transfer-ownership`, { targetUserId, keepAsAdmin }, guardHeaders(o));

// ---- üyeler / istekler / davetler ----

export interface MemberFilters {
  status?: ClubMemberStatus | '';
  role?: ClubRole | '';
  q?: string;
}
export const listClubMembers = (id: number, f: MemberFilters, page: number, size = 20) =>
  api.get<ClubPage<ClubMember>>(`/admin/communities/${id}/members`, {
    status: f.status || undefined,
    role: f.role || undefined,
    q: f.q?.trim() || undefined,
    page,
    size,
  });
export const removeClubMember = (id: number, userId: number, ban: boolean, o: GuardOpts) =>
  api.del<ClubMemberResult>(`/admin/communities/${id}/members/${userId}${ban ? '?ban=true' : ''}`, guardHeaders(o));
export const setClubMemberRole = (id: number, userId: number, role: Exclude<ClubRole, 'OWNER'>, o: GuardOpts) =>
  api.patch<ClubMemberResult>(`/admin/communities/${id}/members/${userId}/role`, { role }, guardHeaders(o));

export const listJoinRequests = (id: number, page: number, size = 20) =>
  api.get<ClubPage<ClubMember>>(`/admin/communities/${id}/join-requests`, { page, size });
export const decideJoinRequest = (id: number, userId: number, approve: boolean, o?: GuardOpts) =>
  api.post<ClubMemberResult>(
    `/admin/communities/${id}/join-requests/${userId}/${approve ? 'approve' : 'reject'}`,
    undefined,
    guardHeaders(o),
  );
export const listClubInvites = (id: number) => api.get<ClubInvite[]>(`/admin/communities/${id}/invites`);
export const revokeClubInvite = (id: number, inviteId: number, o: GuardOpts) =>
  api.del<void>(`/admin/communities/${id}/invites/${inviteId}`, guardHeaders(o));
export const listClubAudit = (id: number, cursor?: number | null, size = 20) =>
  api.get<ClubCursorAudit>(`/admin/communities/${id}/club-audit`, { cursor: cursor ?? undefined, size });

// ---- kulüp içeriği (gönderi + duyuru) ----

export type ContentKind = 'POST' | 'ANNOUNCEMENT';
export type ContentState = 'VISIBLE' | 'HIDDEN' | 'DELETED';

export interface ContentAuthor {
  id: number;
  displayName: string | null;
  email: string | null;
  avatarUrl: string | null;
}

export interface ContentRow {
  id: number;
  communityId: number;
  communityName: string;
  kind: ContentKind;
  state: ContentState;
  author: ContentAuthor;
  text: string;
  imageUrl: string | null;
  pinned: boolean;
  openReportCount: number;
  hiddenReason: string | null;
  hiddenBy: number | null;
  hiddenAt: string | null;
  editedAt: string | null;
  createdAt: string;
}

export interface ContentDetail {
  post: ContentRow;
  reports: ClubReportRow[];
}

export interface ContentFilters {
  communityId?: number;
  kind: ContentKind | 'ALL';
  status: ContentState | 'ALL';
  q: string;
  minReports: string;
  from: string;
  to: string;
  sort: 'createdAt' | 'reports';
}

export const EMPTY_CONTENT_FILTERS: ContentFilters = {
  kind: 'ALL',
  status: 'ALL',
  q: '',
  minReports: '',
  from: '',
  to: '',
  sort: 'createdAt',
};

export const listContent = (f: ContentFilters, page: number, size = 20) =>
  api.get<ClubPage<ContentRow>>('/admin/community-posts', {
    communityId: f.communityId,
    kind: f.kind === 'ALL' ? undefined : f.kind,
    status: f.status === 'ALL' ? undefined : f.status,
    q: f.q.trim() || undefined,
    minReports: /^\d+$/.test(f.minReports.trim()) ? Number(f.minReports.trim()) : undefined,
    from: f.from || undefined,
    to: f.to || undefined,
    sort: f.sort === 'reports' ? 'reports' : undefined,
    page,
    size,
  });
export const getContent = (id: number) => api.get<ContentDetail>(`/admin/community-posts/${id}`);
export const editContent = (id: number, text: string, o?: GuardOpts) =>
  api.patch<ContentRow>(`/admin/community-posts/${id}`, { text }, guardHeaders(o));
export const hideContent = (id: number, o?: GuardOpts) =>
  api.post<ContentRow>(`/admin/community-posts/${id}/hide`, undefined, guardHeaders(o));
export const unhideContent = (id: number, o?: GuardOpts) =>
  api.post<ContentRow>(`/admin/community-posts/${id}/unhide`, undefined, guardHeaders(o));
/** Yumuşak silme, GERİ ALINAMAZ (görsel dosyası silinir). */
export const deleteContent = (id: number, o: GuardOpts) =>
  api.del<{ id: number; state: ContentState; irreversible: boolean }>(`/admin/community-posts/${id}`, guardHeaders(o));
