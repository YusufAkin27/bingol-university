import type { AdminEventPatch, EventAction, EventStatusFilter } from '../../../api/adminEvents';
import type { EventJoinPolicy, EventView } from '../../../api/types';
import { localToIso, toLocalInput } from '../campaigns/lib';
export type EventTiming = 'past' | 'soon' | 'later';
export const SOON_HOURS = 48;

/** Başlangıcı geçmiş = 'past'; 48 saat içinde = 'soon'; aksi 'later'. */
export function eventTiming(startsAt: string, now: Date = new Date()): EventTiming {
  const start = new Date(startsAt).getTime();
  if (Number.isNaN(start)) return 'later';
  const diff = start - now.getTime();
  if (diff < 0) return 'past';
  return diff <= SOON_HOURS * 3600 * 1000 ? 'soon' : 'later';
}

/** Başlangıca kalan süreyi (saat/gün) yerel dilde yazar: "3 saat sonra". */
export function relativeStart(startsAt: string, locale: string, now: Date = new Date()): string {
  const diffMin = Math.round((new Date(startsAt).getTime() - now.getTime()) / 60000);
  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' });
  const abs = Math.abs(diffMin);
  if (abs < 60) return rtf.format(diffMin, 'minute');
  if (abs < 60 * 24) return rtf.format(Math.round(diffMin / 60), 'hour');
  return rtf.format(Math.round(diffMin / (60 * 24)), 'day');
}

export type EventScope = 'all' | 'club' | 'standalone';

interface Filterable {
  title: string;
  location: string | null;
  communityId: number | null;
  communityName: string | null;
  organizerName: string | null;
}

/** Yüklenen sayfalar üzerinde istemci tarafı süzgeç (backend durum dışında süzgeç sunmaz). */
export function filterEvents<T extends Filterable>(items: T[], scope: EventScope, q: string): T[] {
  const needle = q.trim().toLocaleLowerCase('tr');
  return items.filter((e) => {
    if (scope === 'club' && e.communityId == null) return false;
    if (scope === 'standalone' && e.communityId != null) return false;
    if (!needle) return true;
    return [e.title, e.location, e.communityName, e.organizerName].some((v) => (v ?? '').toLocaleLowerCase('tr').includes(needle));
  });
}

// ---------- yönetici moderasyonu ----------

export const REASON_MAX = 300;
/** Durum sekmeleri; ALL sunucuda tüm durumları getirir. */
export const EVENT_STATUS_TABS: EventStatusFilter[] = ['PENDING_REVIEW', 'ACTIVE', 'HIDDEN', 'REJECTED', 'CANCELLED', 'ALL'];
export type ReasonAction = 'hide' | 'unhide' | 'cancel' | 'delete';

export type ReasonError = 'REQUIRED' | 'TOO_LONG' | null;
/** hide/unhide/cancel/delete sebebi zorunlu ve ≤300 karakter. */
export function reasonError(reason: string): ReasonError {
  const r = reason.trim();
  if (!r) return 'REQUIRED';
  return r.length > REASON_MAX ? 'TOO_LONG' : null;
}

/** `allowedActions` sunucudan gelir; bilinmeyen/eksik ise düğme gösterilmez. */
export function allowed(actions: readonly string[] | undefined, a: EventAction): boolean {
  return !!actions && actions.includes(a);
}

export interface EditForm {
  title: string;
  description: string;
  /** datetime-local biçimi (yerel saat) */
  startsLocal: string;
  endsLocal: string;
  location: string;
  /** boş veya 0 = sınırsız */
  capacity: string;
  joinPolicy: EventJoinPolicy;
  reason: string;
}

export function formFromEvent(ev: EventView): EditForm {
  return {
    title: ev.title,
    description: ev.description ?? '',
    startsLocal: toLocalInput(new Date(ev.startsAt)),
    endsLocal: toLocalInput(new Date(ev.endsAt)),
    location: ev.location ?? '',
    capacity: ev.capacity == null ? '' : String(ev.capacity),
    joinPolicy: ev.joinPolicy ?? 'OPEN',
    reason: '',
  };
}

export type EditError = 'TITLE' | 'DESCRIPTION' | 'LOCATION' | 'DATES' | 'CAPACITY' | 'REASON';

function capacityOf(f: string): number | null {
  const v = f.trim();
  if (v === '') return 0;
  if (!/^\d+$/.test(v)) return null;
  const n = Number(v);
  return n <= 100000 ? n : null;
}

export function validateEdit(f: EditForm): EditError[] {
  const out: EditError[] = [];
  const title = f.title.trim();
  if (title.length < 3 || title.length > 150) out.push('TITLE');
  if (f.description.length > 2000) out.push('DESCRIPTION');
  if (f.location.length > 200) out.push('LOCATION');
  const s = localToIso(f.startsLocal);
  const e = localToIso(f.endsLocal);
  if (!s || !e || new Date(e).getTime() <= new Date(s).getTime()) out.push('DATES');
  if (capacityOf(f.capacity) === null) out.push('CAPACITY');
  if (f.reason.length > REASON_MAX) out.push('REASON');
  return out;
}

/** Yalnızca değişen alanları içeren PATCH gövdesi; hiçbir şey değişmediyse null. */
export function buildPatch(ev: EventView, f: EditForm): AdminEventPatch | null {
  const p: AdminEventPatch = {};
  if (f.title.trim() !== ev.title) p.title = f.title.trim();
  if (f.description !== (ev.description ?? '')) p.description = f.description;
  if (f.location !== (ev.location ?? '')) p.location = f.location;
  if (f.startsLocal !== toLocalInput(new Date(ev.startsAt))) p.startsAt = localToIso(f.startsLocal) ?? undefined;
  if (f.endsLocal !== toLocalInput(new Date(ev.endsAt))) p.endsAt = localToIso(f.endsLocal) ?? undefined;
  const cap = capacityOf(f.capacity);
  if (cap !== null && cap !== (ev.capacity ?? 0)) p.capacity = cap;
  if (f.joinPolicy !== (ev.joinPolicy ?? 'OPEN')) p.joinPolicy = f.joinPolicy;
  if (Object.keys(p).length === 0) return null;
  if (f.reason.trim()) p.reason = f.reason.trim();
  return p;
}

/** `yyyy-MM-dd` (yerel) -> gün başı/sonu anı (ISO UTC); geçersizse undefined. */
export function dayBoundIso(day: string, end: boolean): string | undefined {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return undefined;
  const d = new Date(`${day}T${end ? '23:59:59' : '00:00:00'}`);
  return Number.isNaN(d.getTime()) ? undefined : d.toISOString();
}
