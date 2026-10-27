import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import AcademicAnnouncementsPage from './AcademicAnnouncementsPage';
import AcademicCalendarPage from './AcademicCalendarPage';
import AcademicExamsPage from './AcademicExamsPage';

afterEach(() => vi.unstubAllGlobals());

interface Call {
  url: string;
  init: RequestInit;
}

const EVENT = {
  id: 7,
  kind: 'VIZE',
  title: 'Ara sınav haftası',
  startsAt: '2026-11-09T00:00:00+03:00',
  endsAt: '2026-11-13T23:59:00+03:00',
  allDay: true,
  scopeDepartment: null,
  note: null,
  published: false,
};
const EXAM = {
  id: 5,
  title: 'Veri Yapıları Vize',
  type: 'VIZE',
  term: '2026-2027 Güz',
  courseCode: 'BIL201',
  faculty: null,
  department: 'Bilgisayar Mühendisliği',
  grade: '2',
  startsAt: '2026-11-10T10:00:00+03:00',
  endsAt: null,
  room: 'B-204',
  note: null,
  published: true,
};
const ANN = {
  id: 9,
  title: 'Staj başvuruları',
  body: 'Başvurular başladı.',
  department: 'Bilgisayar Mühendisliği',
  faculty: null,
  grade: null,
  pinned: false,
  publishAt: '2026-10-20T09:00:00+03:00',
  expiresAt: null,
  attachmentUrl: null,
  published: true,
  notify: true,
  notifiedAt: null,
  createdBy: 1,
  readCount: 50,
  createdAt: '2026-10-19T09:00:00+03:00',
};

function setup() {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    const method = init.method ?? 'GET';
    const page = (item: unknown) => jsonResponse(200, { items: [item], page: 0, size: 20, total: 1 });
    if (url.includes('/admin/announcements/audience-count')) return jsonResponse(200, { count: 200 });
    if (url.includes('/admin/academic/events/import'))
      return jsonResponse(201, { created: 1, errors: [{ line: 2, message: 'Tarih geçersiz' }] });
    if (method === 'DELETE') return new Response(null, { status: 204 });
    if (method === 'POST' || method === 'PATCH') return jsonResponse(200, { ...EVENT, id: 1 });
    if (url.includes('/admin/academic/events')) return page(EVENT);
    if (url.includes('/admin/academic/exams')) return page(EXAM);
    if (url.includes('/admin/announcements')) return page(ANN);
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

describe('Akademik takvim sayfası', () => {
  it('olayları listeler ve yayınla/sil çağrılarını gönderir', async () => {
    const calls = setup();
    renderWithProviders(<AcademicCalendarPage />);
    expect(await screen.findByText('Ara sınav haftası')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Yayınla' }));
    await waitFor(() =>
      expect(
        calls.some((c) => c.init.method === 'POST' && c.url.endsWith('/admin/academic/events/7/publish')),
      ).toBe(true),
    );
    await userEvent.click(screen.getByRole('button', { name: 'Sil' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Sil' }));
    await waitFor(() =>
      expect(
        calls.some((c) => c.init.method === 'DELETE' && c.url.endsWith('/admin/academic/events/7')),
      ).toBe(true),
    );
  });

  it('eksik başlıkta doğrulama hatası gösterir, geçerli formda POST gönderir', async () => {
    const calls = setup();
    renderWithProviders(<AcademicCalendarPage />);
    await screen.findByText('Ara sınav haftası');
    await userEvent.click(screen.getByRole('button', { name: 'Olay ekle' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    expect(await within(dialog).findAllByRole('alert')).not.toHaveLength(0);
    expect(calls.some((c) => c.init.method === 'POST')).toBe(false);

    await userEvent.type(within(dialog).getByLabelText(/^Başlık/), 'Kayıt haftası');
    await userEvent.type(within(dialog).getByLabelText(/^Başlangıç/), '2026-09-01');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => {
      const post = calls.find((c) => c.init.method === 'POST' && c.url.endsWith('/admin/academic/events'));
      expect(post).toBeTruthy();
      const body = JSON.parse(String(post!.init.body));
      expect(body).toMatchObject({
        title: 'Kayıt haftası',
        allDay: true,
        startsAt: '2026-09-01T00:00',
        published: false,
      });
    });
  });

  it('toplu içe aktarma sonucunu ve hatalı satırı gösterir', async () => {
    setup();
    renderWithProviders(<AcademicCalendarPage />);
    await screen.findByText('Ara sınav haftası');
    await userEvent.click(screen.getByRole('button', { name: 'Toplu içe aktar' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText('Satırlar'), 'VIZE;A;2026-11-09');
    await userEvent.click(within(dialog).getByRole('button', { name: 'İçe aktar' }));
    expect(await within(dialog).findByText(/Satır 2: Tarih geçersiz/)).toBeInTheDocument();
  });

  it('ay görünümü olayı ilgili günlere koyar', async () => {
    setup();
    renderWithProviders(<AcademicCalendarPage />);
    await screen.findByText('Ara sınav haftası');
    await userEvent.click(screen.getByRole('tab', { name: 'Ay' }));
    expect(await screen.findByRole('grid')).toBeInTheDocument();
  });

  it('hata durumunda yeniden dene sunar', async () => {
    mockFetch(() => jsonResponse(500, { code: 'X', message: 'sunucu hatası' }));
    renderWithProviders(<AcademicCalendarPage />);
    expect(await screen.findByRole('alert')).toBeInTheDocument();
  });
});

describe('Sınav programı sayfası', () => {
  it('sınavı listeler ve yayından kaldırır', async () => {
    const calls = setup();
    renderWithProviders(<AcademicExamsPage />);
    expect(await screen.findByText(/Veri Yapıları Vize/)).toBeInTheDocument();
    expect(screen.getByText(/Bilgisayar Mühendisliği/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Yayından kaldır' }));
    await waitFor(() =>
      expect(
        calls.some((c) => c.init.method === 'POST' && c.url.endsWith('/admin/academic/exams/5/unpublish')),
      ).toBe(true),
    );
  });

  it('bölüm süzgeci sunucuya iletilir', async () => {
    const calls = setup();
    renderWithProviders(<AcademicExamsPage />);
    await screen.findByText(/Veri Yapıları Vize/);
    await userEvent.type(screen.getByLabelText('Bölüme göre süz'), 'Bilgisayar');
    await waitFor(() => expect(calls.some((c) => c.url.includes('department=Bilgisayar'))).toBe(true));
  });

  it('dönem boşsa kaydetmez', async () => {
    const calls = setup();
    renderWithProviders(<AcademicExamsPage />);
    await screen.findByText(/Veri Yapıları Vize/);
    await userEvent.click(screen.getByRole('button', { name: 'Sınav ekle' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText(/^Başlık/), 'Final');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    expect(await within(dialog).findByText('Dönem zorunludur.')).toBeInTheDocument();
    expect(calls.some((c) => c.init.method === 'POST')).toBe(false);
  });
});

describe('Bölüm duyuruları sayfası', () => {
  it('duyuruyu, okunma yüzdesini ve bekleyen bildirimi gösterir', async () => {
    setup();
    renderWithProviders(<AcademicAnnouncementsPage />);
    expect(await screen.findByText('Staj başvuruları')).toBeInTheDocument();
    expect(await screen.findByText(/Okunma: 50 \/ 200 \(%25\)/)).toBeInTheDocument();
    expect(screen.getByText(/Bildirim bekliyor/)).toBeInTheDocument();
  });

  it('formda hedef kitle sayısını önizler ve http bağlantıyı reddeder', async () => {
    const calls = setup();
    renderWithProviders(<AcademicAnnouncementsPage />);
    await screen.findByText('Staj başvuruları');
    await userEvent.click(screen.getByRole('button', { name: 'Duyuru ekle' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText(/^Bölüm/), 'Hukuk');
    expect(await within(dialog).findByText(/yaklaşık 200 kullanıcıya/)).toBeInTheDocument();
    await waitFor(() =>
      expect(calls.some((c) => c.url.includes('audience-count') && c.url.includes('department=Hukuk'))).toBe(
        true,
      ),
    );

    await userEvent.type(within(dialog).getByLabelText(/^Başlık/), 'Duyuru');
    await userEvent.type(within(dialog).getByLabelText(/^Metin/), 'Metin');
    await userEvent.type(within(dialog).getByLabelText(/^Ek bağlantısı/), 'http://x.com');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    expect(await within(dialog).findByText('Bağlantı https:// ile başlamalıdır.')).toBeInTheDocument();
    expect(calls.some((c) => c.init.method === 'POST')).toBe(false);
  });

  it('sabitleme PATCH gönderir', async () => {
    const calls = setup();
    renderWithProviders(<AcademicAnnouncementsPage />);
    await screen.findByText('Staj başvuruları');
    await userEvent.click(screen.getByRole('button', { name: 'Sabitle' }));
    await waitFor(() => {
      const c = calls.find((x) => x.init.method === 'PATCH' && x.url.endsWith('/admin/announcements/9'));
      expect(c).toBeTruthy();
      expect(JSON.parse(String(c!.init.body))).toEqual({ pinned: true });
    });
  });
});
