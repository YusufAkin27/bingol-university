import { afterEach, describe, expect, it, vi } from 'vitest';
import { deleteDead, retryDead } from './system';
import { jsonResponse, mockFetch } from '../test/fetchMock';

afterEach(() => vi.unstubAllGlobals());

/** Backend'in gerçek uçları: POST /api/admin/system/dead-letters/{mail|push}/{retry|delete}, gövde {ids}. */
describe('ölü kayıt (dead letter) çağrıları', () => {
  function capture() {
    const calls: { url: string; method: string; body: unknown }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, method: init.method ?? 'GET', body: init.body ? JSON.parse(String(init.body)) : undefined });
      return jsonResponse(200, { requeued: 2, deleted: 2 });
    });
    return calls;
  }

  it.each(['mail', 'push'] as const)('%s için yeniden dene: yol ve ids gövdesi', async (kind) => {
    const calls = capture();
    await retryDead(kind, [3, 4]);
    expect(calls).toEqual([{ url: `/api/admin/system/dead-letters/${kind}/retry`, method: 'POST', body: { ids: [3, 4] } }]);
  });

  it.each(['mail', 'push'] as const)('%s için sil: yol ve ids gövdesi', async (kind) => {
    const calls = capture();
    await deleteDead(kind, [9]);
    expect(calls).toEqual([{ url: `/api/admin/system/dead-letters/${kind}/delete`, method: 'POST', body: { ids: [9] } }]);
  });

  it('boş ids tüm ölü kayıtları yeniden dener (gövde ids: [])', async () => {
    const calls = capture();
    await retryDead('mail', []);
    expect(calls[0].body).toEqual({ ids: [] });
  });
});
