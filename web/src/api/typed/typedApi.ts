// Üretilmiş OpenAPI şemasına (api/generated/schema.d.ts) dayalı ince, tip güvenli sarmalayıcı.
// Mevcut `api/client.ts` fetch katmanını kullanır (token, refresh, hata modeli aynı); yeni küçük modüller bunu kullanır.
// Şemayı yenilemek için: `npm run gen:api` (docs/openapi.json -> schema.d.ts).
import { apiFetch } from '../client';
import type { Query } from '../client';
import type { paths } from '../generated/schema';

type Method = 'get' | 'post' | 'put' | 'patch' | 'delete';
type StripApi<P extends string> = P extends `/api${infer R}` ? R : P;

/** Verilen HTTP yöntemini tanımlayan (never olmayan) şema yolları. */
export type PathsWith<M extends Method> = {
  [P in keyof paths]: paths[P][M] extends never | undefined ? never : P;
}[keyof paths] &
  string;

type Op<P extends keyof paths, M extends Method> = NonNullable<paths[P][M]>;

/** 200/201 JSON gövdesi; yoksa void. */
export type ResponseOf<P extends keyof paths, M extends Method> =
  Op<P, M> extends { responses: infer R }
    ? R extends { 200: { content: { 'application/json': infer B } } }
      ? B
      : R extends { 201: { content: { 'application/json': infer B } } }
        ? B
        : void
    : void;

export type QueryOf<P extends keyof paths, M extends Method> =
  Op<P, M> extends { parameters: { query?: infer Q } } ? NonNullable<Q> : never;

export type BodyOf<P extends keyof paths, M extends Method> =
  Op<P, M> extends { requestBody?: { content: { 'application/json': infer B } } } ? B : never;

/** `/api/admin/users/{id}` gibi şablonu `{id: 5}` ile doldurur; `/api` önekini atar (client BASE'i ekler). */
export function fillPath(template: string, params?: Record<string, string | number>): string {
  const p = template.replace(/^\/api/, '').replace(/\{(\w+)\}/g, (_, k: string) => {
    const v = params?.[k];
    if (v === undefined) throw new Error(`Yol parametresi eksik: ${k}`);
    return encodeURIComponent(String(v));
  });
  return p;
}

export interface CallOptions<P extends keyof paths, M extends Method> {
  path?: Record<string, string | number>;
  query?: QueryOf<P, M>;
  signal?: AbortSignal;
}

export function typedGet<P extends PathsWith<'get'>>(
  template: P,
  opts: CallOptions<P, 'get'> = {},
): Promise<ResponseOf<P, 'get'>> {
  return apiFetch<ResponseOf<P, 'get'>>(fillPath(template, opts.path), {
    query: opts.query as Query | undefined,
    signal: opts.signal,
  });
}

export function typedSend<P extends PathsWith<'post'>>(
  template: P,
  method: 'POST',
  body?: BodyOf<P, 'post'>,
  opts?: { path?: Record<string, string | number> },
): Promise<ResponseOf<P, 'post'>>;
export function typedSend<P extends PathsWith<'put'>>(
  template: P,
  method: 'PUT',
  body?: BodyOf<P, 'put'>,
  opts?: { path?: Record<string, string | number> },
): Promise<ResponseOf<P, 'put'>>;
export function typedSend<P extends PathsWith<'patch'>>(
  template: P,
  method: 'PATCH',
  body?: BodyOf<P, 'patch'>,
  opts?: { path?: Record<string, string | number> },
): Promise<ResponseOf<P, 'patch'>>;
export function typedSend(
  template: string,
  method: 'POST' | 'PUT' | 'PATCH',
  body?: unknown,
  opts: { path?: Record<string, string | number> } = {},
): Promise<unknown> {
  return apiFetch(fillPath(template, opts.path), { method, body });
}

export type { StripApi };
