import type {
  PollAudience,
  PollCreateBody,
  PollDetail,
  PollShowResults,
  PollState,
  PollType,
  PollUpdateBody,
} from '../../../api/adminPolls';
import type { Tone } from '../../../components/ui';

export const MIN_OPTIONS = 2;
export const MAX_OPTIONS = 12;
export const MAX_TITLE = 150;
export const MAX_DESCRIPTION = 1000;
export const MAX_OPTION_TEXT = 100;
export const MAX_AUDIENCE_TEXT = 120;
export const MAX_GRADE = 8;

export const POLL_TYPES: PollType[] = ['SINGLE', 'MULTI', 'RATING', 'RANKED'];
export const SHOW_RESULTS: PollShowResults[] = ['ALWAYS', 'AFTER_VOTE', 'AFTER_CLOSE'];

export interface PollFormState {
  title: string;
  description: string;
  type: PollType;
  options: string[];
  /** MULTI/RANKED için en fazla seçim; boş = tüm seçenekler. */
  maxChoices: string;
  anonymous: boolean;
  allowChangeVote: boolean;
  showResults: PollShowResults;
  notify: boolean;
  /** datetime-local değeri (yerel saat); boş = hemen. */
  opensAt: string;
  closesAt: string;
  faculty: string;
  department: string;
  grade: string;
  /** Taslak olarak kalsın (yayınlanmasın). */
  draft: boolean;
}

export const EMPTY_POLL_FORM: PollFormState = {
  title: '',
  description: '',
  type: 'SINGLE',
  options: ['', ''],
  maxChoices: '',
  anonymous: true,
  allowChangeVote: true,
  showResults: 'ALWAYS',
  notify: false,
  opensAt: '',
  closesAt: '',
  faculty: '',
  department: '',
  grade: '',
  draft: false,
};

/** ISO -> datetime-local değeri (yerel saat). */
export function toLocalInput(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

export function formFromDetail(p: PollDetail): PollFormState {
  return {
    title: p.title,
    description: p.description ?? '',
    type: p.type,
    options: p.type === 'RATING' ? ['', ''] : p.options.map((o) => o.text),
    maxChoices: p.type === 'MULTI' || p.type === 'RANKED' ? String(p.maxChoices) : '',
    anonymous: p.anonymous,
    allowChangeVote: p.allowChangeVote,
    showResults: p.showResults,
    notify: p.notify,
    opensAt: toLocalInput(p.opensAt),
    closesAt: toLocalInput(p.closesAt),
    faculty: p.audience?.faculty ?? '',
    department: p.audience?.department ?? '',
    grade: p.audience?.grade ?? '',
    draft: p.status === 'DRAFT',
  };
}

export type PollFormError =
  | 'title'
  | 'description'
  | 'options'
  | 'optionEmpty'
  | 'optionLong'
  | 'optionDup'
  | 'maxChoices'
  | 'period'
  | 'closesPast'
  | 'audience';

/** Form doğrulaması; ilk hatanın kodunu döner (yoksa null). Kurallar backend `PollService` ile aynıdır. */
export function validatePollForm(f: PollFormState, now: Date = new Date()): PollFormError | null {
  const title = f.title.trim();
  if (!title || title.length > MAX_TITLE) return 'title';
  if (f.description.trim().length > MAX_DESCRIPTION) return 'description';
  if (f.type !== 'RATING') {
    const opts = f.options.map((o) => o.trim());
    if (opts.length < MIN_OPTIONS || opts.length > MAX_OPTIONS) return 'options';
    if (opts.some((o) => !o)) return 'optionEmpty';
    if (opts.some((o) => o.length > MAX_OPTION_TEXT)) return 'optionLong';
    if (new Set(opts.map((o) => o.toLowerCase())).size !== opts.length) return 'optionDup';
    if ((f.type === 'MULTI' || f.type === 'RANKED') && f.maxChoices.trim() !== '') {
      const n = Number(f.maxChoices);
      if (!Number.isInteger(n) || n < 1 || n > opts.length) return 'maxChoices';
    }
  }
  if (f.opensAt && f.closesAt && new Date(f.closesAt) <= new Date(f.opensAt)) return 'period';
  if (f.closesAt && new Date(f.closesAt) <= now) return 'closesPast';
  if (
    f.faculty.trim().length > MAX_AUDIENCE_TEXT ||
    f.department.trim().length > MAX_AUDIENCE_TEXT ||
    f.grade.trim().length > MAX_GRADE
  ) {
    return 'audience';
  }
  return null;
}

const iso = (v: string): string | null => (v ? new Date(v).toISOString() : null);
const nullIfBlank = (v: string): string | null => (v.trim() === '' ? null : v.trim());

function audienceOf(f: PollFormState): PollAudience {
  return { faculty: nullIfBlank(f.faculty), department: nullIfBlank(f.department), grade: nullIfBlank(f.grade) };
}

function maxChoicesOf(f: PollFormState): number | null {
  return (f.type === 'MULTI' || f.type === 'RANKED') && f.maxChoices.trim() !== '' ? Number(f.maxChoices) : null;
}

/** POST /api/polls gövdesi (kapsam her zaman GLOBAL: kulüp anketini kulüp yöneticisi, menü anketini sistem açar). */
export function toCreateBody(f: PollFormState): PollCreateBody {
  const a = audienceOf(f);
  const hasAudience = a.faculty !== null || a.department !== null || a.grade !== null;
  return {
    title: f.title.trim(),
    description: nullIfBlank(f.description),
    type: f.type,
    scope: 'GLOBAL',
    options: f.type === 'RATING' ? [] : f.options.map((o) => o.trim()),
    maxChoices: maxChoicesOf(f),
    anonymous: f.anonymous,
    allowChangeVote: f.allowChangeVote,
    showResults: f.showResults,
    notify: f.notify,
    opensAt: iso(f.opensAt),
    closesAt: iso(f.closesAt),
    audience: hasAudience ? a : null,
    draft: f.draft,
  };
}

/**
 * PATCH /api/polls/{id} gövdesi: yalnız DEĞİŞEN alanlar gider. Böylece oy alınmış ankette yapısal alanlar (tür,
 * seçenekler, zaman damgası) yanlışlıkla "değişti" sayılıp 409 `POLL_LOCKED` üretmez (datetime-local saniyeyi keser).
 */
export function toUpdateBody(initial: PollFormState, f: PollFormState): PollUpdateBody {
  const body: PollUpdateBody = {};
  if (f.title.trim() !== initial.title.trim()) body.title = f.title.trim();
  if (f.description.trim() !== initial.description.trim()) body.description = f.description.trim();
  if (f.type !== initial.type) body.type = f.type;
  const optsChanged =
    f.type !== 'RATING' &&
    JSON.stringify(f.options.map((o) => o.trim())) !== JSON.stringify(initial.options.map((o) => o.trim()));
  if (optsChanged || (f.type !== 'RATING' && f.type !== initial.type)) body.options = f.options.map((o) => o.trim());
  if (f.maxChoices !== initial.maxChoices) {
    const m = maxChoicesOf(f);
    if (m !== null) body.maxChoices = m;
  }
  if (f.anonymous !== initial.anonymous) body.anonymous = f.anonymous;
  if (f.allowChangeVote !== initial.allowChangeVote) body.allowChangeVote = f.allowChangeVote;
  if (f.showResults !== initial.showResults) body.showResults = f.showResults;
  if (f.notify !== initial.notify) body.notify = f.notify;
  if (f.opensAt !== initial.opensAt && f.opensAt) body.opensAt = iso(f.opensAt);
  // closesAt: boş metin kapanışı kaldırır (UpdateRequest sözleşmesi).
  if (f.closesAt !== initial.closesAt) body.closesAt = f.closesAt ? iso(f.closesAt) : '';
  if (
    f.faculty.trim() !== initial.faculty.trim() ||
    f.department.trim() !== initial.department.trim() ||
    f.grade.trim() !== initial.grade.trim()
  ) {
    body.audience = audienceOf(f);
  }
  if (initial.draft && !f.draft) body.draft = false;
  return body;
}

/** Görünüm durumuna göre rozet rengi. */
export function stateTone(s: PollState): Tone {
  switch (s) {
    case 'OPEN':
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

/** Düzenleme yalnız bitmemiş (taslak/zamanlanmış/açık) anketlerde; yönetici her ankete yetkilidir. */
export const canEdit = (p: Pick<PollDetail, 'state' | 'canManage'>) =>
  p.canManage && (p.state === 'DRAFT' || p.state === 'SCHEDULED' || p.state === 'OPEN');
export const canClose = (state: PollState) => state === 'OPEN';
export const canCancel = (state: PollState) => state === 'DRAFT' || state === 'SCHEDULED' || state === 'OPEN';

/** Oy alınmış açık ankette yapı (tür, seçenekler, gizlilik, hedef kitle, açılış) kilitlidir (409 POLL_LOCKED). */
export const isStructureLocked = (p: Pick<PollDetail, 'status' | 'turnout' | 'totalVotes'>) =>
  p.status === 'OPEN' && (p.turnout?.voted ?? p.totalVotes ?? 0) > 0;

/** Yüzdeyi 0..100 aralığına sıkıştırır (çubuk genişliği için). */
export const clampPercent = (v: number) => Math.min(100, Math.max(0, Number.isFinite(v) ? v : 0));
