// Mail şablon/kampanya ekranlarının saf mantığı (test edilebilir): form modeli, doğrulama, kitle kurma, hata çevirisi.
import { isApiError } from '../../../api/client';
import {
  MAIL_LANGS,
  type AudienceFilter,
  type CampaignStatus,
  type MailAudience,
  type MailContent,
  type MailLang,
  type TemplateRequest,
  type TemplateStatus,
  type TemplateView,
} from '../../../api/adminMail';
import type { Tone } from '../../../components/ui';
import type { I18n } from '../../../i18n/I18nProvider';
import { errorMessage } from '../../../lib/errors';

export const MAX_SUBJECT = 200;
export const MAX_HTML = 100000;
export const MAX_LIST = 2000;
export const MAX_SCHEDULE_DAYS = 90;

export interface LangForm {
  subject: string;
  html: string;
  text: string;
}
export interface TemplateForm {
  name: string;
  description: string;
  tr: LangForm;
  en: LangForm;
  ar: LangForm;
}

const emptyLang = (): LangForm => ({ subject: '', html: '', text: '' });
export const emptyForm = (): TemplateForm => ({
  name: '',
  description: '',
  tr: emptyLang(),
  en: emptyLang(),
  ar: emptyLang(),
});

const fromContent = (c: MailContent | null | undefined): LangForm =>
  c ? { subject: c.subject ?? '', html: c.html ?? '', text: c.text ?? '' } : emptyLang();

export function formFromView(v: TemplateView): TemplateForm {
  return {
    name: v.name,
    description: v.description ?? '',
    tr: fromContent(v.tr),
    en: fromContent(v.en),
    ar: fromContent(v.ar),
  };
}

/** Dilin içeriği tamamen boş mu (boşsa o dil gönderilmez; alıcılar Türkçe alır). */
export const isLangEmpty = (c: LangForm) => !c.subject.trim() && !c.html.trim() && !c.text.trim();

const toContent = (c: LangForm): MailContent => ({
  subject: c.subject.trim(),
  html: c.html,
  text: c.text.trim() ? c.text : null,
});

export function toRequest(f: TemplateForm): TemplateRequest {
  return {
    name: f.name.trim(),
    description: f.description.trim(),
    tr: toContent(f.tr),
    en: isLangEmpty(f.en) ? null : toContent(f.en),
    ar: isLangEmpty(f.ar) ? null : toContent(f.ar),
  };
}

export interface FormErrors {
  name?: 'required';
  /** dil -> alan -> hata kodu */
  lang: Partial<Record<MailLang, { subject?: 'required' | 'tooLong'; html?: 'required' | 'tooLong' }>>;
}

/** İstemci tarafı doğrulama (sunucu yine kontrol eder). Boş en/ar atlanır; doluysa konu+HTML şart. */
export function validateForm(f: TemplateForm): FormErrors {
  const e: FormErrors = { lang: {} };
  if (!f.name.trim()) e.name = 'required';
  for (const l of MAIL_LANGS) {
    const c = f[l];
    if (l !== 'tr' && isLangEmpty(c)) continue;
    const le: NonNullable<FormErrors['lang'][MailLang]> = {};
    if (!c.subject.trim()) le.subject = 'required';
    else if (c.subject.trim().length > MAX_SUBJECT) le.subject = 'tooLong';
    if (!c.html.trim()) le.html = 'required';
    else if (c.html.length > MAX_HTML) le.html = 'tooLong';
    if (le.subject || le.html) e.lang[l] = le;
  }
  return e;
}
export const hasErrors = (e: FormErrors) => !!e.name || Object.keys(e.lang).length > 0;

/** İmleç konumuna metin ekler; yeni değeri ve yeni imleç konumunu döner. */
export function insertAt(value: string, start: number, end: number, token: string) {
  const s = Math.max(0, Math.min(start, value.length));
  const eIdx = Math.max(s, Math.min(end, value.length));
  return { value: value.slice(0, s) + token + value.slice(eIdx), caret: s + token.length };
}

export const templateTone = (s: TemplateStatus): Tone =>
  s === 'PUBLISHED' ? 'success' : s === 'ARCHIVED' ? 'neutral' : 'warning';

export const campaignTone = (s: CampaignStatus): Tone => {
  switch (s) {
    case 'DONE':
      return 'success';
    case 'SCHEDULED':
      return 'info';
    case 'SENDING':
    case 'PAUSED':
      return 'warning';
    case 'FAILED':
      return 'danger';
    default:
      return 'neutral';
  }
};

/** Gönderim sürerken (veya sürecekken) liste/ayrıntı yoklanır. */
export const isCampaignLive = (s: CampaignStatus) => s === 'SENDING' || s === 'SCHEDULED';

export interface EmailParse {
  valid: string[];
  invalid: string[];
  duplicates: number;
}
const EMAIL_RE = /^[^\s@,;]+@[^\s@,;]+\.[^\s@,;]+$/;

/** Yapıştırılan metni (satır/virgül/noktalı virgül/boşluk ayraçlı) e-posta listesine çevirir. */
export function parseEmails(text: string): EmailParse {
  const seen = new Set<string>();
  const valid: string[] = [];
  const invalid: string[] = [];
  let duplicates = 0;
  for (const raw of text.split(/[\s,;]+/)) {
    const v = raw.trim().toLowerCase();
    if (!v) continue;
    if (!EMAIL_RE.test(v)) {
      invalid.push(raw.trim());
      continue;
    }
    if (seen.has(v)) {
      duplicates++;
      continue;
    }
    seen.add(v);
    valid.push(v);
  }
  return { valid, invalid, duplicates };
}

type AudienceType = MailAudience['type'];

export interface AudienceState {
  type: AudienceType;
  faculty: string;
  department: string;
  classYear: string;
  role: '' | 'USER' | 'ADMIN';
  language: '' | MailLang;
  communityId: string;
  userIds: number[];
  emailsText: string;
}
export const emptyAudience = (): AudienceState => ({
  type: 'ALL',
  faculty: '',
  department: '',
  classYear: '',
  role: '',
  language: '',
  communityId: '',
  userIds: [],
  emailsText: '',
});

export function buildFilter(a: AudienceState): AudienceFilter {
  const f: AudienceFilter = {};
  if (a.faculty.trim()) f.faculty = a.faculty.trim();
  if (a.department.trim()) f.department = a.department.trim();
  if (a.classYear.trim() !== '' && Number.isFinite(Number(a.classYear))) f.classYear = Number(a.classYear);
  if (a.role) f.role = a.role;
  if (a.language) f.language = a.language;
  if (a.communityId.trim() !== '' && Number.isFinite(Number(a.communityId))) f.communityId = Number(a.communityId);
  return f;
}

export function buildAudience(a: AudienceState): MailAudience {
  switch (a.type) {
    case 'ALL':
      return { type: 'ALL' };
    case 'FILTER':
      return { type: 'FILTER', filter: buildFilter(a) };
    case 'USERS':
      return { type: 'USERS', userIds: a.userIds };
    case 'EMAILS':
      return { type: 'EMAILS', emails: parseEmails(a.emailsText).valid };
  }
}

/** Kitle tanımı geçerli mi (önizleme/sonraki adım için). */
export function audienceReady(a: AudienceState): boolean {
  switch (a.type) {
    case 'ALL':
      return true;
    case 'FILTER':
      return Object.keys(buildFilter(a)).length > 0;
    case 'USERS':
      return a.userIds.length > 0 && a.userIds.length <= MAX_LIST;
    case 'EMAILS': {
      const n = parseEmails(a.emailsText).valid.length;
      return n > 0 && n <= MAX_LIST;
    }
  }
}

/** `datetime-local` değeri -> ISO anı; geçmiş/90 günden ileri ise hata kodu. */
export function parseSchedule(
  local: string,
  now: Date = new Date(),
): { iso: string } | { error: 'required' | 'past' | 'tooFar' } {
  if (!local) return { error: 'required' };
  const d = new Date(local);
  if (Number.isNaN(d.getTime())) return { error: 'required' };
  if (d.getTime() <= now.getTime()) return { error: 'past' };
  if (d.getTime() > now.getTime() + MAX_SCHEDULE_DAYS * 86_400_000) return { error: 'tooFar' };
  return { iso: d.toISOString() };
}

/** Hata kodu -> çevrilmiş metin (`admin.mail.err.<KOD>`); 429 ve ağ hataları genel çeviriye düşer. */
export function mailErrorMessage(i18n: Pick<I18n, 't' | 'td'>, e: unknown): string {
  if (isApiError(e)) {
    // Doğrulama hatalarında sunucu mesajı hangi alan/değişkenin sorunlu olduğunu içerir (istek dilinde).
    if ((e.code === 'MAIL_TEMPLATE_INVALID' || e.code === 'MAIL_TEMPLATE_VARIABLE_UNKNOWN') && e.message && e.message !== e.code) {
      return `${i18n.td(`admin.mail.err.${e.code}`, '')}: ${e.message}`;
    }
    const own = i18n.td(`admin.mail.err.${e.code}`, '');
    if (own) return own;
    if (e.status === 429) return i18n.t('admin.mail.err.RATE_LIMITED');
  }
  return errorMessage(i18n, e);
}
