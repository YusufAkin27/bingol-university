// Erişim engelleri (IP / CIDR / cihaz / kullanıcı) ve anonimleştirici ağ listeleri.
// Uçlar: /admin/access-bans*, /admin/users/{id}/devices, /admin/users/{id}/block-access (backend: accessban/AccessBanDtos).
// Sunucu kayıtları burada arayüz tiplerine çevrilir (adapter); sayfalar ham sunucu şeklini bilmez.
import { api, apiFetch } from './client';
import { guardHeaders, type GuardOpts } from './guard';

export type BanKind = 'IP' | 'CIDR' | 'DEVICE' | 'USER';
export type BanReason = 'ABUSE' | 'SPAM' | 'FRAUD' | 'OTHER';
export const BAN_KINDS: BanKind[] = ['IP', 'CIDR', 'DEVICE', 'USER'];
export const BAN_REASONS: BanReason[] = ['ABUSE', 'SPAM', 'FRAUD', 'OTHER'];

export interface AccessBan {
  id: number;
  kind: BanKind;
  value: string;
  /** Cihaz için kısa özet; diğerlerinde değerin kendisi. */
  valueShort: string;
  /** USER türünde kullanıcının görünen adı. */
  label: string | null;
  userId: number | null;
  note: string | null;
  reasonCode: BanReason;
  createdBy: number | null;
  createdAt: string;
  expiresAt: string | null;
  active: boolean;
  hitCount: number;
  lastHitAt: string | null;
}

export interface AccessBanPage {
  items: AccessBan[];
  nextCursor: number | null;
}

export interface AccessBanStats {
  activeByKind: Partial<Record<BanKind, number>>;
  blockedLast24h: number;
  anonymizerRanges: number;
}

export interface AccessBanAttempt {
  at: string;
  ip: string | null;
  path: string | null;
  userId: number | null;
}

export interface AccessBanListParams {
  kind?: BanKind | '';
  active?: boolean | '';
  q?: string;
  cursor?: number | null;
  size?: number;
}

export interface CreateBanBody {
  kind: BanKind;
  value: string;
  reasonCode: BanReason;
  note?: string;
  expiresAt?: string | null;
  alsoBlockUserDevices?: boolean;
  alsoBlockUserIps?: boolean;
  force?: boolean;
}

export interface RejectedLine {
  line: number;
  value: string;
  /** Hata kodu (örn. BAN_INVALID_VALUE, BAN_SELF_LOCKOUT). */
  error: string;
}

export interface BulkResult {
  added: number;
  skipped: number;
  invalid: RejectedLine[];
}

export interface AnonymizerSource {
  /** Boş dize: etiketsiz yüklemeler. */
  source: string;
  count: number;
}

export interface AnonymizerList {
  /** Sunucu ayarı: anonimleştirici ağlar engelleniyor mu (salt okunur). */
  enforced: boolean;
  total: number;
  items: AnonymizerSource[];
}

export interface DeviceIp {
  ip: string;
  firstSeenAt: string;
  lastSeenAt: string;
  blocked: boolean;
}

export interface UserDevice {
  /** Tam özet (engelleme isteğinde bu kullanılır). */
  deviceHash: string;
  deviceHashShort: string;
  platform: string | null;
  appVersion: string | null;
  firstSeenAt: string;
  lastSeenAt: string;
  ips: DeviceIp[];
  blocked: boolean;
  sharedWithUsers: { id: number; displayName: string }[];
}

export interface UserDevicesInfo {
  devices: UserDevice[];
  /** Cihaz kimliği olmadan görülen IP'ler. */
  unidentifiedIps: DeviceIp[];
}

export interface BlockAccessBody {
  devices: boolean;
  ips: boolean;
  userBan: boolean;
  reasonCode: BanReason;
  note?: string;
  force?: boolean;
}

// ---------- sunucu şekilleri ----------
interface SrvBan {
  id: number;
  kind: BanKind;
  value: string;
  valueShort?: string | null;
  note?: string | null;
  reasonCode: BanReason;
  createdBy?: number | null;
  createdAt: string;
  expiresAt?: string | null;
  active: boolean;
  hitCount: number;
  lastHitAt?: string | null;
  userId?: number | null;
  userDisplayName?: string | null;
}
interface SrvPage<T> {
  items: T[];
  nextCursor: number | null;
}
interface SrvIp {
  ip: string;
  firstSeenAt: string;
  lastSeenAt: string;
  blocked?: boolean;
}
interface SrvDevice {
  deviceHash: string;
  deviceShort: string;
  platform?: string | null;
  appVersion?: string | null;
  firstSeenAt: string;
  lastSeenAt: string;
  ips?: SrvIp[];
  blocked: boolean;
  sharedWithUsers?: { id: number; displayName: string }[];
}
interface SrvRejected {
  line: number;
  value: string;
  error: string;
}

const toBan = (b: SrvBan): AccessBan => ({
  id: b.id,
  kind: b.kind,
  value: b.value,
  valueShort: b.valueShort || b.value,
  label: b.userDisplayName ?? null,
  userId: b.userId ?? null,
  note: b.note ?? null,
  reasonCode: b.reasonCode,
  createdBy: b.createdBy ?? null,
  createdAt: b.createdAt,
  expiresAt: b.expiresAt ?? null,
  active: b.active,
  hitCount: b.hitCount ?? 0,
  lastHitAt: b.lastHitAt ?? null,
});
const toIp = (i: SrvIp): DeviceIp => ({
  ip: i.ip,
  firstSeenAt: i.firstSeenAt,
  lastSeenAt: i.lastSeenAt,
  blocked: !!i.blocked,
});

const BASE = '/admin/access-bans';

export async function listBans(p: AccessBanListParams = {}): Promise<AccessBanPage> {
  const r = await api.get<SrvPage<SrvBan>>(BASE, {
    kind: p.kind || undefined,
    active: p.active === '' ? undefined : p.active,
    q: p.q || undefined,
    cursor: p.cursor ?? undefined,
    size: p.size,
  });
  return { items: (r.items ?? []).map(toBan), nextCursor: r.nextCursor ?? null };
}

export async function getStats(): Promise<AccessBanStats> {
  const r = await api.get<{
    activeBans?: Partial<Record<BanKind, number>>;
    blockedAttemptsLast24h?: number;
    anonymizerRanges?: number;
  }>(`${BASE}/stats`);
  return {
    activeByKind: r.activeBans ?? {},
    blockedLast24h: r.blockedAttemptsLast24h ?? 0,
    anonymizerRanges: r.anonymizerRanges ?? 0,
  };
}

/** Yanıt gövdesi (BlockAccessResult) arayüzde kullanılmaz. */
// W1-B (T-013): engel ekleme / toplu ekleme / kullanıcı erişim engeli gerekçe ister (>= 5 karakter, X-Admin-Reason).
export const createBan = (b: CreateBanBody, o?: GuardOpts) => api.post<unknown>(BASE, b, guardHeaders(o));

/** `noExpiry: true` süresiz yapar; `expiresAt` yeni bitiş (gelecekte). */
export const updateBan = (
  id: number,
  b: { note?: string; expiresAt?: string | null; noExpiry?: boolean; active?: boolean },
) => api.patch<unknown>(`${BASE}/${id}`, b);
export const removeBan = (id: number) => api.del(`${BASE}/${id}`);

export async function bulkAdd(
  b: { text: string; reasonCode: BanReason; note?: string; force?: boolean },
  o?: GuardOpts,
): Promise<BulkResult> {
  const r = await api.post<{ created: number; alreadyBanned: number; rejected?: SrvRejected[] }>(
    `${BASE}/bulk`,
    b,
    guardHeaders(o),
  );
  return { added: r.created ?? 0, skipped: r.alreadyBanned ?? 0, invalid: r.rejected ?? [] };
}

export async function listAttempts(id: number): Promise<AccessBanAttempt[]> {
  const r = await api.get<SrvPage<{ at: string; ip?: string | null; path?: string | null; userId?: number | null }>>(
    `${BASE}/${id}/attempts`,
    { size: 50 },
  );
  return (r.items ?? []).map((a) => ({ at: a.at, ip: a.ip ?? null, path: a.path ?? null, userId: a.userId ?? null }));
}

export async function listAnonymizers(): Promise<AnonymizerList> {
  const r = await api.get<{ enforced?: boolean; total?: number; bySource?: Record<string, number> }>(
    `${BASE}/anonymizers`,
    { size: 1 },
  );
  const items = Object.entries(r.bySource ?? {}).map(([source, count]) => ({ source, count }));
  return { enforced: !!r.enforced, total: r.total ?? items.reduce((a, i) => a + i.count, 0), items };
}

export async function addAnonymizers(b: { text: string; source: string }): Promise<BulkResult> {
  const r = await api.post<{ added: number; duplicates: number; rejected?: SrvRejected[] }>(`${BASE}/anonymizers`, b);
  return { added: r.added ?? 0, skipped: r.duplicates ?? 0, invalid: r.rejected ?? [] };
}

/** Bir kaynak etiketindeki tüm aralıkları siler (boş etiket: etiketsizler). */
export const removeAnonymizerSource = (source: string) =>
  apiFetch<{ deleted: number }>(`${BASE}/anonymizers`, { method: 'DELETE', query: { source } });

export async function listUserDevices(userId: number): Promise<UserDevicesInfo> {
  const r = await api.get<{ devices?: SrvDevice[]; unidentifiedIps?: SrvIp[] }>(`/admin/users/${userId}/devices`);
  return {
    devices: (r.devices ?? []).map((d) => ({
      deviceHash: d.deviceHash,
      deviceHashShort: d.deviceShort,
      platform: d.platform ?? null,
      appVersion: d.appVersion ?? null,
      firstSeenAt: d.firstSeenAt,
      lastSeenAt: d.lastSeenAt,
      ips: (d.ips ?? []).map(toIp),
      blocked: d.blocked,
      sharedWithUsers: d.sharedWithUsers ?? [],
    })),
    unidentifiedIps: (r.unidentifiedIps ?? []).map(toIp),
  };
}
export const blockUserAccess = (userId: number, b: BlockAccessBody, o?: GuardOpts) =>
  api.post<unknown>(`/admin/users/${userId}/block-access`, b, guardHeaders(o));

export const accessBanKeys = {
  all: ['access-bans'] as const,
  list: (p: Omit<AccessBanListParams, 'cursor'>) => ['access-bans', 'list', p] as const,
  stats: () => ['access-bans', 'stats'] as const,
  attempts: (id: number) => ['access-bans', 'attempts', id] as const,
  anonymizers: () => ['access-bans', 'anonymizers'] as const,
  devices: (userId: number) => ['access-bans', 'devices', userId] as const,
};
