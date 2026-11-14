/**
 * Akademisyen alani icin PAYLASILAN sahte backend (page.route) ve konsol bekcisi. Yanit bicimleri UI beklentisinden degil,
 * backend DTO'larindan (AcademicianDtos.java, docs/openapi.json) turetilmistir: liste ucunda `enrolledCount`/`sessionCount`
 * null, `limit` her zaman {type:null,value:null} nesnesi (null degil), canli uc oturumun TUM kayitlarini her yoklamada dondurur,
 * liste ucu `pendingScans` icermez, imlecli sayfalama {items,nextCursor}.
 */
import { expect, type Page, type Route } from '@playwright/test';

export const json = (route: Route, body: unknown, status = 200) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

export const iso = (offsetMs = 0) => new Date(Date.now() + offsetMs).toISOString();

export interface FakeState {
  me: Record<string, unknown>;
  /** true: akademisyen uclari 401, /auth/refresh 401 (oturum dustu). */
  expired: boolean;
  /** live ucu: 'ok' | 'fail' (baglanti kopuk) */
  live: 'ok' | 'fail';
  livePolls: number;
  liveRecordCount: number;
  skewMs: number;
  pending: Array<Record<string, unknown>>;
  sessionStatus: 'OPEN' | 'CLOSED';
  limit: { type: 'COUNT' | 'PERCENT' | null; value: number | null };
  slots: Array<Record<string, unknown>>;
  notices: Array<Record<string, unknown>>;
  enrolled: Array<Record<string, unknown>>;
  /** Istek gunlugu: "METHOD /yol" */
  calls: string[];
  bodies: Array<{ key: string; body: unknown }>;
  /** Mock'un taniyamadigi istekler (bulgu). */
  unexpected: string[];
  /** Mock'un bilerek verdigi 4xx/5xx sayisi (konsoldaki "Failed to load resource" gurultusu icin). */
  intentionalErrors: number;
  nextNoticeId: number;
  uploadReject: boolean;
}

export const COURSE_BASE = {
  id: 7, code: 'BIL101', name: 'Veri Yapıları', term: '2026-2027 Güz', faculty: 'Mühendislik ve Mimarlık Fakültesi',
  department: 'Bilgisayar Mühendisliği', grade: '2', status: 'ACTIVE', createdAt: '2026-09-20T08:00:00Z',
};

export const STUDENTS = Array.from({ length: 30 }, (_, i) => ({
  id: 100 + i,
  displayName: ['Ayşe Örnek', 'Çağrı Öztürk', 'Şule Işık', 'Ömer Ğüngör', 'İlkay Ünal', 'Zeynep Yılmaz'][i % 6] + (i >= 6 ? ` ${i}` : ''),
  studentNo: String(2024000100 + i),
  faculty: 'Mühendislik ve Mimarlık Fakültesi',
  department: 'Bilgisayar Mühendisliği',
  grade: '2',
}));

export function newState(over: Partial<FakeState> = {}): FakeState {
  return {
    me: { status: 'APPROVED', approvalMode: 'AUTO', title: 'Dr.', firstName: 'Deneme', lastName: 'Hoca', unit: null, rejectReason: null },
    expired: false, live: 'ok', livePolls: 0, liveRecordCount: 3, skewMs: 0,
    pending: [{ studentId: 41, displayName: 'Kayıtsız Kişi', studentNo: '2024000941', faculty: null, department: null, grade: null, scannedAt: iso(-20_000) }],
    sessionStatus: 'OPEN',
    limit: { type: null, value: null },
    slots: [{ id: 1, dayOfWeek: 1, startTime: '09:00', endTime: '09:50', room: 'A-101' }],
    notices: [],
    enrolled: STUDENTS.slice(0, 4).map((s) => ({ studentId: s.id, displayName: s.displayName, studentNo: s.studentNo, faculty: s.faculty, department: s.department, grade: s.grade, addedAt: '2026-09-21T08:00:00Z' })),
    calls: [], bodies: [], unexpected: [], intentionalErrors: 0, nextNoticeId: 1, uploadReject: false,
    ...over,
  };
}

const courseView = (st: FakeState, detail: boolean) => ({
  ...COURSE_BASE,
  limit: { type: st.limit.type, value: st.limit.value },
  absenceLimitType: st.limit.type, absenceLimitValue: st.limit.value,
  slots: st.slots,
  // liste ucunda null (backend: yalniz ayrintida dolu)
  enrolledCount: detail ? st.enrolled.length : null,
  sessionCount: detail ? 1 : null,
});

const matrix = (st: FakeState) => ({
  sessions: [{ id: 5, lessonDate: '2026-11-10' }, { id: 6, lessonDate: '2026-11-12' }, { id: 7, lessonDate: '2026-11-14' }],
  students: st.enrolled.map((e, i) => {
    const marks = i === 0
      ? { '5': 'PRESENT_QR', '6': 'PRESENT_MANUAL', '7': 'PRESENT_QR' }
      : i === 1 ? { '5': 'REVOKED', '6': 'ABSENT', '7': 'ABSENT' }
      : i === 2 ? { '5': 'PRESENT_MANUAL', '6': 'ABSENT', '7': 'ABSENT' }
      : { '5': 'ABSENT', '6': 'ABSENT', '7': 'ABSENT' };
    const absent = Object.values(marks).filter((m) => m === 'ABSENT' || m === 'REVOKED').length;
    return { studentId: e.studentId, displayName: e.displayName, studentNo: e.studentNo, marks, absentCount: absent, atRisk: absent === 2, overLimit: absent >= 3 };
  }),
  limit: { type: st.limit.type, value: st.limit.value },
});

const recordsFor = (st: FakeState) =>
  Array.from({ length: st.liveRecordCount }, (_, i) => ({
    id: i + 1, studentId: 100 + i, displayName: STUDENTS[i % STUDENTS.length].displayName, studentNo: STUDENTS[i % STUDENTS.length].studentNo,
    method: i % 3 === 2 ? 'MANUAL' : 'QR', markedAt: iso(-60_000 + i * 1000), revoked: false,
  }));

const sessionView = (st: FakeState, single: boolean) => ({
  id: 5, courseId: 7, slotId: null, lessonDate: '2026-11-14', openedAt: '2026-11-14T08:00:00Z',
  expiresAt: '2026-11-14T11:00:00Z', closedAt: st.sessionStatus === 'CLOSED' ? '2026-11-14T10:00:00Z' : null,
  status: st.sessionStatus, presentCount: st.liveRecordCount, enrolledCount: st.enrolled.length,
  ...(single ? { pendingScans: st.pending } : {}),
});

export const stepOf = (ms: number) => Math.floor(ms / 5000);

/** Gercek saatle degisen kod: `bingol-lesson:5.<adim>.<imza>`. */
export const codeFor = (step: number) => `bingol-lesson:5.${step}.abcDEF123_-xyz${step % 7}`;

export async function installAcademicianFake(page: Page, st: FakeState): Promise<void> {
  await page.route((u) => u.pathname.startsWith('/api/'), async (r) => {
    const req = r.request();
    const url = new URL(req.url());
    const p = url.pathname.replace(/^\/api/, '');
    const m = req.method();
    st.calls.push(`${m} ${p}`);
    let body: unknown = null;
    try { body = req.postDataJSON(); } catch { /* multipart */ }
    st.bodies.push({ key: `${m} ${p}`, body });
    const err = (status: number, code: string, message = 'hata') => { st.intentionalErrors++; return json(r, { code, message }, status); };

    if (p === '/auth/refresh') return st.expired ? err(401, 'UNAUTHORIZED') : json(r, { accessToken: 'a.b.c', refreshToken: 'r2' });
    if (p === '/catalog/academic') {
      return json(r, {
        faculties: [{ id: 'muh', name: 'Mühendislik ve Mimarlık Fakültesi', departments: [{ id: 'bm', name: 'Bilgisayar Mühendisliği' }, { id: 'em', name: 'Elektrik-Elektronik Mühendisliği' }] }],
        grades: [{ id: '1', name: '1. sınıf' }, { id: '2', name: '2. sınıf' }],
      });
    }
    if (p === '/auth/register') return json(r, { message: 'ok' }, 202);
    if (p === '/auth/verify-email') { st.me = { ...st.me, status: 'NONE', approvalMode: null, title: null, firstName: null, lastName: null }; return json(r, { accessToken: 'a.b.c', refreshToken: 'r1' }); }
    if (p === '/auth/login') return json(r, { accessToken: 'a.b.c', refreshToken: 'r1' });
    if (p === '/auth/logout') return json(r, {}, 204);

    if (p.startsWith('/academician/') && st.expired) return err(401, 'UNAUTHORIZED');

    if (p === '/academician/me') {
      if (m === 'PUT') { st.me = { ...st.me, ...(body as object) }; return json(r, st.me); }
      return json(r, st.me);
    }
    if (p === '/academician/apply') {
      const b = body as Record<string, unknown>;
      st.me = { status: 'PENDING', approvalMode: null, title: b.title, firstName: b.firstName, lastName: b.lastName, unit: b.unit ?? null, rejectReason: null };
      return json(r, { status: 'PENDING' });
    }
    if (p === '/academician/courses') return json(r, [courseView(st, false)]);
    if (p === '/academician/courses/7') return json(r, courseView(st, true));
    if (p === '/academician/courses/7/slots' && m === 'PUT') {
      st.slots = (body as Array<Record<string, unknown>>).map((s, i) => ({ id: i + 1, ...s, room: s.room ?? null }));
      return json(r, st.slots);
    }
    if (p === '/academician/courses/7' && m === 'PATCH') return json(r, courseView(st, true));
    if (p === '/academician/courses/7/sessions') return json(r, [sessionView(st, false)]);
    if (p === '/academician/courses/7/attendance') return json(r, matrix(st));
    if (p === '/academician/courses/7/attendance.csv') {
      return r.fulfill({ status: 200, contentType: 'text/csv; charset=UTF-8', headers: { 'Content-Disposition': 'attachment; filename="devamsizlik.csv"' }, body: '﻿Ad;Durum\nAyşe;Var (QR)\n' });
    }
    if (p === '/academician/courses/7/enrollments') {
      if (m === 'POST') {
        const ids = (body as { studentIds: number[] }).studentIds;
        let added = 0;
        for (const id of ids) {
          if (st.enrolled.some((e) => e.studentId === id)) continue;
          const s = STUDENTS.find((x) => x.id === id)!;
          st.enrolled.push({ studentId: s.id, displayName: s.displayName, studentNo: s.studentNo, faculty: s.faculty, department: s.department, grade: s.grade, addedAt: iso() });
          added++;
        }
        return json(r, { added });
      }
      return json(r, st.enrolled);
    }
    if (p === '/academician/students') {
      const q = (url.searchParams.get('q') ?? '').toLocaleLowerCase('tr');
      const cursor = Number(url.searchParams.get('cursor') ?? 0);
      const size = Number(url.searchParams.get('size') ?? 20);
      const all = STUDENTS.filter((s) => !q || `${s.displayName} ${s.studentNo}`.toLocaleLowerCase('tr').includes(q));
      const items = all.slice(cursor, cursor + size);
      return json(r, { items, nextCursor: cursor + size < all.length ? cursor + size : null });
    }
    if (p === '/academician/courses/7/notices') {
      if (m === 'POST') {
        const b = body as Record<string, unknown>;
        const n = { id: st.nextNoticeId++, type: b.type, title: b.title ?? null, note: b.note ?? null, eventAt: b.eventAt ?? null, createdAt: iso(), files: (b.fileIds as number[] | undefined)?.map((id) => ({ id, name: 'ders-notu.pdf', contentType: 'application/pdf', sizeBytes: 12345 })) ?? [] };
        st.notices.unshift(n);
        return json(r, n, 201);
      }
      return json(r, { items: st.notices, nextCursor: null });
    }
    if (p === '/academician/courses/7/notice-files') {
      if (st.uploadReject) return err(400, 'NOTICE_FILE_TYPE_NOT_ALLOWED', 'tur');
      return json(r, { id: 900 + st.calls.length, name: 'ders-notu.pdf', contentType: 'application/pdf', sizeBytes: 12345 }, 201);
    }
    if (p === '/academician/sessions/5') return json(r, sessionView(st, true));
    if (p === '/academician/sessions/5/close') { st.sessionStatus = 'CLOSED'; return json(r, sessionView(st, true)); }
    if (p === '/academician/sessions/5/reopen') { st.sessionStatus = 'OPEN'; return json(r, sessionView(st, true)); }
    const pend = p.match(/^\/academician\/sessions\/5\/pending\/(\d+)\/(accept|dismiss)$/);
    if (pend) {
      st.pending = st.pending.filter((x) => String(x.studentId) !== pend[1]);
      if (pend[2] === 'accept') { st.liveRecordCount++; return json(r, { id: 99, studentId: Number(pend[1]), displayName: 'Kayıtsız Kişi', studentNo: null, method: 'MANUAL', markedAt: iso(), revoked: false }); }
      return json(r, {}, 204);
    }
    if (p === '/academician/sessions/5/live') {
      st.livePolls++;
      if (st.live === 'fail') { st.intentionalErrors++; return r.abort('connectionrefused'); }
      const now = Date.now() + st.skewMs;
      const step = stepOf(now);
      const w = (s: number) => ({ code: codeFor(s), fromMs: s * 5000, untilMs: (s + 1) * 5000 });
      return json(r, {
        status: st.sessionStatus, serverNowMs: now, stepSeconds: 5,
        codes: st.sessionStatus === 'OPEN' ? [w(step), w(step + 1), w(step + 2)] : [],
        presentCount: st.liveRecordCount, enrolledCount: st.enrolled.length,
        newRecords: recordsFor(st), pendingScans: st.pending,
      });
    }
    st.unexpected.push(`${m} ${p}`);
    return err(404, 'NOT_FOUND', 'yok');
  });
}

export async function seedAcadSession(page: Page, theme: 'light' | 'dark' = 'light'): Promise<void> {
  await page.addInitScript((t) => {
    try {
      sessionStorage.setItem('bu.acad.access', 'a.b.c');
      sessionStorage.setItem('bu.acad.refresh', 'r1');
      localStorage.setItem('bu.theme', t);
      localStorage.setItem('bu.cookies', 'ack:v1');
    } catch { /* yoksay */ }
  }, theme);
}

export async function seedTheme(page: Page, theme: 'light' | 'dark'): Promise<void> {
  await page.addInitScript((t) => {
    try {
      localStorage.setItem('bu.theme', t);
      localStorage.setItem('bu.cookies', 'ack:v1');
    } catch { /* yoksay */ }
  }, theme);
}

/** Konsol bekcisi: console.error, yakalanmamis hata/ret, React key uyarisi, mock'un istemedigi basarisiz ag istekleri. */
export function guardConsole(page: Page, st?: FakeState) {
  const problems: string[] = [];
  page.on('console', (m) => {
    const text = m.text();
    if (m.type() === 'error') {
      // mock'un bilerek verdigi 4xx/5xx ve abort'lar tarayicida bu satiri uretir
      if (/Failed to load resource|net::ERR_/.test(text) && st && st.intentionalErrors > 0) return;
      problems.push(`console.error: ${text}`);
    } else if (m.type() === 'warning' && /unique "key"|Each child in a list|validateDOMNesting|act\(/.test(text)) {
      problems.push(`console.warning: ${text}`);
    }
  });
  page.on('pageerror', (e) => problems.push(`pageerror: ${e.message}`));
  page.on('requestfailed', (rq) => {
    const u = rq.url();
    if (!u.includes('/api/')) { problems.push(`requestfailed: ${rq.method()} ${u} ${rq.failure()?.errorText}`); return; }
    if (st && st.intentionalErrors > 0) return;
    problems.push(`requestfailed: ${rq.method()} ${u} ${rq.failure()?.errorText}`);
  });
  return {
    problems,
    assertClean() {
      if (st) expect(st.unexpected, 'mock tanimadigi istekler').toEqual([]);
      expect(problems, 'konsol/ag sorunlari').toEqual([]);
    },
  };
}

export const hOverflow = (page: Page) =>
  page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
