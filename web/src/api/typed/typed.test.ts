import { afterEach, describe, expect, it, vi } from 'vitest';
import { fillPath, typedGet } from './typedApi';
import { getUserTyped, listUsersTyped } from './adminUsersTyped';

afterEach(() => vi.restoreAllMocks());

describe('typedApi', () => {
  it('yol parametrelerini doldurur ve /api önekini atar', () => {
    expect(fillPath('/api/admin/users/{id}', { id: 7 })).toBe('/admin/users/7');
    expect(() => fillPath('/api/admin/users/{id}')).toThrow();
  });

  it('GET çağrısı client üzerinden doğru URL ile gider', async () => {
    const f = vi.spyOn(globalThis, 'fetch').mockImplementation(() => Promise.resolve(new Response(JSON.stringify({ items: [] }), { status: 200 })));
    await listUsersTyped({ page: 1, q: 'ali' });
    expect(String(f.mock.calls[0][0])).toBe('/api/admin/users?page=1&q=ali');
    await getUserTyped(5);
    expect(String(f.mock.calls[1][0])).toBe('/api/admin/users/5');
    await typedGet('/api/status');
    expect(String(f.mock.calls[2][0])).toBe('/api/status');
  });
});
