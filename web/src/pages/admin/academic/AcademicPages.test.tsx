import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import AcademicCalendarPage from './AcademicCalendarPage';

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
function setup() {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    const method = init.method ?? 'GET';
    const page = (item: unknown) => jsonResponse(200, { items: [item], page: 0, size: 20, total: 1 });
    if (url.includes('/admin/academic/events/import'))
      return jsonResponse(201, { created: 1, errors: [{ line: 2, message: 'Tarih geçersiz' }] });
    if (method === 'DELETE') return new Response(null, { status: 204 });
    if (method === 'POST' || method === 'PATCH') return jsonResponse(200, { ...EVENT, id: 1 });
    if (url.includes('/admin/academic/events')) return page(EVENT);
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

describe('Akademik takvim sayfası', () => {
  it('olayları listeler ve yayınla/sil çağrılarını gönderir', async () => {
    const calls = setup();
    renderWithProviders(<AcademicCalendarPage />, { route: '/admin/academic/calendar?view=list' });
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
    renderWithProviders(<AcademicCalendarPage />, { route: '/admin/academic/calendar?view=list' });
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
    renderWithProviders(<AcademicCalendarPage />, { route: '/admin/academic/calendar?view=list' });
    await screen.findByText('Ara sınav haftası');
    await userEvent.click(screen.getByRole('button', { name: 'Toplu içe aktar' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText('Satırlar'), 'VIZE;A;2026-11-09');
    await userEvent.click(within(dialog).getByRole('button', { name: 'İçe aktar' }));
    expect(await within(dialog).findByText(/Satır 2: Tarih geçersiz/)).toBeInTheDocument();
  });

  it('ay görünümü olayı ilgili günlere koyar', async () => {
    setup();
    renderWithProviders(<AcademicCalendarPage />, { route: '/admin/academic/calendar?view=list' });
    await screen.findByText('Ara sınav haftası');
    await userEvent.click(screen.getByRole('tab', { name: 'Takvim' }));
    expect(await screen.findByRole('grid')).toBeInTheDocument();
  });

  it('hata durumunda yeniden dene sunar', async () => {
    mockFetch(() => jsonResponse(500, { code: 'X', message: 'sunucu hatası' }));
    renderWithProviders(<AcademicCalendarPage />, { route: '/admin/academic/calendar?view=list' });
    expect(await screen.findByRole('alert')).toBeInTheDocument();
  });
});

