// Akademisyen paneli test yardımcıları (yalnız testler içe aktarır).
import { Route, Routes } from 'react-router-dom';
import { vi } from 'vitest';
import { tokensFor } from '../../auth/tokens';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import AcademicianRoutes from '../../routes.academician';

export type MockHandler = (req: { url: URL; method: string; body: unknown; init: RequestInit }) => Response | Promise<Response> | unknown;

type Json = string | number | boolean | null | undefined | readonly unknown[] | { [k: string]: unknown };
interface Entry {
  method: string;
  re: RegExp;
  fn: MockHandler;
}

/** Yol deseni (`/academician/courses/:id`) -> yönlendirmeli sahte API. Eşleşmeyen istek 404; çağrılar `calls` listesine yazılır. */
export function mockApi() {
  const entries: Entry[] = [];
  const calls: { method: string; path: string; body: unknown; headers: Record<string, string> }[] = [];
  const toRe = (p: string) => new RegExp(`^${p.replace(/:[A-Za-z]+/g, '[^/]+')}$`);
  const api = {
    calls,
    on(method: string, pattern: string, fn: MockHandler | Json) {
      entries.unshift({ method, re: toRe(pattern), fn: (typeof fn === 'function' ? fn : () => fn) as MockHandler });
      return api;
    },
    get: (p: string, fn: MockHandler | Json) => api.on('GET', p, fn),
    post: (p: string, fn: MockHandler | Json) => api.on('POST', p, fn),
    put: (p: string, fn: MockHandler | Json) => api.on('PUT', p, fn),
    patch: (p: string, fn: MockHandler | Json) => api.on('PATCH', p, fn),
    del: (p: string, fn: MockHandler | Json) => api.on('DELETE', p, fn),
    callsTo: (method: string, pattern: string) => calls.filter((c) => c.method === method && toRe(pattern).test(c.path)),
    install() {
      return mockFetch(async (rawUrl, init) => {
        const url = new URL(rawUrl, 'http://localhost');
        const path = url.pathname.replace(/^\/api/, '');
        const method = (init.method ?? 'GET').toUpperCase();
        let body: unknown;
        if (typeof init.body === 'string') {
          try {
            body = JSON.parse(init.body);
          } catch {
            body = init.body;
          }
        } else body = init.body;
        calls.push({ method, path, body, headers: (init.headers ?? {}) as Record<string, string> });
        const hit = entries.find((e) => e.method === method && e.re.test(path));
        if (!hit) return jsonResponse(404, { code: 'NOT_FOUND', message: 'yok' });
        const out = await hit.fn({ url, method, body, init });
        if (out instanceof Response) return out;
        if (out === undefined) return jsonResponse(204);
        return jsonResponse(200, out);
      });
    },
  };
  return api;
}

export const err = (status: number, code: string, message = code) => jsonResponse(status, { code, message });

export const APPROVED_ME = {
  status: 'APPROVED',
  approvalMode: 'AUTO',
  title: 'Dr. Öğr. Üyesi',
  firstName: 'Deneme',
  lastName: 'Hoca',
  unit: 'Mühendislik Fakültesi',
  rejectReason: null,
};

export const course = (over: Record<string, unknown> = {}) => ({
  id: 7,
  code: 'BIL101',
  name: 'Veri Yapıları',
  term: '2026-2027 Güz',
  faculty: 'Mühendislik ve Mimarlık Fakültesi',
  department: 'Bilgisayar Mühendisliği',
  grade: '2',
  limit: { type: null, value: null },
  absenceLimitType: null,
  absenceLimitValue: null,
  status: 'ACTIVE',
  slots: [],
  enrolledCount: 3,
  sessionCount: 1,
  createdAt: '2026-09-20T08:00:00Z',
  ...over,
});

export function setAcadTokens() {
  tokensFor('acad').setTokens('acad-access', 'acad-refresh');
}

/** `/akademisyen/*` rotalarını (gerçek yönlendirme, kabuk, sağlayıcı) verilen adresle çizer. */
export function renderAcademician(route: string) {
  return renderWithProviders(
    <Routes>
      <Route path="akademisyen/*" element={<AcademicianRoutes />} />
      <Route path="admin/login" element={<p>yonetim girisi</p>} />
      <Route path="*" element={<p>baska sayfa</p>} />
    </Routes>,
    { route },
  );
}

export { vi };
