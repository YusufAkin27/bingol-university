import type { PollInput, PollStatus, PollType, AdminPoll, PollScope, PollAudience } from '../../../api/adminPolls';
import type { Tone } from '../../../components/ui';

export const MIN_OPTIONS = 2;
export const MAX_OPTIONS = 12;
/** Puanlama (RATING) anketinde sabit 1-5 secenek uretilir. */
export const RATING_OPTIONS = ['1', '2', '3', '4', '5'];

export interface PollFormState {
  title: string;
  type: PollType;
  scope: PollScope;
  scopeId: string;
  anonymous: boolean;
  audience: PollAudience;
  startsAt: string;
  endsAt: string;
  options: string[];
}

export const EMPTY_POLL_FORM: PollFormState = {
  title: '',
  type: 'SINGLE',
  scope: 'GENERAL',
  scopeId: '',
  anonymous: false,
  audience: 'ALL',
  startsAt: '',
  endsAt: '',
  options: ['', ''],
};

/** ISO -> datetime-local degeri (yerel saat). */
export function toLocalInput(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

export function formFromPoll(p: AdminPoll): PollFormState {
  return {
    title: p.title,
    type: p.type,
    scope: p.scope,
    scopeId: p.scopeId === null ? '' : String(p.scopeId),
    anonymous: p.anonymous,
    audience: p.audience,
    startsAt: toLocalInput(p.startsAt),
    endsAt: toLocalInput(p.endsAt),
    options: p.type === 'RATING' ? ['', ''] : p.options.map((o) => o.text),
  };
}

export type PollFormError = 'title' | 'options' | 'optionEmpty' | 'optionDup' | 'period' | 'scopeId';

/** Form dogrulamasi; ilk hatanin kodunu doner (yoksa null). */
export function validatePollForm(f: PollFormState): PollFormError | null {
  if (!f.title.trim()) return 'title';
  if ((f.scope === 'COMMUNITY' || f.scope === 'EVENT') && !/^\d+$/.test(f.scopeId.trim())) return 'scopeId';
  if (f.type !== 'RATING') {
    const opts = f.options.map((o) => o.trim());
    if (opts.length < MIN_OPTIONS || opts.length > MAX_OPTIONS) return 'options';
    if (opts.some((o) => !o)) return 'optionEmpty';
    if (new Set(opts.map((o) => o.toLowerCase())).size !== opts.length) return 'optionDup';
  }
  if (f.startsAt && f.endsAt && new Date(f.endsAt) <= new Date(f.startsAt)) return 'period';
  return null;
}

export function toPollInput(f: PollFormState): PollInput {
  const iso = (v: string) => (v ? new Date(v).toISOString() : null);
  return {
    title: f.title.trim(),
    type: f.type,
    scope: f.scope,
    scopeId: f.scope === 'COMMUNITY' || f.scope === 'EVENT' ? Number(f.scopeId) : null,
    anonymous: f.anonymous,
    audience: f.audience,
    startsAt: iso(f.startsAt),
    endsAt: iso(f.endsAt),
    options: f.type === 'RATING' ? RATING_OPTIONS : f.options.map((o) => o.trim()),
  };
}

export function statusTone(s: PollStatus): Tone {
  switch (s) {
    case 'ACTIVE':
      return 'success';
    case 'SCHEDULED':
      return 'info';
    case 'CLOSED':
      return 'neutral';
    case 'CANCELLED':
      return 'danger';
    default:
      return 'warning';
  }
}

/** Duzenleme yalniz oy gelmeden ve bitmemis anketlerde. */
export const canEdit = (p: AdminPoll) => (p.status === 'DRAFT' || p.status === 'SCHEDULED') && p.voteCount === 0;
export const canClose = (p: AdminPoll) => p.status === 'ACTIVE';
export const canCancel = (p: AdminPoll) => p.status === 'DRAFT' || p.status === 'SCHEDULED' || p.status === 'ACTIVE';
