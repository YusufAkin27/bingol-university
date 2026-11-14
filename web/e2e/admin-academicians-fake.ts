/**
 * Yonetim akademisyen sayfalari icin PAYLASILAN sahte backend (DTO bicimli: AdminAcademicianView, CourseView, AttendanceMatrix, NoticeView).
 */
import type { Page, Route } from '@playwright/test';

const json = (route: Route, body: unknown, status = 200) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

export type Row = {
  userId: number; email: string | null; displayName: string | null; title: string | null; firstName: string | null; lastName: string | null;
  unit: string | null; status: string; approvalMode: string | null; rejectReason: string | null; reviewedBy: number | null; reviewedAt: string | null; createdAt: string;
};

const row = (id: number, status: string, over: Partial<Row> = {}): Row => ({
  userId: id, email: `hoca${id}@bingol.edu.tr`, displayName: `Hoca ${id} Öztürk`, title: 'Dr. Öğr. Üyesi', firstName: `Hoca${id}`, lastName: 'Öztürk',
  unit: 'Mühendislik Fakültesi', status, approvalMode: status === 'PENDING' ? null : 'ADMIN', rejectReason: null, reviewedBy: status === 'PENDING' ? null : 1,
  reviewedAt: status === 'PENDING' ? null : '2026-11-10T10:00:00Z', createdAt: '2026-11-01T09:00:00Z', ...over,
});

export interface AdminState {
  rows: Row[];
  perms: string[];
  calls: string[];
  bodies: Array<{ key: string; body: unknown; headers: Record<string, string> }>;
  unexpected: string[];
  intentional: number;
}

const COURSE = {
  id: 7, code: 'BIL101', name: 'Veri Yapıları', term: '2026-2027 Güz', faculty: null, department: 'Bilgisayar Mühendisliği', grade: '2',
  limit: { type: null, value: null }, absenceLimitType: null, absenceLimitValue: null, status: 'ACTIVE',
  slots: [{ id: 1, dayOfWeek: 1, startTime: '09:00', endTime: '09:50', room: 'A-101' }],
  enrolledCount: null, sessionCount: null, createdAt: '2026-09-20T08:00:00Z',
};

export function fresh(): AdminState {
  const rows: Row[] = [
    ...Array.from({ length: 25 }, (_, i) => row(100 + i, 'PENDING')),
    row(200, 'APPROVED', { approvalMode: 'ADMIN' }),
    row(201, 'APPROVED', { approvalMode: 'AUTO', reviewedBy: null }),
    row(202, 'REJECTED', { rejectReason: 'Belgeler eksik' }),
    row(203, 'REVOKED', { rejectReason: 'Yetki kötüye kullanıldı' }),
    row(204, 'APPROVED', { email: 'h***@b***.edu.tr', displayName: null, title: null, firstName: null, lastName: null, unit: null }),
  ];
  return { rows, perms: ['users.read', 'users.write', 'audit.read'], calls: [], bodies: [], unexpected: [], intentional: 0 };
}

export async function install(page: Page, st: AdminState) {
  await page.route((u) => u.pathname.startsWith('/api/'), async (r) => {
    const req = r.request();
    const url = new URL(req.url());
    const p = url.pathname.replace(/^\/api/, '');
    const m = req.method();
    st.calls.push(`${m} ${p}${url.search}`);
    let body: unknown = null;
    try { body = req.postDataJSON(); } catch { /* yok */ }
    st.bodies.push({ key: `${m} ${p}`, body, headers: req.headers() });

    if (p === '/admin/me') return json(r, { id: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', role: 'ADMIN' });
    if (p === '/admin/rbac/me') return json(r, { userId: 1, email: 'boss@bingol.edu.tr', displayName: 'Yonetici', profile: 'FULL', pinned: false, permissions: st.perms });
    if (p === '/admin/audit') return json(r, { items: [], nextCursor: null });
    if (p === '/admin/academicians' && m === 'GET') {
      const statuses = (url.searchParams.get('status') ?? '').split(',').filter(Boolean);
      const mode = url.searchParams.get('approvalMode');
      const cursor = Number(url.searchParams.get('cursor') ?? 0);
      const size = Number(url.searchParams.get('size') ?? 20);
      const all = st.rows.filter((x) => (!statuses.length || statuses.includes(x.status)) && (!mode || x.approvalMode === mode));
      const items = all.slice(cursor, cursor + size);
      return json(r, { items, nextCursor: cursor + size < all.length ? cursor + size : null });
    }
    const act = p.match(/^\/admin\/academicians\/(\d+)\/(approve|reject|revoke)$/);
    if (act && m === 'POST') {
      const x = st.rows.find((q) => String(q.userId) === act[1])!;
      const b = body as { reason?: string } | null;
      if ((act[2] !== 'approve') && !b?.reason) { st.intentional++; return json(r, { code: 'VALIDATION_ERROR', message: 'reason' }, 400); }
      x.status = act[2] === 'approve' ? 'APPROVED' : act[2] === 'reject' ? 'REJECTED' : 'REVOKED';
      x.approvalMode = 'ADMIN';
      x.rejectReason = b?.reason ?? null;
      x.reviewedBy = 1;
      x.reviewedAt = new Date().toISOString();
      return json(r, x);
    }
    const one = p.match(/^\/admin\/academicians\/(\d+)$/);
    if (one) { const x = st.rows.find((q) => String(q.userId) === one[1]); return x ? json(r, x) : (st.intentional++, json(r, { code: 'ACADEMICIAN_NOT_FOUND', message: 'yok' }, 404)); }
    if (/^\/admin\/academicians\/\d+\/courses$/.test(p)) return json(r, [COURSE, { ...COURSE, id: 8, code: null, name: 'Arşivlenmiş Ders', status: 'ARCHIVED', limit: { type: 'PERCENT', value: 30 }, slots: [] }]);
    if (p === '/admin/academicians/courses/7' || p === '/admin/academicians/courses/8') return json(r, COURSE);
    if (/^\/admin\/academicians\/courses\/\d+\/attendance$/.test(p)) {
      return json(r, {
        sessions: [{ id: 5, lessonDate: '2026-11-10' }, { id: 6, lessonDate: '2026-11-12' }],
        students: [
          { studentId: 1, displayName: 'Ayşe Örnek', studentNo: '2024000101', marks: { '5': 'PRESENT_QR', '6': 'PRESENT_MANUAL' }, absentCount: 0, atRisk: false, overLimit: false },
          { studentId: 2, displayName: 'Çağrı Öztürk', studentNo: '2024000102', marks: { '5': 'REVOKED', '6': 'ABSENT' }, absentCount: 2, atRisk: true, overLimit: false },
          { studentId: 3, displayName: null, studentNo: null, marks: {}, absentCount: 2, atRisk: false, overLimit: true },
        ],
        limit: { type: 'COUNT', value: 3 },
      });
    }
    if (/^\/admin\/academicians\/courses\/\d+\/notices$/.test(p)) {
      return json(r, { items: [{ id: 31, type: 'EXAM', title: 'Vize', note: 'Salon A-101', eventAt: '2026-12-20T07:00:00Z', createdAt: '2026-11-12T08:00:00Z', files: [{ id: 51, name: 'sorular.pdf', contentType: 'application/pdf', sizeBytes: 2048 }] }, { id: 30, type: 'LESSON_STARTED', title: null, note: null, eventAt: null, createdAt: '2026-11-11T08:00:00Z', files: [] }], nextCursor: null });
    }
    if (/^\/admin\/academicians\/notices\/\d+\/files\/\d+$/.test(p)) return r.fulfill({ status: 200, contentType: 'application/pdf', headers: { 'Content-Disposition': 'attachment; filename="sorular.pdf"' }, body: '%PDF-1.4' });
    st.unexpected.push(`${m} ${p}`);
    st.intentional++;
    return json(r, { code: 'NOT_FOUND', message: 'yok' }, 404);
  });
}

export async function boot(page: Page, st: AdminState, theme: 'light' | 'dark' = 'light') {
  const problems: string[] = [];
  page.on('pageerror', (e) => problems.push(`pageerror: ${e.message}`));
  page.on('console', (m) => {
    const t = m.text();
    if (m.type() === 'error' && !/Failed to load resource/.test(t)) problems.push(`console.error: ${t}`);
    if (m.type() === 'warning' && /unique "key"|validateDOMNesting/.test(t)) problems.push(`warning: ${t}`);
  });
  await page.addInitScript((t) => {
    try {
      sessionStorage.setItem('bu.admin.access', 'a.b.c');
      sessionStorage.setItem('bu.admin.refresh', 'r1');
      localStorage.setItem('bu.theme', t);
      localStorage.setItem('bu.cookies', 'ack:v1');
    } catch { /* yok */ }
  }, theme);
  await install(page, st);
  return problems;
}

