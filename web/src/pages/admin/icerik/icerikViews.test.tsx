import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import AcademicCalendarPage from '../academic/AcademicCalendarPage';
import MenuAdminPage from '../MenuAdminPage';
import NewsAdminPage from '../NewsAdminPage';
import SourcesPage from '../SourcesPage';

afterEach(() => vi.unstubAllGlobals());

const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const plus = (n: number) => {
  const d = new Date();
  d.setDate(d.getDate() + n);
  return d;
};

describe('Akademik takvim çizelgesi', () => {
  const ev = (id: number, kind: string, title: string, from: number, to: number | null, published = true) => ({
    id,
    kind,
    title,
    startsAt: `${iso(plus(from))}T00:00:00+03:00`,
    endsAt: to === null ? null : `${iso(plus(to))}T23:59:00+03:00`,
    allDay: true,
    scopeDepartment: null,
    note: null,
    published,
  });

  it('varsayılan görünüm çizelgedir: şerit, yaklaşan olaylar ve taslak uyarısı', async () => {
    const items = [ev(1, 'VIZE', 'Ara sınav haftası', 2, 6), ev(2, 'FINAL', 'Final sınavları', 20, 30, false)];
    mockFetch((url) =>
      url.includes('/admin/academic/events')
        ? jsonResponse(200, { items, page: 0, size: 100, total: items.length })
        : jsonResponse(404, { code: 'X', message: 'x' }),
    );
    renderWithProviders(<AcademicCalendarPage />, { route: '/admin/academic/calendar' });
    const tl = await screen.findByTestId('cal-timeline');
    await waitFor(() => expect(within(tl).getAllByText(/Ara sınav haftası/).length).toBeGreaterThan(0));
    expect(within(tl).getByRole('heading', { name: 'Yaklaşan olaylar' })).toBeInTheDocument();
    // tür şeritleri ve olay düğmeleri (erişilebilir ad: başlık, tür, tarih)
    expect(within(tl).getByRole('button', { name: /^Ara sınav haftası, Vize/ })).toBeInTheDocument();
    expect(within(tl).getByRole('button', { name: /^Final sınavları, Final.*Taslak/ })).toBeInTheDocument();
    // yorum cümleleri: sıradaki olay + taslak uyarısı
    expect(within(tl).getByText(/Sıradaki olay/)).toBeInTheDocument();
    expect(within(tl).getByText(/1 yaklaşan olay taslakta/)).toBeInTheDocument();
  });

  it('olay yoksa yönlendirici boş durum gösterir', async () => {
    mockFetch(() => jsonResponse(200, { items: [], page: 0, size: 100, total: 0 }));
    renderWithProviders(<AcademicCalendarPage />, { route: '/admin/academic/calendar' });
    expect(await screen.findByText('Bu aylarda takvim olayı yok')).toBeInTheDocument();
    expect(screen.getByText(/planlanmış bir olay yok/)).toBeInTheDocument();
  });

  it('sunucu hatasında uyarı gösterir', async () => {
    mockFetch(() => jsonResponse(500, { code: 'X', message: 'sunucu hatası' }));
    renderWithProviders(<AcademicCalendarPage />, { route: '/admin/academic/calendar' });
    expect(await screen.findByRole('alert')).toBeInTheDocument();
  });

  it('çizelgedeki olaya tıklayınca düzenleme penceresi açılır', async () => {
    const items = [ev(1, 'VIZE', 'Ara sınav haftası', 2, 6)];
    mockFetch(() => jsonResponse(200, { items, page: 0, size: 100, total: 1 }));
    renderWithProviders(<AcademicCalendarPage />, { route: '/admin/academic/calendar' });
    const btn = await screen.findByRole('button', { name: /^Ara sınav haftası, Vize/ });
    await userEvent.click(btn);
    expect(await screen.findByRole('dialog')).toBeInTheDocument();
  });
});

describe('Menü kalori grafiği', () => {
  it('her gün için çubuk çizer; eksik gün çubuğu uyarı metni taşır', async () => {
    const month = iso(new Date()).slice(0, 7);
    const days = [
      {
        date: `${month}-03`,
        items: ['Çorba', 'Pilav'],
        imageUrl: null,
        dishes: [
          { name: 'Çorba', kcal: 100 },
          { name: 'Pilav', kcal: 200 },
        ],
      },
      {
        date: `${month}-04`,
        items: ['Çorba', 'Pilav'],
        imageUrl: null,
        dishes: [
          { name: 'Çorba', kcal: 100 },
          { name: 'Pilav', kcal: null },
        ],
      },
      { date: `${month}-05`, items: ['Makarna'], imageUrl: null, dishes: [{ name: 'Makarna', kcal: null }] },
    ];
    mockFetch((url) => (url.includes('/admin/menu') ? jsonResponse(200, days) : jsonResponse(404, { code: 'X', message: 'x' })));
    renderWithProviders(<MenuAdminPage />);
    const chart = await screen.findByTestId('menu-kcal-chart');
    expect(within(chart).getAllByRole('button', { name: /Günü aç ve kaloriyi düzenle/ })).toHaveLength(3);
    expect(within(chart).getByRole('button', { name: /300 kcal.*Günü aç/ })).toBeInTheDocument();
    expect(within(chart).getByRole('button', { name: /en az 100 kcal, 1 yemeğin kalorisi eksik/ })).toBeInTheDocument();
    expect(within(chart).getByRole('button', { name: /kalori girilmemiş/ })).toBeInTheDocument();
    expect(within(chart).getByText(/2 yemeğin kalorisi eksik/)).toBeInTheDocument();
    expect(within(chart).getByRole('button', { name: 'İlk eksik güne git' })).toBeInTheDocument();
  });
});

describe('Kaynak durumu ızgarası', () => {
  const unit = (i: number, over: object = {}) => ({
    code: `u${i}`,
    name: `Birim ${i}`,
    kind: 'FACULTY',
    baseUrl: `https://u${i}.bingol.edu.tr`,
    enabled: true,
    graduate: false,
    facultyKeys: [],
    departmentCount: 1,
    announcementCount: i,
    lastSuccessAt: new Date(Date.now() - 3_600_000).toISOString(),
    lastAttemptAt: null,
    lastMessage: null,
    maintenance: false,
    ...over,
  });
  const status = {
    news: { maintenance: false, lastSuccess: new Date().toISOString(), lastAttempt: null, message: null, itemsLast7d: 3, total: 10, hidden: 0, byType: { HABER: 10 } },
    menu: { maintenance: false, lastSuccess: new Date().toISOString(), lastAttempt: null, message: null, totalDays: 30, upcomingDays: 20, withImage: 5 },
    syncPerHour: 3,
  };

  it('ana kaynakları ve birim sitelerini durumlarıyla gösterir, sorunluyu üste alır', async () => {
    mockFetch((url) => {
      if (url.includes('/admin/sources/status')) return jsonResponse(200, status);
      if (url.includes('/admin/unit-news/sources'))
        return jsonResponse(200, [unit(1), unit(2, { maintenance: true }), unit(3, { lastSuccessAt: null }), unit(4, { enabled: false })]);
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<SourcesPage />);
    const grid = await screen.findByTestId('source-grid');
    await waitFor(() => expect(within(grid).getByText('Birim 2')).toBeInTheDocument());
    const items = within(grid).getAllByRole('listitem').filter((li) => li.hasAttribute('data-state'));
    expect(items).toHaveLength(6); // 2 ana kaynak + 4 birim
    const unitStates = items.slice(2).map((li) => li.getAttribute('data-state'));
    expect(unitStates).toEqual(['maintenance', 'never', 'ok', 'disabled']);
    expect(within(grid).getByText(/ilginizi bekliyor/)).toBeInTheDocument();
  });

  it('birim siteleri yüklenemezse ana kaynaklar yine görünür', async () => {
    mockFetch((url) => {
      if (url.includes('/admin/sources/status')) return jsonResponse(200, status);
      return jsonResponse(500, { code: 'X', message: 'hata' });
    });
    renderWithProviders(<SourcesPage />);
    const grid = await screen.findByTestId('source-grid');
    expect(within(grid).getByText('Yemek listesi')).toBeInTheDocument();
    expect(await within(grid).findByRole('alert')).toBeInTheDocument();
  });
});

describe('Haber yönetimi dağılımı', () => {
  it('tür dağılımını ve genel sayıları gösterir', async () => {
    mockFetch((url) => {
      if (url.includes('/admin/sources/status'))
        return jsonResponse(200, {
          news: { maintenance: false, lastSuccess: null, lastAttempt: null, message: null, itemsLast7d: 14, total: 500, hidden: 6, byType: { HABER: 120, DUYURU: 340, ETKINLIK: 40 } },
          menu: { maintenance: false, lastSuccess: null, lastAttempt: null, message: null, totalDays: 0, upcomingDays: 0, withImage: 0 },
          syncPerHour: 3,
        });
      if (url.includes('/admin/news')) return jsonResponse(200, { items: [], page: 0, size: 20, totalItems: 0, totalPages: 1 });
      return jsonResponse(404, { code: 'X', message: 'x' });
    });
    renderWithProviders(<NewsAdminPage />);
    expect(await screen.findByText('Kayıt dağılımı')).toBeInTheDocument();
    expect(screen.getByText(/Toplam 500 kayıt var \(.*Duyuru 340.*\)\. Son 7 günde 14 yeni kayıt geldi; 6 kayıt gizli/)).toBeInTheDocument();
    expect(screen.getByRole('img', { name: 'Haber, duyuru ve etkinlik dağılımı' })).toBeInTheDocument();
  });
});
