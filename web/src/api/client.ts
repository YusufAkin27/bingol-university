import { paths } from '../paths';
import { getCurrentLang } from '../i18n/lang';
import { clearTokens, getAccessToken, getRefreshToken, setTokens } from '../auth/tokens';
import type { ApiErrorBody, TokenResponse } from './types';

/** API hatası: gövde `{code,message}` ise ikisi de taşınır; ağ hatasında status 0, code NETWORK_ERROR. */
export class ApiError extends Error {
  readonly status: number;
  readonly code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
  }
}

export function isApiError(e: unknown): e is ApiError {
  return e instanceof ApiError;
}

export type QueryValue = string | number | boolean | null | undefined;
export type Query = Record<string, QueryValue>;

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  query?: Query;
  body?: unknown;
  signal?: AbortSignal;
  /** false: Bearer eklenmez ve 401'de refresh denenmez (giriş, herkese açık uçlar). Varsayılan true. */
  auth?: boolean;
}

const BASE = ((import.meta.env.VITE_API_BASE as string | undefined) ?? '/api').replace(/\/+$/, '');

export function buildUrl(path: string, query?: Query): string {
  const qs = new URLSearchParams();
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      if (v !== undefined && v !== null && v !== '') qs.append(k, String(v));
    }
  }
  const s = qs.toString();
  return `${BASE}${path.startsWith('/') ? path : `/${path}`}${s ? `?${s}` : ''}`;
}

// ---------- oturum sonu ----------
let unauthorizedHandler: () => void = () => {
  if (typeof window !== 'undefined' && !window.location.pathname.startsWith(paths.admin.login)) {
    window.location.assign(paths.admin.login);
  }
};

/** AuthProvider, oturum kapanınca router ile yönlendirmek için kendi işleyicisini kaydeder. */
export function setUnauthorizedHandler(fn: (() => void) | null): void {
  unauthorizedHandler = fn ?? (() => undefined);
}

function expireSession(): void {
  clearTokens();
  unauthorizedHandler();
}

// ---------- düşük seviye ----------
async function send(path: string, opts: RequestOptions, token: string | null): Promise<Response> {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'Accept-Language': getCurrentLang(),
  };
  const isForm = typeof FormData !== 'undefined' && opts.body instanceof FormData;
  // FormData'da Content-Type'ı tarayıcı sınır (boundary) ile kendisi koyar.
  if (opts.body !== undefined && !isForm) headers['Content-Type'] = 'application/json';
  if (token && opts.auth !== false) headers.Authorization = `Bearer ${token}`;
  try {
    return await fetch(buildUrl(path, opts.query), {
      method: opts.method ?? 'GET',
      headers,
      body: opts.body === undefined ? undefined : isForm ? (opts.body as FormData) : JSON.stringify(opts.body),
      signal: opts.signal,
    });
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw e;
    throw new ApiError(0, 'NETWORK_ERROR', 'Network error');
  }
}

async function toError(res: Response): Promise<ApiError> {
  let body: Partial<ApiErrorBody> | null = null;
  try {
    body = (await res.json()) as Partial<ApiErrorBody>;
  } catch {
    body = null;
  }
  if (body && typeof body.code === 'string') {
    return new ApiError(res.status, body.code, typeof body.message === 'string' ? body.message : body.code);
  }
  const code = res.status >= 500 ? 'SERVER_ERROR' : `HTTP_${res.status}`;
  return new ApiError(res.status, code, res.statusText || code);
}

// ---------- tek-uçuş refresh ----------
// Refresh token tek kullanımlıktır: eşzamanlı 401'lerde yalnızca TEK /auth/refresh çağrısı yapılır,
// diğer istekler aynı sözü bekler. İkinci bir çağrı yarışı kaybedip oturumu düşürürdü.
let refreshInFlight: Promise<string> | null = null;

export function refreshAccessToken(): Promise<string> {
  if (!refreshInFlight) {
    refreshInFlight = doRefresh().finally(() => {
      refreshInFlight = null;
    });
  }
  return refreshInFlight;
}

async function doRefresh(): Promise<string> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) throw new ApiError(401, 'UNAUTHORIZED', 'No refresh token');
  const res = await send('/auth/refresh', { method: 'POST', body: { refreshToken }, auth: false }, null);
  if (!res.ok) throw await toError(res);
  const tokens = (await res.json()) as TokenResponse;
  setTokens(tokens.accessToken, tokens.refreshToken);
  return tokens.accessToken;
}

async function execute(path: string, opts: RequestOptions): Promise<Response> {
  let res = await send(path, opts, getAccessToken());
  if (res.status === 401 && opts.auth !== false) {
    let fresh: string;
    try {
      fresh = await refreshAccessToken();
    } catch (e) {
      // Ağ/5xx: geçici hata, oturumu düşürme. Sunucu reddettiyse (4xx) oturum bitmiştir.
      if (e instanceof ApiError && (e.status === 0 || e.status >= 500)) throw e;
      expireSession();
      throw await toError(res);
    }
    res = await send(path, opts, fresh);
    if (res.status === 401) {
      expireSession();
    }
  }
  if (!res.ok) throw await toError(res);
  return res;
}

// ---------- genel API ----------
export async function apiFetch<T = void>(path: string, opts: RequestOptions = {}): Promise<T> {
  const res = await execute(path, opts);
  if (res.status === 204) return undefined as T;
  const text = await res.text();
  if (!text) return undefined as T;
  try {
    return JSON.parse(text) as T;
  } catch {
    throw new ApiError(res.status, 'INVALID_RESPONSE', 'Invalid JSON response');
  }
}

/** CSV vb. dosya indirmeleri için (Authorization başlığı gerektiğinden `<a href>` yetmez). */
export async function apiBlob(path: string, opts: RequestOptions = {}): Promise<Blob> {
  const res = await execute(path, opts);
  return res.blob();
}

export const api = {
  get: <T>(path: string, query?: Query, signal?: AbortSignal) => apiFetch<T>(path, { query, signal }),
  post: <T = void>(path: string, body?: unknown) =>
    apiFetch<T>(path, { method: 'POST', body: body ?? undefined }),
  put: <T = void>(path: string, body?: unknown) =>
    apiFetch<T>(path, { method: 'PUT', body: body ?? undefined }),
  /** multipart/form-data yükleme (gövde FormData; başlık tarayıcıda kurulur). */
  putForm: <T = void>(path: string, form: FormData) => apiFetch<T>(path, { method: 'PUT', body: form }),
  patch: <T = void>(path: string, body?: unknown) =>
    apiFetch<T>(path, { method: 'PATCH', body: body ?? undefined }),
  del: <T = void>(path: string) => apiFetch<T>(path, { method: 'DELETE' }),
};

/** Herkese açık uçlar: Bearer yok, refresh yok. */
export const publicApi = {
  get: <T>(path: string, query?: Query, signal?: AbortSignal) =>
    apiFetch<T>(path, { query, signal, auth: false }),
  post: <T = void>(path: string, body?: unknown) =>
    apiFetch<T>(path, { method: 'POST', body: body ?? undefined, auth: false }),
};
