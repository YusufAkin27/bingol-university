import type { Lang, Role, UserListParams, UserStatus } from '../../../api/types';

export const SORT_KEYS = ['createdAt', 'lastSeenAt', 'displayName'] as const;
export type SortKey = (typeof SORT_KEYS)[number];
export const DEFAULT_SORT = 'createdAt,desc';
export const PAGE_SIZE = 20;

const STATUSES: UserStatus[] = ['ACTIVE', 'SUSPENDED', 'DELETED'];
const ROLES: Role[] = ['USER', 'ADMIN'];
const LANGS: Lang[] = ['tr', 'en', 'ar'];

/** URL'de tutulan kullanıcı listesi durumu (hepsi metin; boş = filtre yok). */
export interface UserFilters {
  q: string;
  status: UserStatus | '';
  role: Role | '';
  faculty: string;
  department: string;
  classYear: '' | '1' | '2' | '3' | '4';
  language: Lang | '';
  verified: '' | 'true' | 'false';
  sort: string;
  page: number;
}

export const EMPTY_FILTERS: UserFilters = {
  q: '',
  status: '',
  role: '',
  faculty: '',
  department: '',
  classYear: '',
  language: '',
  verified: '',
  sort: DEFAULT_SORT,
  page: 0,
};

function oneOf<T extends string>(v: string | null, allowed: readonly T[]): T | '' {
  return v && (allowed as readonly string[]).includes(v) ? (v as T) : '';
}

export function parseSort(v: string | null): string {
  if (!v) return DEFAULT_SORT;
  const [key, dir] = v.split(',');
  if (!(SORT_KEYS as readonly string[]).includes(key)) return DEFAULT_SORT;
  return `${key},${dir === 'asc' ? 'asc' : 'desc'}`;
}

export function parseUserFilters(sp: URLSearchParams): UserFilters {
  const page = Number.parseInt(sp.get('page') ?? '0', 10);
  return {
    q: sp.get('q') ?? '',
    status: oneOf(sp.get('status'), STATUSES),
    role: oneOf(sp.get('role'), ROLES),
    faculty: sp.get('faculty') ?? '',
    department: sp.get('department') ?? '',
    classYear: oneOf(sp.get('classYear'), ['1', '2', '3', '4'] as const),
    language: oneOf(sp.get('language'), LANGS),
    verified: oneOf(sp.get('verified'), ['true', 'false'] as const),
    sort: parseSort(sp.get('sort')),
    page: Number.isFinite(page) && page > 0 ? page : 0,
  };
}

/** Varsayılan olmayan değerleri paylaşılabilir bağlantı için URL'ye yazar. */
export function filtersToSearch(f: UserFilters): URLSearchParams {
  const sp = new URLSearchParams();
  const put = (k: string, v: string) => v && sp.set(k, v);
  put('q', f.q);
  put('status', f.status);
  put('role', f.role);
  put('faculty', f.faculty);
  put('department', f.department);
  put('classYear', f.classYear);
  put('language', f.language);
  put('verified', f.verified);
  if (f.sort !== DEFAULT_SORT) sp.set('sort', f.sort);
  if (f.page > 0) sp.set('page', String(f.page));
  return sp;
}

/** Liste ve CSV uçları için API parametreleri (boşlar atılır). */
export function filtersToApi(f: UserFilters): UserListParams {
  const p: UserListParams = { sort: f.sort };
  if (f.q) p.q = f.q;
  if (f.status) p.status = f.status;
  if (f.role) p.role = f.role;
  if (f.faculty) p.faculty = f.faculty;
  if (f.department) p.department = f.department;
  if (f.classYear) p.classYear = Number(f.classYear);
  if (f.language) p.language = f.language;
  if (f.verified) p.verified = f.verified === 'true';
  return p;
}

export function activeFilterCount(f: UserFilters): number {
  return [f.status, f.role, f.faculty, f.department, f.classYear, f.language, f.verified].filter(Boolean)
    .length;
}

/** Blob'u tarayıcıda dosya olarak indirir. */
export function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
