import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../test/fetchMock';
import {
  addSuppression,
  bulkOutbox,
  cancelOutbox,
  exportSuppressionsCsv,
  listOutbox,
  listSuppressions,
  removeSuppression,
  retryOutbox,
} from './adminMailOps';

afterEach(() => vi.unstubAllGlobals());

interface Call {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: unknown;
}
function capture(response: () => Response = () => jsonResponse(200, {})) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({
      url,
      method: init.method ?? 'GET',
      headers: (init.headers ?? {}) as Record<string, string>,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
    });
    return response();
  });
  return calls;
}

describe('bastırma çağrıları', () => {
  it('liste: boş süzgeçler gönderilmez, q kırpılır', async () => {
    const calls = capture();
    await listSuppressions({ reason: '', q: '  ali@x.com ', page: 2 });
    expect(calls[0].url).toBe('/api/admin/mail/suppressions?q=ali%40x.com&page=2&size=20');
  });

  it('ekleme: sebep MANUAL, not gövdede ve sebep başlığında (yüzde kodlu)', async () => {
    const calls = capture();
    await addSuppression({ email: ' a@b.co ', note: 'Kullanıcı telefonla istedi' });
    expect(calls[0].method).toBe('POST');
    expect(calls[0].body).toEqual({ email: 'a@b.co', reason: 'MANUAL', note: 'Kullanıcı telefonla istedi' });
    expect(decodeURIComponent(calls[0].headers['X-Admin-Reason'])).toBe('Kullanıcı telefonla istedi');
  });

  it('kaldırma: onay başlığı yalnız confirm=true iken kayıt kimliğiyle gider', async () => {
    const calls = capture(() => jsonResponse(204));
    await removeSuppression(7, { reason: 'Kullanıcı yazılı olarak istedi', confirm: true });
    await removeSuppression(8, { reason: 'adres düzeltildi' });
    expect(calls[0].method).toBe('DELETE');
    expect(calls[0].url).toBe('/api/admin/mail/suppressions/7');
    expect(calls[0].headers['X-Admin-Confirm']).toBe('7');
    expect(decodeURIComponent(calls[0].headers['X-Admin-Reason'])).toBe('Kullanıcı yazılı olarak istedi');
    expect(calls[1].headers['X-Admin-Confirm']).toBeUndefined();
  });

  it('CSV: süzgeçler sorguya geçer', async () => {
    const calls = capture(() => new Response('id', { status: 200 }));
    await exportSuppressionsCsv({ reason: 'BOUNCED', from: '2026-10-01' });
    expect(calls[0].url).toBe('/api/admin/mail/suppressions/export.csv?reason=BOUNCED&from=2026-10-01');
  });
});

describe('kuyruk çağrıları', () => {
  it('liste süzgeçleri', async () => {
    const calls = capture();
    await listOutbox({ status: 'DEAD', template: 'ANNOUNCEMENT', q: '@bingol.edu.tr' });
    expect(calls[0].url).toBe('/api/admin/mail/outbox?status=DEAD&template=ANNOUNCEMENT&q=%40bingol.edu.tr&page=0&size=20');
  });

  it('yeniden dene / iptal: gövdesiz POST + sebep başlığı', async () => {
    const calls = capture();
    await retryOutbox(4, { reason: 'sunucu düzeldi' });
    await cancelOutbox(5, { reason: 'yanlış gönderim' });
    expect(calls.map((c) => [c.method, c.url])).toEqual([
      ['POST', '/api/admin/mail/outbox/4/retry'],
      ['POST', '/api/admin/mail/outbox/5/cancel'],
    ]);
    expect(decodeURIComponent(calls[1].headers['X-Admin-Reason'])).toBe('yanlış gönderim');
  });

  it('toplu: eylem, kimlikler ve sebep gövdede', async () => {
    const calls = capture();
    await bulkOutbox('RETRY', [1, 2], { reason: 'toplu düzeltme' });
    expect(calls[0].url).toBe('/api/admin/mail/outbox/bulk');
    expect(calls[0].body).toEqual({ action: 'RETRY', ids: [1, 2], reason: 'toplu düzeltme' });
  });
});
