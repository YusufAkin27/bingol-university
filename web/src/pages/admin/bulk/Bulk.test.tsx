import { act, renderHook, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import AcademicCalendarPage from '../academic/AcademicCalendarPage';
import MenuAdminPage from '../MenuAdminPage';
import NewsAdminPage from '../NewsAdminPage';
import PendingUsersPage from '../PendingUsersPage';
import SourcesPage from '../SourcesPage';
import { useIdSelection } from './BulkParts';

interface Call {
  url: string;
  init: RequestInit;
}

const REASON = 'Toplu inceleme sonucu';

beforeEach(() => {
  // CSV indirme (downloadBlob) jsdom'da yoktur
  URL.createObjectURL = vi.fn(() => 'blob:x');
  URL.revokeObjectURL = vi.fn();
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => undefined);
});
afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const body = (c: Call | undefined) => JSON.parse(String(c?.init.body ?? '{}')) as Record<string, unknown>;
const report = (over: Record<string, unknown> = {}) => ({
  requested: 3,
  done: 1,
  skipped: 1,
  failed: 1,
  results: [
    { id: '1', status: 'DONE', code: null },
    { id: '2', status: 'SKIPPED', code: 'ALREADY_DONE' },
    { id: '3', status: 'FAILED', code: 'INTERNAL_ERROR' },
  ],
  ...over,
});

describe('useIdSelection', () => {
  it('sınırı aşmaz ve resetKey değişince sıfırlanır', () => {
    const { result, rerender } = renderHook(({ k }) => useIdSelection<number>(k, 2), { initialProps: { k: 'a' } });
    act(() => result.current.setAll([1, 2, 3], true));
    expect([...result.current.selected]).toEqual([1, 2]);
    expect(result.current.atMax).toBe(true);
    act(() => result.current.toggle(3, true));
    expect(result.current.has(3)).toBe(false);
    rerender({ k: 'b' });
    expect(result.current.count).toBe(0);
  });
});

describe('Haber: toplu gizle ve CSV', () => {
  const rows = [
    { id: 1, type: 'HABER', title: 'Birinci haber', summary: null, url: 'https://x/1', imageUrl: null, publishedDate: '2026-10-01', hidden: false },
    { id: 2, type: 'DUYURU', title: 'İkinci duyuru', summary: null, url: 'https://x/2', imageUrl: null, publishedDate: '2026-10-02', hidden: false },
  ];

  function setup() {
    const calls: Call[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/admin/news/bulk')) return jsonResponse(200, report());
      if (url.includes('/admin/news/export.csv')) return new Response('id,type\r\n', { status: 200 });
      if (url.includes('/admin/news')) return jsonResponse(200, { items: rows, page: 0, totalPages: 1, totalItems: 2 });
      if (url.includes('/status')) return jsonResponse(200, {});
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    return calls;
  }

  it('seçimle çubuk açılır; sebepsiz onaylanmaz; gönderimde ids + sebep gider ve rapor gösterilir', async () => {
    const calls = setup();
    renderWithProviders(<NewsAdminPage />);
    await screen.findByText('Birinci haber');
    expect(screen.queryByRole('region', { name: /Toplu işlem/i })).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('checkbox', { name: 'Görünen tüm satırları seç' }));
    expect(await screen.findByText('2 satır seçili')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Seçilenleri gizle' }));
    const dialog = await screen.findByRole('dialog');
    const confirm = within(dialog).getByRole('button', { name: 'Seçilenleri gizle' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox', { name: /Sebep/ }), REASON);
    expect(confirm).toBeEnabled();
    await userEvent.click(confirm);

    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/admin/news/bulk'))).toBe(true));
    const sent = body(calls.find((c) => c.url.endsWith('/admin/news/bulk')));
    expect(sent).toMatchObject({ action: 'HIDE', ids: [1, 2], reason: REASON });
    const rep = await screen.findByTestId('bulk-report');
    expect(rep).toHaveTextContent('1 tamamlandı');
    expect(rep).toHaveTextContent('1 atlandı');
    expect(rep).toHaveTextContent('Zaten istenen durumda');
    expect(rep).toHaveTextContent('Hata (Beklenmeyen hata)');
    // seçim sıfırlandı
    expect(screen.queryByText('2 satır seçili')).not.toBeInTheDocument();
  });

  it('CSV düğmesi süzgeçle export.csv ister', async () => {
    const calls = setup();
    renderWithProviders(<NewsAdminPage />);
    await screen.findByText('Birinci haber');
    await userEvent.click(screen.getByRole('button', { name: 'CSV indir' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('/admin/news/export.csv'))).toBe(true));
  });
});

describe('Akademik takvim: toplu yayınla / sil', () => {
  const ev = (id: number) => ({
    id,
    kind: 'VIZE',
    title: `Olay ${id}`,
    startsAt: '2026-11-09T00:00:00+03:00',
    endsAt: null,
    allDay: true,
    scopeDepartment: null,
    note: null,
    published: false,
  });

  function setup() {
    const calls: Call[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/admin/academic/bulk')) return jsonResponse(200, report());
      if (url.includes('/admin/academic/export.csv')) return new Response('id\r\n', { status: 200 });
      if (url.includes('/admin/academic/events'))
        return jsonResponse(200, { items: [ev(7), ev(8)], page: 0, size: 20, total: 2 });
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    return calls;
  }

  it('yayınla: sebep ister, entity CALENDAR + ids gönderir', async () => {
    const calls = setup();
    renderWithProviders(<AcademicCalendarPage />);
    await screen.findByText('Olay 7');
    await userEvent.click(screen.getByRole('checkbox', { name: 'Seç: Olay 7' }));
    await userEvent.click(screen.getByRole('checkbox', { name: 'Seç: Olay 8' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Seçilenleri yayınla' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByRole('textbox', { name: /Sebep/ }), REASON);
    await userEvent.click(within(dialog).getByRole('button', { name: 'Seçilenleri yayınla' }));
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/admin/academic/bulk'))).toBe(true));
    expect(body(calls.find((c) => c.url.endsWith('/admin/academic/bulk')))).toMatchObject({
      entity: 'CALENDAR',
      action: 'PUBLISH',
      ids: [7, 8],
      reason: REASON,
    });
    expect(await screen.findByTestId('bulk-report')).toBeInTheDocument();
  });

  it('sil: yazarak onay (SİL) olmadan düğme kapalıdır', async () => {
    const calls = setup();
    renderWithProviders(<AcademicCalendarPage />);
    await screen.findByText('Olay 7');
    await userEvent.click(screen.getByRole('checkbox', { name: 'Seç: Olay 7' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Seçilenleri sil' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('kalıcı olarak silinir');
    await userEvent.type(within(dialog).getByRole('textbox', { name: /Sebep/ }), REASON);
    const confirm = within(dialog).getByRole('button', { name: 'Seçilenleri sil' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox', { name: /Onay metni/ }), 'sil');
    expect(confirm).toBeEnabled();
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/admin/academic/bulk'))).toBe(true));
    expect(body(calls.find((c) => c.url.endsWith('/admin/academic/bulk')))).toMatchObject({
      action: 'DELETE',
      ids: [7],
    });
  });

  it('CSV entity=CALENDAR ile istenir', async () => {
    const calls = setup();
    renderWithProviders(<AcademicCalendarPage />);
    await screen.findByText('Olay 7');
    await userEvent.click(screen.getByRole('button', { name: 'CSV indir' }));
    await waitFor(() =>
      expect(calls.some((c) => c.url.includes('/admin/academic/export.csv') && c.url.includes('entity=CALENDAR'))).toBe(true),
    );
  });
});

describe('Menü: toplu silme', () => {
  const days = [
    { date: '2026-02-03', items: ['Çorba'], imageUrl: '/files/menu/a.jpg' },
    { date: '2026-02-04', items: ['Makarna'], imageUrl: null },
  ];

  it('seçilen günleri sebep + yazarak onayla siler; CSV from/to ile gider', async () => {
    const calls: Call[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/admin/menu/bulk-delete')) return jsonResponse(200, report({ requested: 2, done: 2, skipped: 0, failed: 0, results: [] }));
      if (url.includes('/admin/menu/export.csv')) return new Response('date\r\n', { status: 200 });
      if (url.includes('/admin/menu')) return jsonResponse(200, days);
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<MenuAdminPage />);
    await screen.findAllByTestId('menu-row');
    await userEvent.click(screen.getByRole('checkbox', { name: 'Aydaki tüm günleri seç' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Seçilen günleri sil' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('Kaynak site aylık senkronda');
    await userEvent.type(within(dialog).getByRole('textbox', { name: /Sebep/ }), REASON);
    const confirm = within(dialog).getByRole('button', { name: 'Seçilen günleri sil' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox', { name: /Onay metni/ }), 'SİL');
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/admin/menu/bulk-delete'))).toBe(true));
    expect(body(calls.find((c) => c.url.endsWith('/admin/menu/bulk-delete')))).toMatchObject({
      dates: ['2026-02-03', '2026-02-04'],
      reason: REASON,
    });

    await userEvent.click(screen.getByRole('button', { name: 'CSV indir' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('/admin/menu/export.csv?from='))).toBe(true));
  });
});

describe('Bekleyen kayıtlar: toplu iptal ve CSV', () => {
  const entry = (email: string) => ({
    email,
    displayName: 'Ad',
    faculty: null,
    department: null,
    grade: null,
    createdAtEpochSec: 1_790_000_000,
    remainingSeconds: 3600,
    resendCount: 0,
  });

  it('seçilenleri iptal eder (e-postalar gövdede), CSV maskeli ucu ister', async () => {
    const calls: Call[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/bulk-cancel')) return jsonResponse(200, report({ results: [] }));
      if (url.includes('/export.csv')) return new Response('emailMasked\r\n', { status: 200 });
      if (url.includes('/admin/pending-registrations'))
        return jsonResponse(200, { items: [entry('a@bingol.edu.tr'), entry('b@bingol.edu.tr')], nextCursor: null });
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<PendingUsersPage />);
    await screen.findByText('a@bingol.edu.tr');
    await userEvent.click(screen.getByRole('checkbox', { name: /tüm|Tümünü/i }));
    await userEvent.click(await screen.findByRole('button', { name: 'Seçilenleri iptal et' }));
    const dialog = await screen.findByRole('alertdialog');
    await userEvent.type(within(dialog).getByRole('textbox', { name: /Sebep/ }), REASON);
    await userEvent.click(within(dialog).getByRole('button', { name: 'Seçilenleri iptal et' }));
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/admin/pending-registrations/bulk-cancel'))).toBe(true));
    expect(body(calls.find((c) => c.url.endsWith('/bulk-cancel')))).toMatchObject({
      emails: ['a@bingol.edu.tr', 'b@bingol.edu.tr'],
      reason: REASON,
    });

    await userEvent.click(screen.getByRole('button', { name: 'CSV indir' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('/pending-registrations/export.csv'))).toBe(true));
  });
});

describe('Kaynak durumu sayfası', () => {
  const status = {
    news: {
      maintenance: true,
      lastSuccess: '2026-10-27T21:00:00Z',
      lastAttempt: '2026-10-28T21:00:00Z',
      message: 'Kaynak site yapısı değişti',
      itemsLast7d: 12,
      total: 300,
      hidden: 4,
      byType: { HABER: 100, DUYURU: 150, ETKINLIK: 50 },
    },
    menu: {
      maintenance: false,
      lastSuccess: null,
      lastAttempt: null,
      message: null,
      totalDays: 30,
      upcomingDays: 10,
      withImage: 3,
    },
    syncPerHour: 3,
  };

  function setup(syncResponse: () => Response) {
    const calls: Call[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/admin/sources/sync')) return syncResponse();
      if (url.includes('/admin/sources/status')) return jsonResponse(200, status);
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    return calls;
  }

  it('iki kaynağın durumunu ve scraper kuralını gösterir', async () => {
    setup(() => jsonResponse(200, {}));
    renderWithProviders(<SourcesPage />);
    expect(await screen.findByText('Haber, duyuru ve etkinlik')).toBeInTheDocument();
    expect(screen.getByText('Bakımda')).toBeInTheDocument();
    expect(screen.getByText('Kaynak site yapısı değişti')).toBeInTheDocument();
    expect(screen.getByText('Yemek listesi')).toBeInTheDocument();
    expect(screen.getByText(/zamanlayıcı istek atar/, { selector: 'p' })).toBeInTheDocument();
    expect(screen.getByText(/saatte en çok 3 kez/, { selector: 'p' })).toBeInTheDocument();
  });

  it('elle senkron: açıklamalı onay + sebep ister, source ve sebep gönderir', async () => {
    const calls = setup(() => jsonResponse(200, { source: 'NEWS', changed: 2, detail: { HABER: 2, DUYURU: 0 } }));
    renderWithProviders(<SourcesPage />);
    await screen.findByText('Haber, duyuru ve etkinlik');
    await userEvent.click(screen.getAllByRole('button', { name: 'Şimdi senkronize et' })[0]);
    const dialog = await screen.findByRole('dialog');
    expect(dialog).toHaveTextContent('Kaynak siteye istek atar');
    expect(dialog).toHaveTextContent('bu elle tetikleme bir istisnadır');
    expect(dialog).toHaveTextContent('saatte en çok 3 kez');
    const confirm = within(dialog).getByRole('button', { name: 'Şimdi senkronize et' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole('textbox', { name: /Sebep/ }), 'Acil duyuru çıktı');
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/admin/sources/sync'))).toBe(true));
    expect(body(calls.find((c) => c.url.endsWith('/admin/sources/sync')))).toMatchObject({
      source: 'NEWS',
      reason: 'Acil duyuru çıktı',
    });
  });

  it('saatlik sınır dolunca (429) bekleme mesajı gösterir ve diyalog açık kalır', async () => {
    setup(() => new Response(JSON.stringify({ code: 'RATE_LIMITED', message: 'x' }), {
      status: 429,
      headers: { 'Content-Type': 'application/json', 'Retry-After': '120' },
    }));
    renderWithProviders(<SourcesPage />);
    await screen.findByText('Haber, duyuru ve etkinlik');
    await userEvent.click(screen.getAllByRole('button', { name: 'Şimdi senkronize et' })[1]);
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByRole('textbox', { name: /Sebep/ }), 'Yeni ay menüsü');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Şimdi senkronize et' }));
    expect((await screen.findAllByText(/120 saniye sonra yeniden deneyin/)).length).toBeGreaterThan(0);
    expect(screen.getByRole('dialog')).toBeInTheDocument();
  });
});
