// Kampüs Forum yönetimi (ADMIN). Uçlar: /api/admin/forum/{categories|reports|topics|actions} (sözleşme: docs/FORUM_API.md §2-D).
// Yanıt şekilleri TEK yerde (bu dosya) toplanır: backend belgesi (docs/changes/forum-d.md) ile ayrışırsa yalnız burası uyarlanır.
// Yazma işlemleri gerekçe ister: `X-Admin-Reason` başlığı (+ gövdede `reason`). Anonim içeriğin yazarı HİÇBİR yanıtta gelmez.
import { api, type Query } from './client';
import { cleanReason, guardHeaders, type GuardOpts } from './guard';

type Idem = Pick<GuardOpts, 'idempotencyKey'>;

// ---------- Ortak ----------
export type ForumTargetType = 'FORUM_TOPIC' | 'FORUM_COMMENT';
/** DELETED: sahibi sildi; MISSING: kayıt bulunamadı (yalnız şikâyet önizlemesinde). Her ikisinde içerik eylemi yoktur. */
export type ForumContentStatus = 'ACTIVE' | 'REMOVED' | 'DELETED' | 'MISSING';
const contentStatus = (v: unknown): ForumContentStatus =>
  v === 'REMOVED' || v === 'DELETED' || v === 'MISSING' ? v : 'ACTIVE';
/** Konu için moderatör eylemleri (POST .../moderate). Yorum için yalnız REMOVE | RESTORE. */
export type ForumTopicAction = 'PIN' | 'UNPIN' | 'LOCK' | 'UNLOCK' | 'REMOVE' | 'RESTORE';
export type ForumCommentAction = 'REMOVE' | 'RESTORE';

/** İmeç tabanlı liste: opak `nextCursor` (null ise son sayfa). */
export interface ForumCursorPage<T> {
  items: T[];
  nextCursor: string | number | null;
}
/** Sayfa tabanlı liste (0 tabanlı sayfa). */
export interface ForumPageList<T> {
  items: T[];
  page: number;
  totalPages: number;
  totalItems: number;
}

export const forumKeys = {
  all: ['adminForum'] as const,
  categories: () => ['adminForum', 'categories'] as const,
  reports: (f: unknown) => ['adminForum', 'reports', f] as const,
  topics: (f: unknown) => ['adminForum', 'topics', f] as const,
  actions: (f: unknown) => ['adminForum', 'actions', f] as const,
};

const num = (v: unknown, d = 0): number => (typeof v === 'number' && Number.isFinite(v) ? v : d);
const str = (v: unknown): string | null => (typeof v === 'string' ? v : null);
const rec = (v: unknown): Record<string, unknown> => (v && typeof v === 'object' ? (v as Record<string, unknown>) : {});

// ---------- Kategoriler ----------
export interface ForumCategory {
  id: number;
  slug: string;
  nameTr: string;
  nameEn: string;
  nameAr: string;
  sortOrder: number;
  active: boolean;
  topicCount: number;
}
/** Boş bırakılan alan GÖNDERİLMEZ: oluştururken sunucu Türkçe ada düşer, güncellerken mevcut değer kalır. */
export interface ForumCategoryInput {
  slug?: string;
  nameTr?: string;
  nameEn?: string;
  nameAr?: string;
  active?: boolean;
}

/** Yanıt `nameTr/nameEn/nameAr` ya da `names:{tr,en,ar}` olabilir; ikisini de kabul eder. */
export function normalizeCategory(raw: unknown): ForumCategory {
  const r = rec(raw);
  const names = rec(r.names);
  return {
    id: num(r.id),
    slug: str(r.slug) ?? '',
    nameTr: str(r.nameTr) ?? str(names.tr) ?? str(r.name) ?? '',
    nameEn: str(r.nameEn) ?? str(names.en) ?? '',
    nameAr: str(r.nameAr) ?? str(names.ar) ?? '',
    sortOrder: num(r.sortOrder),
    active: r.active !== false,
    topicCount: num(r.topicCount),
  };
}

/** Yanıt düz dizi ya da `{items}` olabilir. */
function itemsOf(raw: unknown): unknown[] {
  if (Array.isArray(raw)) return raw;
  const items = rec(raw).items;
  return Array.isArray(items) ? items : [];
}

export const listCategories = async (): Promise<ForumCategory[]> => {
  const raw = await api.get<unknown>('/admin/forum/categories');
  return itemsOf(raw)
    .map(normalizeCategory)
    .sort((a, b) => a.sortOrder - b.sortOrder || a.id - b.id);
};
export const createCategory = (b: ForumCategoryInput) => api.post<unknown>('/admin/forum/categories', b);
export const updateCategory = (id: number, b: Partial<ForumCategoryInput>) =>
  api.patch<unknown>(`/admin/forum/categories/${id}`, b);
/** DELETE = arşivle (`active=false`); kategori ve konuları silinmez. */
export const archiveCategory = (id: number) => api.del(`/admin/forum/categories/${id}`);
export const reorderCategories = (ids: number[]) => api.post<unknown>('/admin/forum/categories/reorder', { ids });

// ---------- Konular ----------
export interface ForumTopicRow {
  id: number;
  title: string;
  /** Tam gövde yoksa önizleme. */
  body: string;
  categoryId: number | null;
  categoryName: string | null;
  /** Anonim ise yazar adı "Anonim #N" ya da null; kimlik asla gelmez. */
  authorName: string | null;
  anonymous: boolean;
  status: ForumContentStatus;
  pinned: boolean;
  locked: boolean;
  commentCount: number;
  likeCount: number;
  openReportCount: number;
  removedReason: string | null;
  createdAt: string;
}
export interface ForumTopicFilters {
  q?: string;
  /** '' = varsayılan (sahibinin silmedikleri); PINNED/LOCKED/DELETED/ALL sunucu süzgeçleri. */
  status?: '' | 'ACTIVE' | 'REMOVED' | 'DELETED' | 'PINNED' | 'LOCKED' | 'ALL';
  categoryId?: string;
}

export function normalizeTopic(raw: unknown): ForumTopicRow {
  const r = rec(raw);
  const cat = rec(r.category);
  const author = rec(r.author);
  const anonymous = r.anonymous === true || author.anonymous === true;
  return {
    id: num(r.id),
    title: str(r.title) ?? '',
    body: str(r.body) ?? str(r.bodyPreview) ?? '',
    categoryId: typeof r.categoryId === 'number' ? r.categoryId : typeof cat.id === 'number' ? cat.id : null,
    categoryName: str(r.categoryName) ?? str(cat.name) ?? null,
    // anonimde ad hiç taşınmaz: arayüz "Anonim" yazar (sunucu zaten kimlik vermez; burada ikinci emniyet)
    authorName: anonymous ? null : (str(author.displayName) ?? str(r.authorName)),
    anonymous,
    status: contentStatus(r.status),
    pinned: r.pinned === true || (typeof r.pinnedAt === 'string' && r.pinnedAt !== ''),
    locked: r.locked === true || (typeof r.lockedAt === 'string' && r.lockedAt !== ''),
    commentCount: num(r.commentCount),
    likeCount: num(r.likeCount),
    openReportCount: num(r.openReportCount ?? r.reportCount),
    removedReason: str(r.removedReason),
    createdAt: str(r.createdAt) ?? '',
  };
}

export const listTopics = async (f: ForumTopicFilters, page = 0, size = 20): Promise<ForumPageList<ForumTopicRow>> => {
  const query: Query = {
    q: f.q?.trim() || undefined,
    status: f.status || undefined,
    categoryId: f.categoryId && /^\d+$/.test(f.categoryId) ? Number(f.categoryId) : undefined,
    page,
    size,
  };
  const raw = rec(await api.get<unknown>('/admin/forum/topics', query));
  const items = itemsOf(raw).map(normalizeTopic);
  return {
    items,
    page: num(raw.page, page),
    totalPages: num(raw.totalPages, 1),
    totalItems: num(raw.totalItems, items.length),
  };
};

/** Gerekçe zorunlu (sunucu `X-Admin-Reason` ister); gövdede de gider. */
export const moderateTopic = (id: number, action: ForumTopicAction, reason: string, o?: Idem) =>
  api.post<unknown>(
    `/admin/forum/topics/${id}/moderate`,
    { action, reason: cleanReason(reason) },
    guardHeaders({ ...o, reason }),
  );
export const moderateComment = (id: number, action: ForumCommentAction, reason: string, o?: Idem) =>
  api.post<unknown>(
    `/admin/forum/comments/${id}/moderate`,
    { action, reason: cleanReason(reason) },
    guardHeaders({ ...o, reason }),
  );

// ---------- Şikâyet kuyruğu ----------
export type ForumReportStatus = 'OPEN' | 'RESOLVED';
export type ForumReportReason = 'SPAM' | 'HARASSMENT' | 'INAPPROPRIATE' | 'PERSONAL_INFO' | 'OTHER';
export const FORUM_REPORT_REASONS: ForumReportReason[] = ['SPAM', 'HARASSMENT', 'INAPPROPRIATE', 'PERSONAL_INFO', 'OTHER'];

export interface ForumReportRow {
  /** Şikâyet kimliği (çözme ucu bunu kullanır). */
  id: number;
  targetType: ForumTargetType;
  targetId: number;
  /** Yorum şikâyetinde bağlı konu; konu şikâyetinde = targetId. */
  topicId: number | null;
  status: ForumReportStatus;
  reasons: string[];
  note: string | null;
  /** Aynı hedefe gelen şikâyet sayısı. */
  reportCount: number;
  createdAt: string;
  preview: {
    title: string | null;
    body: string | null;
    authorName: string | null;
    anonymous: boolean;
    contentStatus: ForumContentStatus;
    pinned: boolean;
    locked: boolean;
  };
}
export interface ForumReportFilters {
  status: ForumReportStatus | '';
  type: ForumTargetType | '';
  reason: ForumReportReason | '';
}

export function normalizeReport(raw: unknown): ForumReportRow {
  const r = rec(raw);
  const p = rec(r.preview ?? r.target);
  const author = rec(p.author);
  const reasons = Array.isArray(r.reasons)
    ? (r.reasons as unknown[]).filter((x): x is string => typeof x === 'string')
    : typeof r.reason === 'string'
      ? [r.reason]
      : [];
  const targetType: ForumTargetType = r.targetType === 'FORUM_COMMENT' ? 'FORUM_COMMENT' : 'FORUM_TOPIC';
  const targetId = num(r.targetId);
  const anonymousPreview = p.anonymous === true || author.anonymous === true;
  return {
    id: num(r.id),
    targetType,
    targetId,
    topicId: typeof r.topicId === 'number' ? r.topicId : targetType === 'FORUM_TOPIC' ? targetId : null,
    status: r.status === 'RESOLVED' ? 'RESOLVED' : 'OPEN',
    reasons,
    note: str(r.note),
    reportCount: num(r.reportCount ?? r.openReporters, 1),
    createdAt: str(r.createdAt) ?? '',
    preview: {
      title: str(p.title),
      body: str(p.body) ?? str(p.bodyPreview) ?? str(p.text),
      authorName: anonymousPreview ? null : (str(p.authorName) ?? str(author.displayName)),
      anonymous: anonymousPreview,
      contentStatus: contentStatus(p.contentStatus ?? p.status),
      pinned: p.pinned === true,
      locked: p.locked === true,
    },
  };
}

export const listReports = async (f: ForumReportFilters, cursor?: string | number | null, size = 20) => {
  const raw = rec(
    await api.get<unknown>('/admin/forum/reports', {
      status: f.status || undefined,
      type: f.type || undefined,
      reason: f.reason || undefined,
      cursor: cursor ?? undefined,
      size,
    }),
  );
  const out: ForumCursorPage<ForumReportRow> = {
    items: itemsOf(raw).map(normalizeReport),
    nextCursor: typeof raw.nextCursor === 'string' || typeof raw.nextCursor === 'number' ? raw.nextCursor : null,
  };
  return out;
};

/** Şikâyeti içeriğe dokunmadan sonuçlandırır (yoksay/çöz). */
export const resolveReport = (id: number, reason: string, o?: Idem) =>
  api.post<unknown>(
    `/admin/forum/reports/${id}/resolve`,
    { action: 'DISMISS', message: cleanReason(reason) },
    guardHeaders({ ...o, reason }),
  );

// ---------- İşlem kayıtları ----------
export interface ForumActionRow {
  id: number;
  actorName: string | null;
  actorId: number | null;
  targetType: ForumTargetType;
  targetId: number;
  action: string;
  reason: string;
  createdAt: string;
}
export interface ForumActionFilters {
  action: string;
  type: ForumTargetType | '';
}

export function normalizeAction(raw: unknown): ForumActionRow {
  const r = rec(raw);
  const actor = rec(r.actor);
  return {
    id: num(r.id),
    actorName: str(r.actorName) ?? str(actor.displayName) ?? str(actor.email),
    actorId: typeof r.actorId === 'number' ? r.actorId : typeof actor.id === 'number' ? actor.id : null,
    targetType: r.targetType === 'FORUM_COMMENT' ? 'FORUM_COMMENT' : 'FORUM_TOPIC',
    targetId: num(r.targetId),
    action: str(r.action) ?? '',
    reason: str(r.reason) ?? '',
    createdAt: str(r.createdAt) ?? '',
  };
}

export const listActions = async (f: ForumActionFilters, cursor?: string | number | null, size = 30) => {
  const raw = rec(
    await api.get<unknown>('/admin/forum/actions', {
      action: f.action || undefined,
      targetType: f.type || undefined,
      cursor: cursor ?? undefined,
      size,
    }),
  );
  const out: ForumCursorPage<ForumActionRow> = {
    items: itemsOf(raw).map(normalizeAction),
    nextCursor: typeof raw.nextCursor === 'string' || typeof raw.nextCursor === 'number' ? raw.nextCursor : null,
  };
  return out;
};
