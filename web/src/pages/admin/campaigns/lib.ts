/**
 * Kampanya oluşturucunun saf mantığı (arayüzden bağımsız, birim testli): kitle doğrulaması, karakter sayaçları,
 * yerel saat -> ISO UTC dönüşümü, hedef doğrulaması, istek kurma ve taslak saklama.
 */
import type {
  AudienceType,
  CampaignAudience,
  CampaignTargetType,
  CreateCampaignRequest,
  Lang,
} from '../../../api/types';
import { readStorage, removeStorage, writeStorage } from '../../../lib/storage';

export const TITLE_MAX = 100;
export const BODY_MAX = 300;
export const MAX_USERS = 500;
export const MAX_SCHEDULE_DAYS = 30;
export const DRAFT_KEY = 'bu.admin.campaignDraft';

export const LANGS: Lang[] = ['tr', 'en', 'ar'];
export const AUDIENCE_TYPES: AudienceType[] = ['ALL', 'DEPARTMENT', 'CLASS_YEAR', 'USERS', 'ADMINS', 'SELF'];
export type ComposeNotifType = 'ANNOUNCEMENT' | 'NEWS' | 'EVENT' | 'SYSTEM';
export const NOTIF_TYPES: ComposeNotifType[] = ['ANNOUNCEMENT', 'NEWS', 'EVENT', 'SYSTEM'];
export type ComposeTargetType = Extract<CampaignTargetType, 'NONE' | 'NEWS' | 'EVENT' | 'COMMUNITY' | 'URL'>;
export const TARGET_TYPES: ComposeTargetType[] = ['NONE', 'NEWS', 'EVENT', 'COMMUNITY', 'URL'];

export interface PickedUser {
  id: number;
  displayName: string;
  email: string;
}

export interface LangContent {
  title: string;
  body: string;
}

export interface ComposeState {
  audienceType: AudienceType;
  department: string;
  classYear: string;
  users: PickedUser[];
  contents: Record<Lang, LangContent>;
  notifType: ComposeNotifType;
  targetType: ComposeTargetType;
  targetValue: string;
  scheduleMode: 'now' | 'later';
  /** `datetime-local` biçimi: yyyy-MM-ddTHH:mm (yerel saat) */
  scheduledLocal: string;
}

export function emptyState(): ComposeState {
  return {
    audienceType: 'SELF',
    department: '',
    classYear: '',
    users: [],
    contents: {
      tr: { title: '', body: '' },
      en: { title: '', body: '' },
      ar: { title: '', body: '' },
    },
    notifType: 'ANNOUNCEMENT',
    targetType: 'NONE',
    targetValue: '',
    scheduleMode: 'now',
    scheduledLocal: '',
  };
}

// ---------- kitle ----------

export type AudienceError = 'DEPARTMENT_REQUIRED' | 'CLASS_YEAR_INVALID' | 'USERS_EMPTY' | 'USERS_TOO_MANY';

/** Seçime göre API kitlesi; eksik/geçersizse hata kodu. */
export function audienceFromState(
  s: Pick<ComposeState, 'audienceType' | 'department' | 'classYear' | 'users'>,
): { audience: CampaignAudience; error?: undefined } | { audience?: undefined; error: AudienceError } {
  switch (s.audienceType) {
    case 'DEPARTMENT': {
      const v = s.department.trim();
      if (!v || v.length > 120) return { error: 'DEPARTMENT_REQUIRED' };
      return { audience: { type: 'DEPARTMENT', value: v } };
    }
    case 'CLASS_YEAR': {
      const n = Number(s.classYear);
      if (!/^\d+$/.test(s.classYear.trim()) || n < 1 || n > 8) return { error: 'CLASS_YEAR_INVALID' };
      return { audience: { type: 'CLASS_YEAR', value: String(n) } };
    }
    case 'USERS': {
      if (s.users.length === 0) return { error: 'USERS_EMPTY' };
      if (s.users.length > MAX_USERS) return { error: 'USERS_TOO_MANY' };
      return { audience: { type: 'USERS', value: s.users.map((u) => u.id).join(',') } };
    }
    default:
      return { audience: { type: s.audienceType, value: null } };
  }
}

// ---------- sayaçlar ----------

export type CounterTone = 'ok' | 'warn' | 'over';
/** Sınıra %90'dan sonra uyarı, aşınca hata tonu. */
export function counterTone(length: number, max: number): CounterTone {
  if (length > max) return 'over';
  return length >= Math.floor(max * 0.9) ? 'warn' : 'ok';
}

// ---------- zaman ----------

/** `yyyy-MM-ddTHH:mm` (yerel) -> ISO UTC; geçersizse null. */
export function localToIso(local: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(local)) return null;
  const d = new Date(local);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

/** Date -> `yyyy-MM-ddTHH:mm` (yerel saat) */
export function toLocalInput(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

export type ScheduleError = 'REQUIRED' | 'PAST' | 'TOO_FAR';
export function scheduleError(local: string, now: Date): ScheduleError | null {
  const iso = localToIso(local);
  if (!iso) return 'REQUIRED';
  const at = new Date(iso).getTime();
  if (at <= now.getTime()) return 'PAST';
  if (at > now.getTime() + MAX_SCHEDULE_DAYS * 24 * 3600 * 1000) return 'TOO_FAR';
  return null;
}

// ---------- hedef ----------

export type TargetError = 'ID_REQUIRED' | 'URL_HTTPS';
export function targetError(type: ComposeTargetType, value: string): TargetError | null {
  const v = value.trim();
  if (type === 'NONE') return null;
  if (type === 'URL') return /^https:\/\/\S+$/i.test(v) && v.length <= 500 ? null : 'URL_HTTPS';
  return /^\d{1,18}$/.test(v) ? null : 'ID_REQUIRED';
}

// ---------- içerik ----------

export type ContentError = 'TR_REQUIRED' | 'TOO_LONG' | 'PARTIAL';
/** Boş bırakılan dilde Türkçe gider; yalnızca başlık veya yalnızca metin dolu olan dil hatalıdır. */
export function contentErrors(contents: Record<Lang, LangContent>): Partial<Record<Lang, ContentError>> {
  const out: Partial<Record<Lang, ContentError>> = {};
  for (const l of LANGS) {
    const title = contents[l].title.trim();
    const body = contents[l].body.trim();
    if (l === 'tr' && (!title || !body)) out[l] = 'TR_REQUIRED';
    else if (contents[l].title.length > TITLE_MAX || contents[l].body.length > BODY_MAX) out[l] = 'TOO_LONG';
    else if (l !== 'tr' && (!title) !== (!body)) out[l] = 'PARTIAL';
  }
  return out;
}

/** Hangi dillerde içerik tamamlanmış (boş olmayan başlık+metin). */
export function filledLangs(contents: Record<Lang, LangContent>): Lang[] {
  return LANGS.filter((l) => contents[l].title.trim() && contents[l].body.trim());
}

export interface BuildResult {
  request?: CreateCampaignRequest;
  audienceError?: AudienceError;
  contentErrors: Partial<Record<Lang, ContentError>>;
  targetError: TargetError | null;
  scheduleError: ScheduleError | null;
  valid: boolean;
}

export function buildRequest(s: ComposeState, now: Date, audienceCount: number | null): BuildResult {
  const a = audienceFromState(s);
  const cErr = contentErrors(s.contents);
  const tErr = targetError(s.targetType, s.targetValue);
  const sErr = s.scheduleMode === 'later' ? scheduleError(s.scheduledLocal, now) : null;
  const valid =
    !a.error && Object.keys(cErr).length === 0 && !tErr && !sErr && audienceCount !== null && audienceCount > 0;
  if (!valid || !a.audience) {
    return { audienceError: a.error, contentErrors: cErr, targetError: tErr, scheduleError: sErr, valid: false };
  }
  const trim = (c: LangContent) => ({ title: c.title.trim(), body: c.body.trim() });
  const req: CreateCampaignRequest = {
    type: s.notifType,
    audience: a.audience,
    tr: trim(s.contents.tr),
    target: { type: s.targetType, value: s.targetType === 'NONE' ? null : s.targetValue.trim() },
  };
  if (s.contents.en.title.trim() && s.contents.en.body.trim()) req.en = trim(s.contents.en);
  if (s.contents.ar.title.trim() && s.contents.ar.body.trim()) req.ar = trim(s.contents.ar);
  if (s.scheduleMode === 'later') req.scheduledAt = localToIso(s.scheduledLocal) ?? undefined;
  return { request: req, contentErrors: cErr, targetError: tErr, scheduleError: sErr, valid: true };
}

/** Çift onay gerektiren tehlikeli gönderimler. */
export function needsExtraConfirm(s: Pick<ComposeState, 'audienceType' | 'notifType'>): {
  all: boolean;
  system: boolean;
} {
  return { all: s.audienceType === 'ALL', system: s.notifType === 'SYSTEM' };
}

// ---------- taslak ----------

export function saveDraft(s: ComposeState): void {
  // Kullanıcı e-postaları taslakta tutulur (yalnızca bu tarayıcıda); gönderimde kullanılmaz.
  writeStorage('local', DRAFT_KEY, JSON.stringify(s));
}
export function clearDraft(): void {
  removeStorage('local', DRAFT_KEY);
}

function str(v: unknown, fallback = ''): string {
  return typeof v === 'string' ? v : fallback;
}

/** Bozuk/eksik taslağı tolere eder; alan alan doğrular. */
export function loadDraft(): ComposeState | null {
  const raw = readStorage('local', DRAFT_KEY);
  if (!raw) return null;
  try {
    const o = JSON.parse(raw) as Record<string, unknown>;
    if (!o || typeof o !== 'object') return null;
    const base = emptyState();
    const c = (o.contents ?? {}) as Record<string, Record<string, unknown> | undefined>;
    const contents = { ...base.contents };
    for (const l of LANGS) {
      contents[l] = { title: str(c[l]?.title), body: str(c[l]?.body) };
    }
    const users = Array.isArray(o.users)
      ? (o.users as unknown[])
          .filter((u): u is Record<string, unknown> => !!u && typeof u === 'object')
          .map((u) => ({ id: Number(u.id), displayName: str(u.displayName), email: str(u.email) }))
          .filter((u) => Number.isInteger(u.id) && u.id > 0)
          .slice(0, MAX_USERS)
      : [];
    const pick = <T extends string>(v: unknown, all: readonly T[], d: T): T =>
      typeof v === 'string' && (all as readonly string[]).includes(v) ? (v as T) : d;
    return {
      audienceType: pick(o.audienceType, AUDIENCE_TYPES, base.audienceType),
      department: str(o.department),
      classYear: str(o.classYear),
      users,
      contents,
      notifType: pick(o.notifType, NOTIF_TYPES, base.notifType),
      targetType: pick(o.targetType, TARGET_TYPES, base.targetType),
      targetValue: str(o.targetValue),
      scheduleMode: o.scheduleMode === 'later' ? 'later' : 'now',
      scheduledLocal: str(o.scheduledLocal),
    };
  } catch {
    return null;
  }
}

/** Taslakta hiç içerik/seçim var mı ("devam et" bildirimi için). */
export function isDraftEmpty(s: ComposeState): boolean {
  return LANGS.every((l) => !s.contents[l].title && !s.contents[l].body) && s.users.length === 0 && !s.department;
}

// ---------- kampanya listesi yardımcıları ----------

/** Yenileme gerektiren durumlar */
export function isLive(status: string): boolean {
  return status === 'SENDING' || status === 'SCHEDULED';
}
