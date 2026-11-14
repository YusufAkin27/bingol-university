// Ders sayfaları: program düzenleyici, ders oluşturma/düzenleme, öğrenci ekleme, oturum ayrıntısı (dört durum), devamsızlık, dışa aktarma.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { tokensFor } from '../../../auth/tokens';
import { ENROLL_CHUNK, addEnrollmentsChunked } from '../../../api/academician';
import { APPROVED_ME, course, err, mockApi, renderAcademician, setAcadTokens } from '../testUtils';
import { overlaps, slotError, type SlotRow } from './slots';
import { riskSort } from './AbsenceTab';
import { csvFileName } from './ExportTab';

afterEach(() => tokensFor('acad').clearTokens());

const base = () => {
  setAcadTokens();
  return mockApi()
    .get('/academician/me', APPROVED_ME)
    .get('/catalog/academic', {
      version: 1,
      faculties: [{ id: 'f1', name: 'Mühendislik ve Mimarlık Fakültesi', departments: [{ id: 'd1', name: 'Bilgisayar Mühendisliği' }, { id: 'd2', name: 'Elektrik Mühendisliği' }] }],
      grades: [{ id: '1', name: '1. Sınıf' }, { id: '2', name: '2. Sınıf' }],
    });
};

const row = (day: number, s: string, e: string, key = `${day}${s}`): SlotRow => ({ key, dayOfWeek: day, startTime: s, endTime: e, room: '' });

describe('slots.ts', () => {
  it('bitiş <= başlangıç ve geçersiz saat hata; geçerli satır hatasız', () => {
    expect(slotError({ startTime: '10:00', endTime: '10:00' })).toBe('order');
    expect(slotError({ startTime: '10:00', endTime: '09:00' })).toBe('order');
    expect(slotError({ startTime: '25:00', endTime: '26:00' })).toBe('start');
    expect(slotError({ startTime: '09:00', endTime: '' })).toBe('end');
    expect(slotError({ startTime: '09:00', endTime: '09:50' })).toBeNull();
  });
  it('aynı gün çakışmayı bulur; bitişik ve farklı gün çakışmaz', () => {
    expect(overlaps([row(1, '09:00', '10:00', 'a'), row(1, '09:30', '10:30', 'b')])).toEqual([['a', 'b']]);
    expect(overlaps([row(1, '09:00', '10:00'), row(1, '10:00', '11:00')])).toEqual([]);
    expect(overlaps([row(1, '09:00', '10:00'), row(2, '09:00', '10:00')])).toEqual([]);
  });
});

describe('Program sekmesi', () => {
  it('bitiş başlangıçtan önceyse kaydetmez ve hata gösterir; çakışma uyarısı verir; geçerliyse PUT gönderir', async () => {
    const api = base()
      .get('/academician/courses/7', course())
      .put('/academician/courses/7/slots', [{ id: 1, dayOfWeek: 1, startTime: '09:00', endTime: '09:50', room: null }]);
    api.install();
    renderAcademician('/akademisyen/dersler/7');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Saat ekle' }));
    const end = screen.getByLabelText('Bitiş');
    fireEvent.change(end, { target: { value: '08:00' } });
    expect(await screen.findByText('Bitiş saati başlangıçtan sonra olmalı.')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Programı kaydet' }));
    expect(api.callsTo('PUT', '/academician/courses/7/slots')).toHaveLength(0);
    fireEvent.change(end, { target: { value: '09:50' } });
    await user.click(screen.getByRole('button', { name: 'Saat ekle' }));
    expect(await screen.findByText(/çakışan saatler var/)).toBeInTheDocument();
    await user.click(screen.getByLabelText('2. satırı kaldır'));
    await user.click(screen.getByRole('button', { name: 'Programı kaydet' }));
    await waitFor(() => expect(api.callsTo('PUT', '/academician/courses/7/slots')).toHaveLength(1));
    expect(api.callsTo('PUT', '/academician/courses/7/slots')[0].body).toEqual([{ dayOfWeek: 1, startTime: '09:00', endTime: '09:50' }]);
  });
});

describe('Dersler: oluşturma ve düzenleme', () => {
  it('yeni ders: zorunlu alanlar doğrulanır, istek gövdesi doğru, başarıda ders sayfasına gider', async () => {
    const api = base()
      .get('/academician/courses', [])
      .post('/academician/courses', ({ body }) => ({ ...course({ id: 9 }), ...(body as object) }))
      .get('/academician/courses/9', course({ id: 9 }));
    api.install();
    renderAcademician('/akademisyen/dersler?yeni=1');
    const user = userEvent.setup();
    const dlg = await screen.findByRole('dialog');
    await user.click(within(dlg).getByRole('button', { name: 'Dersi oluştur' }));
    expect(within(dlg).getAllByText('Bu alan zorunlu.').length).toBeGreaterThanOrEqual(2);
    expect(api.callsTo('POST', '/academician/courses')).toHaveLength(0);
    await user.type(within(dlg).getByLabelText(/Ders adı/), 'Algoritmalar');
    await waitFor(() => expect(within(dlg).getByRole('option', { name: 'Elektrik Mühendisliği' })).toBeInTheDocument());
    await user.selectOptions(within(dlg).getByLabelText(/Bölüm/), 'Bilgisayar Mühendisliği');
    await user.click(within(dlg).getByRole('button', { name: 'Dersi oluştur' }));
    await waitFor(() => expect(api.callsTo('POST', '/academician/courses')).toHaveLength(1));
    expect(api.callsTo('POST', '/academician/courses')[0].body).toMatchObject({ name: 'Algoritmalar', department: 'Bilgisayar Mühendisliği' });
    expect(await screen.findByRole('button', { name: 'Yoklama başlat' })).toBeInTheDocument();
  });

  it('düzenleme hata verirse pencere açık kalır ve girdi korunur', async () => {
    const api = base()
      .get('/academician/courses/7', course())
      .patch('/academician/courses/7', () => err(400, 'AC_FIELD_INVALID'));
    api.install();
    renderAcademician('/akademisyen/dersler/7');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Düzenle' }));
    const dlg = await screen.findByRole('dialog');
    const name = within(dlg).getByLabelText(/Ders adı/);
    await user.clear(name);
    await user.type(name, 'Yeni Ad');
    await user.click(within(dlg).getByRole('button', { name: 'Kaydet' }));
    expect(await within(dlg).findByRole('alert')).toHaveTextContent('geçersiz ya da eksik');
    expect(name).toHaveValue('Yeni Ad');
  });
});

describe('Öğrenci ekleme', () => {
  it('addEnrollmentsChunked 250 öğrenciyi 100+100+50 parça gönderir', async () => {
    const api = mockApi().post('/academician/courses/7/enrollments', ({ body }) => ({ added: (body as { studentIds: number[] }).studentIds.length }));
    api.install();
    setAcadTokens();
    const ids = Array.from({ length: 250 }, (_, i) => i + 1);
    const added = await addEnrollmentsChunked(7, ids);
    expect(ENROLL_CHUNK).toBe(100);
    expect(added).toBe(250);
    expect(api.calls.map((c) => (c.body as { studentIds: number[] }).studentIds.length)).toEqual([100, 100, 50]);
  });

  it('arama, çoklu seçim ve seçilenleri ekleme', async () => {
    const students = [
      { id: 21, displayName: 'Ali Aday', studentNo: '2024000021', faculty: null, department: 'Bilgisayar Mühendisliği', grade: '2' },
      { id: 22, displayName: 'Veli Aday', studentNo: '2024000022', faculty: null, department: 'Bilgisayar Mühendisliği', grade: '2' },
    ];
    const api = base()
      .get('/academician/courses/7', course())
      .get('/academician/courses/7/enrollments', [])
      .get('/academician/students', ({ url }) => ({ items: url.searchParams.get('q') === 'aday' ? students : [], nextCursor: null }))
      .post('/academician/courses/7/enrollments', ({ body }) => ({ added: (body as { studentIds: number[] }).studentIds.length }));
    api.install();
    renderAcademician('/akademisyen/dersler/7/ogrenciler/ekle');
    const user = userEvent.setup();
    expect(await screen.findByText('Arama yapın ya da süzgeç seçin')).toBeInTheDocument();
    await user.type(screen.getByRole('searchbox'), 'aday');
    await screen.findByText('Ali Aday', {}, { timeout: 4000 });
    await user.click(screen.getByRole('checkbox', { name: 'Ali Aday öğrencisini seç' }));
    await user.click(screen.getByRole('checkbox', { name: 'Veli Aday öğrencisini seç' }));
    await user.click(screen.getByRole('button', { name: 'Seçilen 2 öğrenciyi ekle' }));
    await waitFor(() => expect(api.callsTo('POST', '/academician/courses/7/enrollments')).toHaveLength(1));
    expect((api.callsTo('POST', '/academician/courses/7/enrollments')[0].body as { studentIds: number[] }).studentIds.sort()).toEqual([21, 22]);
  });

  it('toplu ekleme: onay penceresi sayıyı gösterir ve onaylanınca bulk çağrılır', async () => {
    const page = Array.from({ length: 50 }, (_, i) => ({ id: i + 1, displayName: `Ö${i}`, studentNo: null, faculty: null, department: 'Bilgisayar Mühendisliği', grade: '2' }));
    const api = base()
      .get('/academician/courses/7', course())
      .get('/academician/courses/7/enrollments', [])
      .get('/academician/students', ({ url }) => (url.searchParams.get('cursor') ? { items: page.slice(0, 20), nextCursor: null } : { items: page, nextCursor: 50 }))
      .post('/academician/courses/7/enrollments/bulk', { added: 70 });
    api.install();
    renderAcademician('/akademisyen/dersler/7/ogrenciler/ekle');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Toplu ekle…' }));
    const dlg = await screen.findByRole('dialog');
    expect(await within(dlg).findByText(/70 öğrenci derse eklenecek/)).toBeInTheDocument();
    await user.click(within(dlg).getByRole('button', { name: '70 öğrenciyi ekle' }));
    await waitFor(() => expect(api.callsTo('POST', '/academician/courses/7/enrollments/bulk')).toHaveLength(1));
    expect(api.callsTo('POST', '/academician/courses/7/enrollments/bulk')[0].body).toEqual({ department: 'Bilgisayar Mühendisliği', grade: '2' });
  });
});

const matrix = {
  sessions: [{ id: 5, lessonDate: '2026-11-10' }, { id: 6, lessonDate: '2026-11-12' }],
  students: [
    { studentId: 11, displayName: 'Ayşe Örnek', studentNo: '2024000011', marks: { '5': 'PRESENT_QR', '6': 'ABSENT' }, absentCount: 1, atRisk: false, overLimit: false },
    { studentId: 12, displayName: 'Mehmet Deneme', studentNo: '2024000012', marks: { '5': 'PRESENT_MANUAL', '6': 'REVOKED' }, absentCount: 1, atRisk: true, overLimit: false },
    { studentId: 13, displayName: 'Zeynep Test', studentNo: '2024000013', marks: { '5': 'REVOKED', '6': 'ABSENT' }, absentCount: 2, atRisk: true, overLimit: true },
  ],
  limit: { type: 'COUNT', value: 2 },
};

describe('Yoklamalar sekmesi: oturum ayrıntısı (kapalı oturum)', () => {
  const closed = {
    id: 5, courseId: 7, slotId: null, lessonDate: '2026-11-10', openedAt: '2026-11-10T08:00:00Z', expiresAt: '2026-11-10T11:00:00Z', closedAt: '2026-11-10T09:00:00Z',
    status: 'CLOSED', presentCount: 2, enrolledCount: 3,
    pendingScans: [{ studentId: 41, displayName: 'Kayıtsız Kişi', studentNo: null, faculty: null, department: null, grade: null, scannedAt: '2026-11-10T08:30:00Z' }],
  };
  it('dört durum görünür; kapalı oturumda geri yükle, kaldır (onaylı) çalışır; bekleyen karara bağlanır', async () => {
    const api = base()
      .get('/academician/courses/7', course())
      .get('/academician/courses/7/sessions', [closed])
      .get('/academician/sessions/5', closed)
      .get('/academician/courses/7/attendance', matrix)
      .put('/academician/sessions/5/records/:id', { id: 1 })
      .del('/academician/sessions/5/records/:id', undefined)
      .post('/academician/sessions/5/pending/41/accept', { id: 2 });
    api.install();
    renderAcademician('/akademisyen/dersler/7?sekme=yoklamalar');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Ayrıntı' }));
    const drawer = await screen.findByRole('dialog');
    expect(await within(drawer).findByText('Var (QR)')).toBeInTheDocument();
    expect(within(drawer).getByText('Var (elle)')).toBeInTheDocument();
    expect(within(drawer).getAllByText('Silindi').length).toBeGreaterThan(1);
    expect(within(drawer).getByText('Kayıtlı değil')).toBeInTheDocument();
    await user.click(within(drawer).getByRole('button', { name: 'Kayıtsız Kişi öğrencisini derse ekle ve var say' }));
    await waitFor(() => expect(api.callsTo('POST', '/academician/sessions/5/pending/41/accept')).toHaveLength(1));
    await user.click(within(drawer).getByRole('button', { name: 'Zeynep Test kaydını geri yükle' }));
    await waitFor(() => expect(api.callsTo('PUT', '/academician/sessions/5/records/13')).toHaveLength(1));
    await user.click(within(drawer).getByRole('button', { name: 'Ayşe Örnek yoklama kaydını kaldır' }));
    const confirm = await screen.findByRole('alertdialog');
    expect(api.callsTo('DELETE', '/academician/sessions/5/records/11')).toHaveLength(0);
    await user.click(within(confirm).getByRole('button', { name: 'Kaldır' }));
    await waitFor(() => expect(api.callsTo('DELETE', '/academician/sessions/5/records/11')).toHaveLength(1));
  });
});

describe('Devamsızlık sekmesi', () => {
  it('riske göre sıralar; sınırı aşan ve sınıra bir kalan metin + simgeyle belirtilir (yalnız renk değil)', async () => {
    const api = base()
      .get('/academician/courses/7', course({ limit: { type: 'COUNT', value: 2 }, absenceLimitType: 'COUNT', absenceLimitValue: 2 }))
      .get('/academician/courses/7/attendance', matrix);
    api.install();
    renderAcademician('/akademisyen/dersler/7?sekme=devamsizlik');
    const table = await screen.findByRole('table');
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows[0]).toHaveTextContent('Zeynep Test');
    expect(rows[0]).toHaveTextContent('Sınırı aştı');
    expect(rows[1]).toHaveTextContent('Mehmet Deneme');
    expect(rows[1]).toHaveTextContent('Sınıra bir kala');
    expect(rows[2]).toHaveTextContent('Normal');
    expect(rows[0].querySelector('svg')).not.toBeNull();
  });

  it('sınır türü/değeri doğrulanır ve PATCH gönderilir', async () => {
    const api = base()
      .get('/academician/courses/7', course())
      .get('/academician/courses/7/attendance', { ...matrix, limit: { type: null, value: null } })
      .patch('/academician/courses/7', course({ limit: { type: 'PERCENT', value: 30 } }));
    api.install();
    renderAcademician('/akademisyen/dersler/7?sekme=devamsizlik');
    const user = userEvent.setup();
    await user.selectOptions(await screen.findByLabelText('Sınır türü'), 'PERCENT');
    const v = screen.getByLabelText(/İzin verilen devamsızlık/);
    await user.type(v, '150');
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    expect(await screen.findByText('1 ile 100 arasında bir tam sayı girin.')).toBeInTheDocument();
    expect(api.callsTo('PATCH', '/academician/courses/7')).toHaveLength(0);
    await user.clear(v);
    await user.type(v, '30');
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(api.callsTo('PATCH', '/academician/courses/7')).toHaveLength(1));
    expect(api.callsTo('PATCH', '/academician/courses/7')[0].body).toEqual({ absenceLimitType: 'PERCENT', absenceLimitValue: 30 });
  });

  it('riskSort: aşan > bir kala > çok devamsız', () => {
    const sorted = [...(matrix.students as never[])].sort(riskSort) as { studentId: number }[];
    expect(sorted.map((x) => x.studentId)).toEqual([13, 12, 11]);
  });
});

describe('Dışa aktar', () => {
  it('CSV doğru uçtan indirilir ve dosya olarak kaydedilir', async () => {
    const names: string[] = [];
    URL.createObjectURL = vi.fn(() => 'blob:x');
    URL.revokeObjectURL = vi.fn();
    vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
      names.push(this.download);
    });
    const api = base()
      .get('/academician/courses/7', course())
      .get('/academician/courses/7/attendance.csv', () => new Response('Ad;Var', { status: 200, headers: { 'Content-Type': 'text/csv' } }));
    api.install();
    renderAcademician('/akademisyen/dersler/7?sekme=disa-aktar');
    await userEvent.setup().click(await screen.findByRole('button', { name: 'CSV indir' }));
    await waitFor(() => expect(names).toHaveLength(1));
    expect(api.callsTo('GET', '/academician/courses/7/attendance.csv')).toHaveLength(1);
    expect(names[0]).toBe('devamsizlik-bil101.csv');
    expect(csvFileName({ id: 1, code: null, name: 'Çok Özel Ders' })).toMatch(/^devamsizlik-.+\.csv$/);
  });
});
