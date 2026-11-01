// Genel bakış: sağlık şeridi, kitle çubukları, hafta karşılaştırması; Analitik: önceki dönem karşılaştırması ve aralık düzeltme.
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import AnalyticsPage from './AnalyticsPage';
import DashboardPage from './DashboardPage';

const overview = {
  totalUsers: 1000,
  verifiedUsers: 900,
  suspendedUsers: 0,
  newUsers: { today: 2, last7d: 20, last30d: 80 },
  activeUsers: { dau: 50, wau: 200, mau: 500 },
  stickiness: 0.1,
  messages: { total: 10, last24h: 1 },
  communities: { active: 4, pending: 0 },
  events: { upcoming: 3, pending: 0 },
  openReports: 0,
  openTickets: 0,
  newFeedback: 0,
  pushCampaignsSent30d: 2,
  bookmarks: 7,
  devices: { android: 8, ios: 2, web: 0 },
};
const ind = (status: string) => ({ status, value: null, threshold: null, message: null });
const okSources = { NEWS: { maintenance: false, lastSuccessAt: null }, MENU: { maintenance: false, lastSuccessAt: null } };

function dashboardApi(system: unknown, sources: unknown = okSources) {
  return (url: string) => {
    if (url.includes('/analytics/overview')) return jsonResponse(200, overview);
    if (url.includes('/analytics/registrations')) return jsonResponse(200, { points: [] });
    if (url.includes('/analytics/active-users')) return jsonResponse(200, { points: [], wau: 0, mau: 0 });
    if (url.includes('/system/overview')) return system === 'fail' ? jsonResponse(500, { code: 'X', message: 'x' }) : jsonResponse(200, system);
    if (url.includes('/status')) return jsonResponse(200, sources);
    return jsonResponse(200, { items: [], points: [] });
  };
}

describe('Genel bakış: sağlık şeridi', () => {
  afterEach(() => vi.useRealTimers());

  it('her şey yolundaysa yeşil onay cümlesi yazar', async () => {
    mockFetch(dashboardApi({ generatedAt: 'x', overall: 'OK', indicators: { db: ind('OK') } }));
    renderWithProviders(<DashboardPage />, { route: '/admin' });
    const strip = await screen.findByTestId('health-strip');
    await waitFor(() => expect(strip).toHaveAttribute('data-tone', 'good'));
    expect(within(strip).getByText(/Evet, her şey yolunda\. Sistem, haber ve yemek kaynakları sorunsuz çalışıyor\./)).toBeInTheDocument();
  });

  it('kritik gösterge ve bakımdaki kaynak: acil başlık, metinli rozetler ve sistem sayfası bağlantısı', async () => {
    mockFetch(
      dashboardApi(
        { generatedAt: 'x', overall: 'CRIT', indicators: { db: ind('CRIT') } },
        { NEWS: { maintenance: true, lastSuccessAt: null }, MENU: { maintenance: false, lastSuccessAt: null } },
      ),
    );
    renderWithProviders(<DashboardPage />, { route: '/admin' });
    const strip = await screen.findByTestId('health-strip');
    await waitFor(() => expect(strip).toHaveAttribute('data-tone', 'bad'));
    expect(within(strip).getByText('Acil: 2 konuya hemen bakılmalı.')).toBeInTheDocument();
    // renk tek başına değil: "Kritik" / "Uyarı" sözcüğü rozette yazılı
    expect(within(strip).getByText('Kritik')).toBeInTheDocument();
    expect(within(strip).getByText('Uyarı')).toBeInTheDocument();
    expect(within(strip).getByText('Haber ve duyurular bakımda')).toBeInTheDocument();
    expect(within(strip).getByRole('link', { name: 'Sistem durumunu aç' })).toHaveAttribute('href', '/admin/system');
  });

  it('sistem göstergeleri okunamazsa sessizce "yolunda" demez, not düşer', async () => {
    mockFetch(dashboardApi('fail'));
    renderWithProviders(<DashboardPage />, { route: '/admin' });
    expect(await screen.findByText(/Sistem göstergeleri şu an okunamadı/)).toBeInTheDocument();
  });

  it('kitle çubukları dört seviyeyi yüzdeyle yazar', async () => {
    mockFetch(dashboardApi({ generatedAt: 'x', overall: 'OK', indicators: {} }));
    renderWithProviders(<DashboardPage />, { route: '/admin' });
    const panel = await screen.findByTestId('audience-panel');
    const list = await within(panel).findByRole('list', { name: 'Kitlenin ne kadarı aktif?' });
    const rows = within(list).getAllByRole('listitem');
    expect(rows).toHaveLength(4);
    expect(rows[0]).toHaveTextContent('Kayıtlı üye');
    expect(rows[1]).toHaveTextContent('Bu ay giren');
    expect(rows[1]).toHaveTextContent('kayıtlıların yüzde 50 kadarı');
    expect(within(panel).getByText(/Kayıtlı 1\.000 kişinin yüzde 50 kadarı bu ay/)).toBeInTheDocument();
  });
});

describe('Analitik: önceki dönemle karşılaştırma', () => {
  const dau = (from: number) => ({
    points: Array.from({ length: 3 }, (_, i) => ({ date: `2026-10-0${i + 1}`, dau: from + i })),
    wau: 5,
    mau: 9,
  });

  it('varsayılan açık: önceki dönem istenir ve cümle yüzde fark yazar; kapatınca ikinci istek yapılmaz', async () => {
    const calls: string[] = [];
    mockFetch((url) => {
      calls.push(url);
      if (url.includes('/analytics/active-users')) {
        // önceki dönem (from 2026-09-28 civarı) 10, bu dönem 20 ortalama
        return jsonResponse(200, url.includes('from=2026-10-01') ? dau(19) : dau(9));
      }
      if (url.includes('/analytics/registrations')) return jsonResponse(200, { points: [] });
      if (url.includes('/analytics/content')) return jsonResponse(200, { daily: [], sources: {} });
      if (url.includes('/analytics/support')) {
        return jsonResponse(200, { tickets: { open: 0, answered: 0, closed: 0 }, avgFirstResponseMinutes: null, feedbackByCategory: [], feedbackByStatus: [] });
      }
      if (url.includes('/analytics/push')) return jsonResponse(200, { totals: { campaigns: 0, recipients: 0 }, recent: [] });
      return jsonResponse(200, overview);
    });
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=overview&from=2026-10-01&to=2026-10-03' });
    const cmp = (await screen.findByText(/Bu dönemde günde ortalama/)).closest('p');
    expect(cmp).toHaveTextContent(/önceki dönemde 10 idi/);
    expect(calls.some((u) => u.includes('active-users') && u.includes('from=2026-09-28'))).toBe(true);
    expect(screen.getByTestId('range-note')).toHaveTextContent('3 günlük dönem: 1 Eki - 3 Eki.');

    const before = calls.length;
    const user = userEvent.setup();
    await user.click(screen.getByRole('switch', { name: 'Önceki dönemle karşılaştır' }));
    await waitFor(() => expect(screen.getByText(/Günde ortalama 20 kişi girdi/)).toBeInTheDocument());
    expect(calls.slice(before).some((u) => u.includes('from=2026-09-28'))).toBe(false);
  });

  it('ters tarih aralığı düzeltilir ve kullanıcıya söylenir', async () => {
    mockFetch(() => jsonResponse(200, { points: [], wau: 0, mau: 0, ...overview }));
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=growth&from=2026-10-10&to=2026-10-01' });
    expect(await screen.findByText(/tarihler yer değiştirildi/)).toBeInTheDocument();
    expect(screen.getByTestId('range-note')).toHaveTextContent('10 günlük dönem');
  });
});
