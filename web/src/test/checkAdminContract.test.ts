import { describe, expect, it } from 'vitest';
import {
  buildOperations,
  checkSources,
  extractCalls,
  matchCall,
  normalizePath,
} from '../../scripts/check-admin-contract.mjs';

const openapi = {
  paths: {
    '/api/admin/polls': { get: {}, post: {} },
    '/api/admin/polls/{id}': { get: {}, delete: {} },
    '/api/admin/polls/{id}/close': { post: {} },
    '/api/polls/{pollId}': { patch: {} },
  },
};

describe('normalizePath', () => {
  it('sorguyu atar, ifadeleri {} yapar ve sorgu ekini siler', () => {
    expect(normalizePath('/admin/polls?x=1')).toBe('/admin/polls');
    expect(normalizePath('/admin/polls/{}')).toBe('/admin/polls/{}');
    expect(normalizePath('/admin/polls{}')).toBe('/admin/polls');
    expect(normalizePath('/admin/users/{}/')).toBe('/admin/users/{}');
  });
});

describe('extractCalls', () => {
  it('api.* ve jenerikli cagrilari yontemiyle cikarir', () => {
    const src = [
      "export const a = () => api.get<{ items: X[] }>('/admin/polls', { page: 1 });",
      'export const b = (id: number) => api.del(`/admin/polls/${id}`, h);',
      "export const c = () => api.post<Foo<Bar>>('/admin/polls', body);",
      "export const d = (id: number) => apiBlob(`/admin/polls/${id}/export.csv`);",
      "export const e = () => apiFetch('/admin/polls/bulk', { method: 'POST', body: {} });",
    ].join('\n');
    const calls = extractCalls(src);
    expect(calls.map((c) => `${c.method} ${c.path}`)).toEqual([
      'GET /admin/polls',
      'DELETE /admin/polls/{}',
      'POST /admin/polls',
      'GET /admin/polls/{}/export.csv',
      'POST /admin/polls/bulk',
    ]);
    expect(calls.map((c) => c.line)).toEqual([1, 2, 3, 4, 5]);
  });

  it('degiskenle kurulan yollari dinamik sayar ve atlar', () => {
    const calls = extractCalls("const r = api.get(url); const s = api.post('/a/' + id);");
    expect(calls).toHaveLength(2);
    expect(calls.every((c) => c.dynamic && c.path === null)).toBe(true);
  });
});

describe('matchCall', () => {
  const ops = buildOperations(openapi);
  it('yontem + yol sablonu birlikte eslesir ({id} adi onemsiz)', () => {
    expect(matchCall({ method: 'GET', path: '/admin/polls/{}' }, ops)).toBe(true);
    expect(matchCall({ method: 'PATCH', path: '/polls/{}' }, ops)).toBe(true);
    expect(matchCall({ method: 'PUT', path: '/admin/polls/{}' }, ops)).toBe(false);
    expect(matchCall({ method: 'GET', path: '/admin/polls/{}/results' }, ops)).toBe(false);
  });
});

describe('checkSources', () => {
  it('eslesmeyen web cagrilarini listeler, dinamik olanlari ayri sayar', () => {
    const src = [
      "export const ok = () => api.get('/admin/polls');",
      'export const bad = (id: number) => api.put(`/admin/polls/${id}`, {});',
      'export const dyn = (u: string) => api.get(u);',
    ].join('\n');
    const r = checkSources(openapi, [{ rel: 'src/api/x.ts', src }]);
    expect(r.matched).toBe(1);
    expect(r.dynamic).toHaveLength(1);
    expect(r.unmatched).toHaveLength(1);
    expect(r.unmatched[0]).toMatchObject({ file: 'src/api/x.ts', method: 'PUT', path: '/api/admin/polls/{}', line: 2 });
    expect(r.total).toBe(3);
  });
});
