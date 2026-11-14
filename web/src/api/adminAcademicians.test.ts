import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../test/fetchMock';
import {
  approveAcademician,
  downloadNoticeFile,
  getCourseAttendance,
  listAcademicianCourses,
  listAcademicians,
  listCourseNotices,
  rejectAcademician,
  revokeAcademician,
} from './adminAcademicians';

afterEach(() => vi.unstubAllGlobals());

describe('adminAcademicians istemcisi', () => {
  it('liste: birden çok durum virgülle, boş değerler gönderilmez', async () => {
    const fn = mockFetch(() => jsonResponse(200, { items: [], nextCursor: null }));
    await listAcademicians({ status: ['REJECTED', 'REVOKED'], approvalMode: undefined, cursor: 12, size: 20 });
    const url = new URL(String(fn.mock.calls[0][0]), 'http://x');
    expect(url.pathname).toBe('/api/admin/academicians');
    expect(url.searchParams.get('status')).toBe('REJECTED,REVOKED');
    expect(url.searchParams.get('cursor')).toBe('12');
    expect(url.searchParams.has('approvalMode')).toBe(false);
    await listAcademicians({});
    expect(String(fn.mock.calls[1][0]).endsWith('/api/admin/academicians')).toBe(true);
  });

  it('karar uçları: yol, yöntem, gövde ve Idempotency-Key', async () => {
    const fn = mockFetch(() => jsonResponse(200, {}));
    await approveAcademician(3, 'k1');
    await rejectAcademician(3, 'neden', 'k2');
    await revokeAcademician(3, 'neden2');
    const [a, r, v] = fn.mock.calls.map(([u, i]) => ({ u: String(u), i: i as RequestInit }));
    expect(a.u).toBe('/api/admin/academicians/3/approve');
    expect(a.i.method).toBe('POST');
    expect((a.i.headers as Record<string, string>)['Idempotency-Key']).toBe('k1');
    expect(r.u).toBe('/api/admin/academicians/3/reject');
    expect(JSON.parse(String(r.i.body))).toEqual({ reason: 'neden' });
    expect(v.u).toBe('/api/admin/academicians/3/revoke');
    expect(JSON.parse(String(v.i.body))).toEqual({ reason: 'neden2' });
  });

  it('salt okunur ders uçları ve denetimli dosya indirme yolu', async () => {
    const fn = mockFetch((u) => (u.includes('/files/') ? new Response('x') : jsonResponse(200, [])));
    await listAcademicianCourses(5);
    await getCourseAttendance(11);
    await listCourseNotices(11, { cursor: 4, size: 20 });
    await downloadNoticeFile(7, 3);
    const urls = fn.mock.calls.map(([u]) => String(u));
    expect(urls).toEqual([
      '/api/admin/academicians/5/courses',
      '/api/admin/academicians/courses/11/attendance',
      '/api/admin/academicians/courses/11/notices?cursor=4&size=20',
      '/api/admin/academicians/notices/7/files/3',
    ]);
  });
});
