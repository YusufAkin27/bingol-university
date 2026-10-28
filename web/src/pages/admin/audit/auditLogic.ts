// Denetim ekranı mantığı (W-P02): URL <-> süzgeç, işlem adını insanca yazma, hedef bağlantıları.
import { paths } from '../../../paths';

export const AUDIT_PAGE_SIZE = 20;
export const AUDIT_METHODS = ['POST', 'PUT', 'PATCH', 'DELETE', 'GET'] as const;
/** Sunucu `status` süzgeci: tam kod ya da sınıf (4xx). */
export const AUDIT_STATUS_OPTIONS = ['2xx', '4xx', '401', '403', '404', '409', '429', '5xx'] as const;
/** Yoldan çıkarılan/servisin bildirdiği başlıca hedef türleri (süzgeç listesi; başka tür de URL ile verilebilir). */
export const AUDIT_TARGET_TYPES = [
  'USER',
  'EVENT',
  'POST',
  'COMMUNITY',
  'REPORT',
  'CAMPAIGN',
  'POLL',
  'TICKET',
  'SETTING',
  'LEGAL',
  'AUDIT',
] as const;
/** CSV dışa aktarmanın sunucu üst sınırı. */
export const AUDIT_CSV_MAX_ROWS = 50000;

export interface AuditFilters {
  adminId?: number;
  method: string;
  status: string;
  q: string;
  from: string;
  to: string;
  targetType: string;
  targetId: string;
  page: number;
}

export const EMPTY_AUDIT_FILTERS: AuditFilters = {
  method: '',
  status: '',
  q: '',
  from: '',
  to: '',
  targetType: '',
  targetId: '',
  page: 0,
};

const DAY = /^\d{4}-\d{2}-\d{2}$/;
const STATUS = /^([1-5]\d\d|[1-5]xx)$/i;
const TYPE = /^[A-Za-z][A-Za-z0-9_]{0,31}$/;

/** URL sorgusundan süzgeçleri okur; geçersiz değerler sessizce atılır. */
export function filtersFromParams(sp: URLSearchParams): AuditFilters {
  const page = Number.parseInt(sp.get('page') ?? '0', 10);
  const adminId = Number.parseInt(sp.get('adminId') ?? '', 10);
  const method = (sp.get('method') ?? '').toUpperCase();
  const status = sp.get('status') ?? '';
  const from = sp.get('from') ?? '';
  const to = sp.get('to') ?? '';
  const targetType = sp.get('targetType') ?? '';
  return {
    adminId: Number.isFinite(adminId) ? adminId : undefined,
    method: (AUDIT_METHODS as readonly string[]).includes(method) ? method : '',
    status: STATUS.test(status) ? status.toLowerCase() : '',
    q: sp.get('q') ?? '',
    from: DAY.test(from) ? from : '',
    to: DAY.test(to) ? to : '',
    targetType: TYPE.test(targetType) ? targetType.toUpperCase() : '',
    targetId: (sp.get('targetId') ?? '').slice(0, 64),
    page: Number.isFinite(page) && page > 0 ? page : 0,
  };
}

/** Süzgeçleri URL sorgusuna yazar (boşlar atılır; sayfa 0 yazılmaz). */
export function filtersToParams(f: AuditFilters): URLSearchParams {
  const out = new URLSearchParams();
  if (f.adminId !== undefined) out.set('adminId', String(f.adminId));
  if (f.method) out.set('method', f.method);
  if (f.status) out.set('status', f.status);
  if (f.q) out.set('q', f.q);
  if (f.from) out.set('from', f.from);
  if (f.to) out.set('to', f.to);
  if (f.targetType) out.set('targetType', f.targetType);
  if (f.targetId) out.set('targetId', f.targetId);
  if (f.page > 0) out.set('page', String(f.page));
  return out;
}

/** Etkin süzgeç sayısı (sayfa hariç). */
export function activeFilterCount(f: AuditFilters): number {
  return [f.adminId !== undefined, f.method, f.status, f.q, f.from, f.to, f.targetType, f.targetId].filter(Boolean).length;
}

/** API sorgusu (sayfa/boyut çağıranda eklenir). */
export function filtersToQuery(f: AuditFilters) {
  return {
    adminId: f.adminId,
    method: f.method || undefined,
    status: f.status || undefined,
    q: f.q || undefined,
    from: f.from || undefined,
    to: f.to || undefined,
    targetType: f.targetType || undefined,
    targetId: f.targetId || undefined,
  };
}

// ---------- işlem adı ----------

/** Yolu kimliksiz parçalara ayırır: sayı, e-posta, özet (hex) ve tarih parçaları atılır. */
export function pathSegments(path: string): string[] {
  const clean = path.split('?')[0].replace(/^\/api\/admin\/?/, '');
  return clean
    .split('/')
    .filter(Boolean)
    .filter((s) => !/^\d+$/.test(s) && !/[@%]/.test(s) && !/^[0-9a-f]{16,}$/i.test(s) && !DAY.test(s));
}

/** Çeviri anahtarı adayları: en özelinden (tüm parçalar) en genele (yalnız ilk parça). */
export function actionKeyCandidates(method: string, path: string): string[] {
  const segs = pathSegments(path);
  const out: string[] = [];
  for (let n = segs.length; n >= 1; n--) out.push(`admin.wp02.audit.act.${method.toUpperCase()}.${segs.slice(0, n).join('.')}`);
  return out;
}

export interface ActionText {
  /** Çevrilmiş ad ("Kullanıcı rolü değiştirildi") ya da bilinmiyorsa "Fiil · kaynak". */
  label: string;
  known: boolean;
}

/** `td`: I18n.td; bilinen işlemi insanca yazar, bilinmeyeni "Değişiklik · users/role" biçiminde. */
export function describeAction(
  td: (key: string, fallback?: string) => string,
  method: string,
  path: string,
): ActionText {
  for (const key of actionKeyCandidates(method, path)) {
    const text = td(key, '');
    if (text) return { label: text, known: true };
  }
  const verb = td(`admin.wp02.audit.verb.${method.toUpperCase()}`, method);
  const res = pathSegments(path).join('/');
  return { label: res ? `${verb} · ${res}` : verb, known: false };
}

// ---------- hedef bağlantıları ----------

const NUMERIC = /^\d+$/;

/** Hedefe giden yönetim sayfası (yoksa null): USER, EVENT, POST, REPORT, CAMPAIGN, COMMUNITY, TICKET, POLL. */
export function targetHref(type: string | null | undefined, id: string | null | undefined): string | null {
  if (!type) return null;
  const hasId = !!id && NUMERIC.test(id);
  switch (type.toUpperCase()) {
    case 'USER':
      return hasId ? paths.admin.user(id as string) : null;
    case 'EVENT':
      return hasId ? `${paths.admin.events}?open=${id}` : paths.admin.events;
    case 'POST':
      return hasId ? `${paths.admin.posts}?open=${id}` : paths.admin.posts;
    case 'REPORT':
      return paths.admin.reports;
    case 'CAMPAIGN':
      return paths.admin.campaigns;
    case 'COMMUNITY':
      return paths.admin.communities;
    case 'TICKET':
      return hasId ? paths.admin.ticket(id as string) : paths.admin.tickets;
    case 'POLL':
      return paths.admin.polls;
    default:
      return null;
  }
}

/** Bir hedefin tüm kayıtlarını gösteren denetim bağlantısı. */
export function auditForTargetHref(type: string, id: string): string {
  const p = new URLSearchParams({ targetType: type.toUpperCase(), targetId: id });
  return `${paths.admin.audit}?${p.toString()}`;
}

/** Sebep/özet gibi uzun metni tabloda kısaltır (tam metin ayrıntı çekmecesinde). */
export function clip(text: string | null | undefined, max = 60): string {
  const s = (text ?? '').trim();
  return s.length > max ? `${s.slice(0, max - 1)}…` : s;
}
