import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../../test/fetchMock';
import { renderWithProviders } from '../../../../test/utils';
import AnalyticsPage from '../../AnalyticsPage';
import UsageTab from './UsageTab';

const RANGE = { from: '2026-10-01', to: '2026-10-03' };

const FIXTURES: Record<string, unknown> = {
  '/usage/summary': {
    from: RANGE.from,
    to: RANGE.to,
    totalSessions: 90,
    totalScreenViews: 600,
    avgDau: 42.5,
    avgReportingUsers: 40,
    avgSessionSeconds: 75,
    topScreen: 'home',
    topAction: 'news_open',
    daily: [
      { date: '2026-10-01', dau: 40, reportingUsers: 38, sessions: 30, screenViews: 200 },
      { date: '2026-10-02', dau: 45, reportingUsers: 42, sessions: 30, screenViews: 200 },
      { date: '2026-10-03', dau: 42, reportingUsers: 40, sessions: 30, screenViews: 200 },
    ],
  },
  '/usage/top-screens': {
    from: RANGE.from,
    to: RANGE.to,
    dates: ['2026-10-01', '2026-10-02', '2026-10-03'],
    totalViews: 600,
    items: [
      { screen: 'home', views: 300, userDays: 120, avgDailyUsers: 40, avgSeconds: 12, medianSeconds: 8, exitPercent: 10, trend: [90, 100, 110] },
      { screen: 'zzz_new_screen', views: 100, userDays: 50, avgDailyUsers: 16.7, avgSeconds: null, medianSeconds: null, exitPercent: 60, trend: [30, 30, 40] },
    ],
  },
  '/usage/top-actions': {
    from: RANGE.from,
    to: RANGE.to,
    dates: ['2026-10-01', '2026-10-02', '2026-10-03'],
    totalEvents: 500,
    avgReportingUsers: 40,
    items: [{ action: 'news_open', count: 400, userDays: 60, adoptionPercent: 50, trend: [100, 150, 150] }],
  },
  '/usage/flow': {
    from: RANGE.from,
    to: RANGE.to,
    totalTransitions: 200,
    edges: [{ from: 'home', to: 'news_list', count: 120 }],
  },
  '/usage/hourly': {
    from: RANGE.from,
    to: RANGE.to,
    totalSessions: 90,
    totalViews: 600,
    peak: { dow: 5, hour: 13, sessions: 40 },
    cells: [{ dow: 5, hour: 13, sessions: 40, views: 200 }],
  },
  '/usage/segments': {
    from: RANGE.from,
    to: RANGE.to,
    kAnonymity: 10,
    platforms: [
      { key: 'android', userDays: 70, percent: 70 },
      { key: 'ios', userDays: 30, percent: 30 },
    ],
    versions: [{ key: '2.0.6', userDays: 100, percent: 100 }],
    faculties: [{ key: 'Mühendislik Fakültesi', userDays: 80, percent: 80 }, { key: 'other', userDays: 20, percent: 20 }],
    departments: [],
  },
  '/usage/features': {
    asOf: '2026-10-02',
    mau: 100,
    reportingUsers: 80,
    items: [
      { feature: 'news', users: 60, percentOfMau: 60 },
      { feature: 'map', users: 0, percentOfMau: 0 },
    ],
  },
};

function serve(overrides: Record<string, () => Response> = {}) {
  return mockFetch((url) => {
    for (const [path, body] of Object.entries(FIXTURES)) {
      if (url.includes(path)) return overrides[path]?.() ?? jsonResponse(200, body);
    }
    return jsonResponse(404, { code: 'X', message: 'x' });
  });
}

afterEach(() => vi.unstubAllGlobals());

describe('UsageTab', () => {
  it('vurguları, sayfa listesini, akışı, ısı haritasını ve özellik tablosunu gösterir', async () => {
    serve();
    renderWithProviders(<UsageTab range={RANGE} />);

    // vurgular + Türkçe ad eşleme
    expect(await screen.findByText('En çok gezilen sayfa')).toBeInTheDocument();
    expect(await screen.findByText('1 dk 15 sn')).toBeInTheDocument();
    expect(screen.getAllByText('Ana sayfa').length).toBeGreaterThan(0);

    // sayfa listesi: bilinmeyen anahtar teknik adıyla görünür; rozetler
    const list = await screen.findByRole('list', { name: 'En çok gezilen sayfalar' });
    expect(within(list).getAllByRole('listitem')).toHaveLength(2);
    expect(within(list).getByText('zzz_new_screen')).toBeInTheDocument();
    expect(within(list).getByText('Çıkış %60')).toBeInTheDocument();
    expect(within(list).getByText('Ort. 12 sn')).toBeInTheDocument();

    // akış cümlesi ve satırı
    expect(await screen.findByLabelText(/Ana sayfa sayfasından Haber listesi sayfasına 120 geçiş/)).toBeInTheDocument();

    // ısı haritası: 7 gün satırı + başlık satırı
    const heat = await screen.findByRole('table', { name: 'Hangi gün hangi saatte yoğunluk var?' });
    expect(within(heat).getAllByRole('row')).toHaveLength(8);
    expect(screen.getByText(/En yoğun zaman Cuma günü saat 13:00/)).toBeInTheDocument();

    // özellik tablosu
    expect(await screen.findByText('Haber ve duyurular')).toBeInTheDocument();
    expect(screen.getByText('Kampüs haritası')).toBeInTheDocument();

    // gizlilik: k eşiği metni
    expect(screen.getAllByText(/10 kişiden küçük gruplar/).length).toBeGreaterThan(0);
  });

  it('veri yoksa tek bir boş durum gösterir ve CSV pasiftir', async () => {
    mockFetch((url) => {
      if (url.includes('/usage/summary')) {
        return jsonResponse(200, { ...FIXTURES['/usage/summary'] as object, totalSessions: 0, totalScreenViews: 0, topScreen: null, topAction: null, avgSessionSeconds: null, daily: [] });
      }
      if (url.includes('/usage/top-screens')) return jsonResponse(200, { from: 'a', to: 'b', dates: [], totalViews: 0, items: [] });
      if (url.includes('/usage/top-actions')) return jsonResponse(200, { from: 'a', to: 'b', dates: [], totalEvents: 0, avgReportingUsers: 0, items: [] });
      if (url.includes('/usage/flow')) return jsonResponse(200, { from: 'a', to: 'b', totalTransitions: 0, edges: [] });
      if (url.includes('/usage/hourly')) return jsonResponse(200, { from: 'a', to: 'b', totalSessions: 0, totalViews: 0, peak: null, cells: [] });
      if (url.includes('/usage/segments')) return jsonResponse(200, { from: 'a', to: 'b', kAnonymity: 10, platforms: [], versions: [], faculties: [], departments: [] });
      return jsonResponse(200, { asOf: null, mau: 0, reportingUsers: 0, items: [] });
    });
    renderWithProviders(<UsageTab range={RANGE} />);
    expect((await screen.findAllByText('Bu aralıkta henüz kullanım verisi yok')).length).toBeGreaterThan(0);
    expect(screen.getByRole('button', { name: 'CSV indir' })).toBeDisabled();
    expect(await screen.findByText('Özellik tablosu gece hesaplanır; ilk hesap yarın görünür.')).toBeInTheDocument();
  });

  it('bir kart hata verirse yalnız o kartta "Tekrar dene" çıkar, diğerleri çalışır', async () => {
    serve({ '/usage/flow': () => jsonResponse(500, { code: 'X', message: 'x' }) });
    renderWithProviders(<UsageTab range={RANGE} />);
    expect(await screen.findByRole('button', { name: 'Tekrar dene' })).toBeInTheDocument();
    expect(await screen.findByText('Haber ve duyurular')).toBeInTheDocument();
  });

  it('CSV indirme: formül karakteriyle başlayan değerler tırnaklanır', async () => {
    serve();
    let blobText = '';
    const created: Blob[] = [];
    vi.stubGlobal('URL', {
      ...URL,
      createObjectURL: (b: Blob) => {
        created.push(b);
        return 'blob:test';
      },
      revokeObjectURL: () => undefined,
    });
    renderWithProviders(<UsageTab range={RANGE} />);
    const btn = await screen.findByRole('button', { name: 'CSV indir' });
    await waitFor(() => expect(btn).toBeEnabled());
    // tüm sorgular dolsun
    await screen.findByText('Haber ve duyurular');
    await userEvent.setup().click(btn);
    expect(created).toHaveLength(1);
    blobText = await new Promise<string>((res) => {
      const fr = new FileReader();
      fr.onload = () => res(String(fr.result));
      fr.readAsText(created[0]);
    });
    expect(blobText).toContain('bolum,oge,olcu,deger');
    expect(blobText).toContain('ekran,Ana sayfa,goruntuleme,300');
    expect(blobText).toContain('eylem,Haber açıldı,sayi,400');
  });
});

describe('AnalyticsPage kullanım sekmesi', () => {
  it('?tab=usage sekmeyi açar ve karşılaştırma anahtarını gizler', async () => {
    serve();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=usage&from=2026-10-01&to=2026-10-03' });
    expect(screen.getByRole('tab', { name: 'Kullanım' })).toHaveAttribute('aria-selected', 'true');
    expect(await screen.findByTestId('usage-tab')).toBeInTheDocument();
    expect(screen.queryByRole('switch')).not.toBeInTheDocument();
  });
});
