import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import AcademiciansPage from './AcademiciansPage';

afterEach(() => vi.unstubAllGlobals());

const academician = {
  userId: 5,
  email: 'o***@bingol.edu.tr',
  displayName: 'Örnek Hoca',
  title: 'Doç. Dr.',
  firstName: 'Örnek',
  lastName: 'Hoca',
  unit: 'Deneme Bölümü',
  status: 'APPROVED',
  approvalMode: 'AUTO',
  rejectReason: null,
  reviewedBy: null,
  reviewedAt: '2026-11-02T10:00:00Z',
  createdAt: '2026-11-02T09:59:00Z',
};

const course = {
  id: 11,
  code: 'DNM101',
  name: 'Deneme Dersi',
  term: '2026-Güz',
  faculty: null,
  department: 'Deneme Bölümü',
  grade: '1',
  limit: { type: 'COUNT', value: 3 },
  absenceLimitType: 'COUNT',
  absenceLimitValue: 3,
  status: 'ACTIVE',
  slots: [{ id: 1, dayOfWeek: 2, startTime: '09:00', endTime: '10:50', room: 'A-101' }],
  enrolledCount: 4,
  sessionCount: 2,
  createdAt: '2026-10-01T08:00:00Z',
};

const matrix = {
  sessions: [
    { id: 101, lessonDate: '2026-11-03' },
    { id: 102, lessonDate: '2026-11-10' },
  ],
  students: [
    { studentId: 1, displayName: 'Ali Deneme', studentNo: '100001', marks: { '101': 'PRESENT_QR', '102': 'PRESENT_MANUAL' }, absentCount: 0, atRisk: false, overLimit: false },
    { studentId: 2, displayName: 'Ayşe Örnek', studentNo: '100002', marks: { '101': 'REVOKED', '102': 'ABSENT' }, absentCount: 2, atRisk: true, overLimit: false },
    { studentId: 3, displayName: 'Can Sahte', studentNo: '100003', marks: { '101': 'ABSENT', '102': 'ABSENT' }, absentCount: 3, atRisk: false, overLimit: true },
  ],
  limit: { type: 'COUNT', value: 3 },
};

const notices = {
  items: [
    {
      id: 7,
      type: 'ASSIGNMENT',
      title: 'Ödev 1',
      note: 'Cuma gününe kadar teslim edin.',
      eventAt: '2026-11-20T12:00:00Z',
      createdAt: '2026-11-05T08:00:00Z',
      files: [{ id: 3, name: 'odev1.pdf', contentType: 'application/pdf', sizeBytes: 2048 }],
    },
  ],
  nextCursor: null,
};

const ME = { userId: 1, email: 'a@b.c', displayName: 'Y', profile: 'FULL', pinned: false, permissions: ['users.read', 'users.write', 'audit.read'] };

function setup(opts: { detail?: Response; matrix?: unknown; course?: unknown } = {}) {
  const urls: string[] = [];
  mockFetch((raw) => {
    urls.push(raw);
    const path = new URL(raw, 'http://x').pathname;
    if (path.endsWith('/admin/rbac/me')) return jsonResponse(200, ME);
    if (path.endsWith('/admin/audit')) return jsonResponse(200, []);
    if (path.endsWith('/admin/academicians/5')) return opts.detail ?? jsonResponse(200, academician);
    if (path.endsWith('/admin/academicians/404')) return jsonResponse(404, { code: 'ACADEMICIAN_NOT_FOUND', message: 'x' });
    if (path.endsWith('/admin/academicians/5/courses')) return jsonResponse(200, [opts.course ?? course]);
    if (path.endsWith('/admin/academicians/courses/11/attendance')) return jsonResponse(200, opts.matrix ?? matrix);
    if (path.endsWith('/admin/academicians/courses/11/notices')) return jsonResponse(200, notices);
    if (path.endsWith('/admin/academicians/notices/7/files/3'))
      return new Response('PDFDATA', { status: 200, headers: { 'Content-Type': 'application/pdf' } });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return urls;
}

function renderDetail(id = '5', query = '') {
  return renderWithProviders(
    <Routes>
      <Route path="/admin/academicians/:id" element={<AcademiciansPage />} />
    </Routes>,
    { route: `/admin/academicians/${id}${query}` },
  );
}

describe('Akademisyen ayrıntısı', () => {
  it('profili, maskeli e-postayı, karar bilgisini ve dersleri gösterir; düzenleme denetimi yoktur', async () => {
    setup();
    renderDetail();
    expect(await screen.findByRole('heading', { level: 1, name: 'Örnek Hoca' })).toBeInTheDocument();
    expect(screen.getByTitle('o***@bingol.edu.tr')).toBeInTheDocument();
    expect(screen.getByText('Deneme Bölümü', { selector: 'dd' })).toBeInTheDocument();
    expect(screen.getByText('Otomatik (kural)')).toBeInTheDocument();
    expect(screen.getByText('Sistem (kural)')).toBeInTheDocument();
    expect(await screen.findByRole('button', { name: /Deneme Dersi/ })).toBeInTheDocument();
    // yalnız karar düğmesi: ders/yoklama verisi için düzenleme yok
    expect(screen.getByRole('button', { name: 'Onayı geri al' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Kaydet|Sil|Düzenle/ })).not.toBeInTheDocument();
  });

  it('ders seçilince program, öğrenciler ve dört yoklama durumu (simge + metin) görünür', async () => {
    const urls = setup();
    renderDetail();
    await userEvent.click(await screen.findByRole('button', { name: /Deneme Dersi/ }));
    // Haftalık program
    expect(await screen.findByText('Salı')).toBeInTheDocument();
    expect(screen.getByText('09:00 - 10:50')).toBeInTheDocument();
    expect(screen.getByText('A-101')).toBeInTheDocument();

    // Öğrenciler: sınır durumu
    await userEvent.click(screen.getByRole('tab', { name: 'Öğrenciler' }));
    const studentsTable = await screen.findByRole('table', { name: 'Öğrenciler' });
    expect(within(studentsTable).getByText('Ali Deneme')).toBeInTheDocument();
    expect(within(studentsTable).getByText('Sınıra bir kala')).toBeInTheDocument();
    expect(within(studentsTable).getByText('Sınıra ulaştı')).toBeInTheDocument();
    expect(within(studentsTable).getByText('Normal')).toBeInTheDocument();

    // Yoklama matrisi: dört durum metinle ayrışır
    await userEvent.click(screen.getByRole('tab', { name: 'Devamsızlık' }));
    const matrixTable = await screen.findByRole('table', { name: 'Yoklama matrisi' });
    expect(within(matrixTable).getByText('Var (QR)')).toBeInTheDocument();
    expect(within(matrixTable).getByText('Var (elle)')).toBeInTheDocument();
    expect(within(matrixTable).getByText('Silindi')).toBeInTheDocument();
    expect(within(matrixTable).getAllByText('Yok').length).toBe(3);
    expect(within(matrixTable).getByText('Sınıra ulaştı')).toBeInTheDocument();

    // Oturumlar: matristen türetilen özet
    await userEvent.click(screen.getByRole('tab', { name: 'Yoklamalar' }));
    const sessions = await screen.findByRole('table', { name: 'Yoklamalar' });
    expect(within(sessions).getAllByRole('row').length).toBe(3);
    expect(urls.some((u) => u.endsWith('/admin/academicians/courses/11/attendance'))).toBe(true);
  });

  it('duyurular eklerle listelenir; indirme denetimli yönetici uç noktasını çağırır', async () => {
    const urls = setup();
    const create = vi.fn(() => 'blob:fake');
    vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: create, revokeObjectURL: vi.fn() }));
    renderDetail();
    await userEvent.click(await screen.findByRole('button', { name: /Deneme Dersi/ }));
    await userEvent.click(await screen.findByRole('tab', { name: 'Duyurular' }));
    expect(await screen.findByText('Ödev 1')).toBeInTheDocument();
    expect(screen.getByText('Ödev', { selector: 'span' })).toBeInTheDocument();
    expect(screen.getByText('Cuma gününe kadar teslim edin.')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /odev1.pdf/ }));
    await waitFor(() => expect(urls.some((u) => u.endsWith('/admin/academicians/notices/7/files/3'))).toBe(true));
    await waitFor(() => expect(create).toHaveBeenCalled());
  });

  it('bilinmeyen kimlik için bulunamadı durumu gösterir', async () => {
    setup();
    renderDetail('404');
    expect(await screen.findByText('Akademisyen bulunamadı')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Akademisyen listesine dön' })).toHaveAttribute('href', '/admin/academicians');
  });

  it('ders yoksa boş durum gösterir', async () => {
    mockFetch((raw) => {
      const path = new URL(raw, 'http://x').pathname;
      if (path.endsWith('/admin/rbac/me')) return jsonResponse(200, ME);
      if (path.endsWith('/admin/audit')) return jsonResponse(200, []);
      if (path.endsWith('/admin/academicians/5')) return jsonResponse(200, { ...academician, status: 'PENDING', approvalMode: null, reviewedAt: null });
      if (path.endsWith('/courses')) return jsonResponse(200, []);
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderDetail();
    expect(await screen.findByText('Bu akademisyenin dersi yok')).toBeInTheDocument();
    expect(screen.getByText('Henüz karar verilmedi')).toBeInTheDocument();
  });

  it('altı yoklama durumu, canlı/sayılmayan oturum, bilinmeyen durum ve izin verilen devamsızlık satırı', async () => {
    setup({
      course: { ...course, plannedSessions: 14, limit: { type: 'COUNT', value: 3, allowedAbsences: 3 } },
      matrix: {
        sessions: [
          { id: 101, lessonDate: '2026-11-03', live: false, counted: true },
          { id: 102, lessonDate: '2026-11-10', live: true, counted: false },
        ],
        students: [
          { studentId: 1, displayName: 'Ali Deneme', studentNo: null, marks: { '101': 'PRESENT_QR', '102': 'EXCUSED' }, absentCount: 0, atRisk: false, overLimit: false },
          { studentId: 2, displayName: 'Ayşe Örnek', studentNo: '10****', marks: { '101': 'NOT_ENROLLED_YET', '102': 'ABSENT' }, absentCount: 0, atRisk: false, overLimit: false },
          { studentId: 3, displayName: 'Can Sahte', studentNo: '100003', marks: { '101': 'FUTURE_MARK', '102': 'REVOKED' }, absentCount: 1, atRisk: false, overLimit: false },
        ],
        limit: { type: 'COUNT', value: 3, allowedAbsences: 3 },
      },
    });
    renderDetail('5', '?course=11&ctab=attendance');
    const table = await screen.findByRole('table', { name: 'Yoklama matrisi' });
    expect(within(table).getByText('İzinli')).toBeInTheDocument();
    expect(within(table).getByText('Kayıtlı değildi')).toBeInTheDocument();
    expect(within(table).getByText('Henüz okutmadı')).toBeInTheDocument();
    expect(within(table).getByText('FUTURE_MARK')).toBeInTheDocument();
    expect(within(table).getByText('Silindi')).toBeInTheDocument();
    expect(within(table).getByText(/sayılmıyor/)).toBeInTheDocument();
    expect(within(table).getByText('10****')).toBeInTheDocument();
    const legend = screen.getByRole('list', { name: 'Yoklama durumları' });
    expect(within(legend).getAllByRole('listitem').length).toBe(6);
    expect(screen.getAllByText('En fazla 3 devamsızlık').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Planlanan 14 oturum').length).toBeGreaterThan(0);
  });

  it("seçili ders sekmesi URL'dedir (yenilemede korunur)", async () => {
    setup();
    renderDetail('5', '?course=11&ctab=notices');
    expect(await screen.findByText('Ödev 1')).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Duyurular' })).toHaveAttribute('aria-selected', 'true');
  });
});
