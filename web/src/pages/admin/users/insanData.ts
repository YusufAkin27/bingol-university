// İnsanlar grubu: grafik/özet veri dönüşümleri (saf fonksiyonlar, test edilir). Sahte veri üretmez; yalnız gelen veriyi biçimlendirir.
import type { AdminUserDetail, BreakdownResponse, TwoFactorUserRow } from '../../../api/types';

export interface Trend {
  now: number;
  prev: number;
  /** null: karşılaştırma yok (önceki 0) ya da değişmedi. */
  pct: number | null;
  dir: 'up' | 'down' | 'same' | 'fromZero' | 'none';
}

/** İki dönemi karşılaştırır; önceki 0 ise uydurma yüzde yazılmaz. */
export function compareTrend(now: number, prev: number): Trend {
  if (now === 0 && prev === 0) return { now, prev, pct: null, dir: 'none' };
  if (now === 0 && prev > 0) return { now, prev, pct: 100, dir: 'down' };
  if (prev === 0) return { now, prev, pct: null, dir: 'fromZero' };
  const pct = Math.round(Math.abs((now - prev) / prev) * 100);
  if (now === prev) return { now, prev, pct: 0, dir: 'same' };
  return { now, prev, pct, dir: now > prev ? 'up' : 'down' };
}

/** Günlük seriden son 7 günü bir önceki 7 günle karşılaştırır (seri eskiden yeniye sıralı). */
export function weekOverWeek(counts: number[]): Trend | null {
  if (counts.length < 14) return null;
  const sum = (a: number[]) => a.reduce((s, n) => s + n, 0);
  const last = counts.slice(-7);
  const before = counts.slice(-14, -7);
  return compareTrend(sum(last), sum(before));
}

export interface StatusSlice {
  key: 'ACTIVE' | 'SUSPENDED' | 'DELETED';
  value: number;
}

/** Durum kırılımı → bilinen üç durum (sırası sabit: aktif, askıda, silindi). Bilinmeyen anahtarlar atılır. */
export function statusSlices(b: BreakdownResponse | undefined): StatusSlice[] {
  if (!b) return [];
  const by = new Map(b.items.map((i) => [i.key, i.count]));
  return (['ACTIVE', 'SUSPENDED', 'DELETED'] as const)
    .map((key) => ({ key, value: by.get(key) ?? 0 }))
    .filter((s) => s.value > 0);
}

export interface FacultyRow {
  key: string;
  label: string;
  value: number;
}

/** Fakülte kırılımı: boş/"unknown" satırı ayrılır (seçmemişler ayrı cümleyle söylenir). */
export function facultyRows(b: BreakdownResponse | undefined): { rows: FacultyRow[]; unset: number } {
  if (!b) return { rows: [], unset: 0 };
  let unset = 0;
  const rows: FacultyRow[] = [];
  for (const i of b.items) {
    if (!i.label || i.key === 'unknown' || i.key === '') unset += i.count;
    else rows.push({ key: i.key, label: i.label, value: i.count });
  }
  rows.sort((a, c) => c.value - a.value);
  return { rows, unset };
}

export interface AttentionInput {
  suspended: number | undefined;
  unverified: number | undefined;
  adminsNo2fa: number | undefined;
}
export type AttentionKind = 'suspended' | 'unverified' | 'adminNo2fa';
export interface AttentionItem {
  kind: AttentionKind;
  count: number;
  tone: 'danger' | 'warning';
}

/** Sayısı bilinen ve 0'dan büyük olanlar; önem sırası: askıda (acil), korumasız yönetici, doğrulamayan (dikkat). */
export function attentionItems(a: AttentionInput): AttentionItem[] {
  const out: AttentionItem[] = [];
  if (a.suspended) out.push({ kind: 'suspended', count: a.suspended, tone: 'danger' });
  if (a.adminsNo2fa) out.push({ kind: 'adminNo2fa', count: a.adminsNo2fa, tone: 'danger' });
  if (a.unverified) out.push({ kind: 'unverified', count: a.unverified, tone: 'warning' });
  return out;
}

// ---------- Kullanıcı ayrıntısı: risk özeti ----------
export type RiskLevel = 'high' | 'medium' | 'low' | 'clean' | 'deleted';
export type RiskFactorId =
  | 'suspended'
  | 'reportsMany'
  | 'reportsSome'
  | 'unverified'
  | 'adminNo2fa'
  | 'blockedBy'
  | 'neverSeen'
  | 'dormant';
export interface RiskFactor {
  id: RiskFactorId;
  tone: 'danger' | 'warning' | 'info';
  n?: number;
  /** Açıklamada gidilecek sekme. */
  goto?: 'support' | 'security';
}
export interface Risk {
  level: RiskLevel;
  factors: RiskFactor[];
}

const DAY = 86_400_000;

/** Ayrıntı verisinden, nedenleri açık yazılan basit risk özeti. Her etken gerçek bir alandan gelir. */
export function computeRisk(u: AdminUserDetail, now = Date.now()): Risk {
  if (u.status === 'DELETED') return { level: 'deleted', factors: [] };
  const f: RiskFactor[] = [];
  if (u.status === 'SUSPENDED') f.push({ id: 'suspended', tone: 'danger' });
  const openReports = u.extras
    ? u.extras.reportsAgainst.filter((r) => r.status === 'OPEN').length
    : u.counts.reportsAgainst;
  if (openReports >= 3) f.push({ id: 'reportsMany', tone: 'danger', n: openReports, goto: 'support' });
  else if (openReports > 0) f.push({ id: 'reportsSome', tone: 'warning', n: openReports, goto: 'support' });
  if (!u.emailVerified) f.push({ id: 'unverified', tone: 'warning' });
  if (u.role === 'ADMIN' && !u.twoFactorEnabled) f.push({ id: 'adminNo2fa', tone: 'warning', goto: 'security' });
  const blockedBy = u.extras?.blockedBy ?? 0;
  if (blockedBy >= 3) f.push({ id: 'blockedBy', tone: 'warning', n: blockedBy });
  const age = now - new Date(u.createdAt).getTime();
  if (!u.lastSeenAt) {
    if (age > 3 * DAY) f.push({ id: 'neverSeen', tone: 'info' });
  } else {
    const idle = Math.floor((now - new Date(u.lastSeenAt).getTime()) / DAY);
    if (idle >= 60) f.push({ id: 'dormant', tone: 'info', n: idle });
  }
  const level: RiskLevel = f.some((x) => x.tone === 'danger')
    ? 'high'
    : f.some((x) => x.tone === 'warning')
      ? 'medium'
      : f.length > 0
        ? 'low'
        : 'clean';
  return { level, factors: f };
}

// ---------- Kullanıcı ayrıntısı: zaman çizelgesi ----------
export type TimelineKind =
  | 'joined'
  | 'consent'
  | 'twoFactor'
  | 'device'
  | 'community'
  | 'ticket'
  | 'feedback'
  | 'reportAgainst'
  | 'reportFiled'
  | 'lastSeen'
  | 'deleted';
export interface TimelineEvent {
  id: string;
  at: string;
  kind: TimelineKind;
  tone: 'neutral' | 'success' | 'warning' | 'danger' | 'info';
  params: Record<string, string>;
}

const ts = (iso: string) => new Date(iso).getTime();

/** Ayrıntı verisindeki tarihli kayıtlardan en yeni üstte olay listesi. Geçersiz tarihler atılır. */
export function buildTimeline(u: AdminUserDetail, consentName: (type: string) => string): TimelineEvent[] {
  const ev: TimelineEvent[] = [];
  const add = (e: TimelineEvent) => {
    if (e.at && Number.isFinite(ts(e.at))) ev.push(e);
  };
  add({ id: 'joined', at: u.createdAt, kind: 'joined', tone: 'success', params: {} });
  for (const c of u.consents)
    add({ id: `c-${c.type}-${c.version}`, at: c.acceptedAt, kind: 'consent', tone: 'neutral', params: { name: consentName(c.type), v: String(c.version) } });
  if (u.twoFactorEnabledAt) add({ id: 'tf', at: u.twoFactorEnabledAt, kind: 'twoFactor', tone: 'success', params: {} });
  const x = u.extras;
  if (x) {
    x.devices.forEach((d, i) => add({ id: `d-${i}`, at: d.registeredAt, kind: 'device', tone: 'info', params: { platform: d.platform } }));
    for (const c of x.communities)
      if (c.joinedAt) add({ id: `m-${c.id}`, at: c.joinedAt, kind: 'community', tone: 'info', params: { name: c.name } });
    for (const t of x.tickets) add({ id: `t-${t.id}`, at: t.createdAt, kind: 'ticket', tone: 'neutral', params: { subject: t.subject } });
    for (const f of x.feedback) add({ id: `f-${f.id}`, at: f.createdAt, kind: 'feedback', tone: 'neutral', params: { subject: f.subject } });
    for (const r of x.reportsAgainst)
      add({ id: `ra-${r.id}`, at: r.createdAt, kind: 'reportAgainst', tone: r.status === 'OPEN' ? 'danger' : 'warning', params: { status: r.status } });
    for (const r of x.reportsFiled) add({ id: `rf-${r.id}`, at: r.createdAt, kind: 'reportFiled', tone: 'neutral', params: { status: r.status } });
  }
  if (u.lastSeenAt) add({ id: 'seen', at: u.lastSeenAt, kind: 'lastSeen', tone: 'neutral', params: {} });
  if (u.deletedAt) add({ id: 'del', at: u.deletedAt, kind: 'deleted', tone: 'danger', params: {} });
  return ev.sort((a, b) => ts(b.at) - ts(a.at));
}

// ---------- İki faktörlü: haftalık benimseme ----------
export interface WeekBucket {
  /** Haftanın ilk günü (yyyy-MM-dd, yerel gün). */
  week: string;
  count: number;
}

const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** Bugünün dahil olduğu 7 günlük dilimleri (en yeni sağda) `weeks` adet üretir ve `enabledAt` değerlerini sayar. */
export function weeklyEnablements(rows: Pick<TwoFactorUserRow, 'enabledAt'>[], weeks = 8, now = Date.now()): WeekBucket[] {
  const startOfToday = new Date(now);
  startOfToday.setHours(0, 0, 0, 0);
  const buckets: WeekBucket[] = [];
  for (let w = weeks - 1; w >= 0; w--) {
    const start = new Date(startOfToday.getTime() - (w * 7 + 6) * DAY);
    buckets.push({ week: iso(start), count: 0 });
  }
  const first = new Date(buckets[0].week + 'T00:00:00').getTime();
  for (const r of rows) {
    if (!r.enabledAt) continue;
    const t = ts(r.enabledAt);
    if (!Number.isFinite(t) || t < first || t > now) continue;
    const idx = Math.min(weeks - 1, Math.max(0, Math.floor((t - first) / (7 * DAY))));
    buckets[idx].count += 1;
  }
  return buckets;
}
