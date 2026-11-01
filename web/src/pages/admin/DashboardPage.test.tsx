import { screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import DashboardPage from './DashboardPage';

const overview = {
  totalUsers: 1234,
  verifiedUsers: 1000,
  suspendedUsers: 3,
  newUsers: { today: 2, last7d: 20, last30d: 80 },
  activeUsers: { dau: 50, wau: 200, mau: 500 },
  stickiness: 0.1,
  messages: { total: 10, last24h: 1 },
  communities: { active: 4, pending: 2 },
  events: { upcoming: 3, pending: 0 },
  openReports: 5,
  openTickets: 0,
  newFeedback: 1,
  pushCampaignsSent30d: 2,
  bookmarks: 7,
  devices: { android: 8, ios: 2, web: 0 },
};

describe('DashboardPage: bugünün kısmi verisi', () => {
  afterEach(() => vi.useRealTimers());

  it('sabah 09:00 İstanbul: bugün dünün tamamıyla kıyaslanır, nötr tonda ve "şu ana kadar" diye yazılır', async () => {
    // 2026-11-02 06:00 UTC = 09:00 İstanbul; dün = 2026-11-01
    vi.useFakeTimers({ toFake: ['Date'], now: new Date('2026-11-02T06:00:00Z') });
    mockFetch((url) => {
      if (url.includes('/analytics/overview')) {
        return jsonResponse(200, { ...overview, activeUsers: { dau: 12, wau: 200, mau: 500 } });
      }
      if (url.includes('/analytics/registrations')) return jsonResponse(200, { points: [] });
      if (url.includes('/analytics/active-users')) {
        return jsonResponse(200, { points: [{ date: '2026-11-01', dau: 98 }], wau: 0, mau: 0 });
      }
      return jsonResponse(200, { items: [], NEWS: {}, MENU: {}, points: [] });
    });
    renderWithProviders(<DashboardPage />, { route: '/admin' });
    const hero = await screen.findByText(/şu ana kadar/);
    const insight = hero.closest('p')!;
    expect(insight).toHaveTextContent('Bugün şu ana kadar 12 kişi girdi, dün tüm gün 98 idi');
    expect(insight).toHaveAttribute('data-tone', 'info');
    expect(insight.textContent).not.toContain('%');
    // sayı kutusundaki fark rozeti de kırmızı/yeşil yargı taşımaz
    await waitFor(() => expect(document.querySelectorAll('[data-dir][data-good]').length).toBe(0));
    expect(screen.getAllByText(/dünün tamamına göre/).length).toBeGreaterThan(0);
  }, 30_000);
});

describe('DashboardPage', () => {
  it('bir kart hata verse de diğerleri çalışır ve dikkat paneli bağlantı verir', async () => {
    mockFetch((url) => {
      if (url.includes('/analytics/overview')) return jsonResponse(200, overview);
      if (url.includes('/analytics/registrations')) return jsonResponse(200, { points: [] });
      if (url.includes('/analytics/active-users')) return jsonResponse(200, { points: [], wau: 0, mau: 0 });
      if (url.includes('/status')) {
        return jsonResponse(200, {
          NEWS: { maintenance: true, lastSuccessAt: null },
          MENU: { maintenance: false, lastSuccessAt: '2026-10-01T10:00:00Z' },
        });
      }
      if (url.includes('/admin/audit')) return jsonResponse(500, { code: 'X', message: 'x' });
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderWithProviders(<DashboardPage />, { route: '/admin' });

    expect(await screen.findByText(/1\.234/)).toBeInTheDocument();
    const attention = screen.getByTestId('attention-panel');
    await waitFor(() => expect(within(attention).getByText('5 açık rapor')).toBeInTheDocument());
    expect(within(attention).getByText('5 açık rapor').closest('a')).toHaveAttribute('href', '/admin/reports');
    expect(within(attention).getByText('2 onay bekleyen topluluk')).toBeInTheDocument();
    expect(within(attention).queryByText(/destek talebi/)).not.toBeInTheDocument(); // 0 olanlar listelenmez

    const sources = screen.getByTestId('sources-panel');
    expect(await within(sources).findByText('Bakımda')).toBeInTheDocument();
    expect(within(sources).getByText('Çalışıyor')).toBeInTheDocument();

    // denetim kartı hata verir, sayfa çökmez
    expect(await within(screen.getByTestId('recent-audit')).findByRole('alert')).toBeInTheDocument();
  }, 30_000);

  it('genel bakış hata verirse tekrar dene gösterilir', async () => {
    mockFetch((url) =>
      url.includes('/analytics/overview') ? jsonResponse(500, { code: 'X', message: 'x' }) : jsonResponse(200, { items: [], NEWS: {}, points: [] }),
    );
    renderWithProviders(<DashboardPage />, { route: '/admin' });
    expect((await screen.findAllByRole('button', { name: 'Tekrar dene' })).length).toBeGreaterThan(0);
  });
});
