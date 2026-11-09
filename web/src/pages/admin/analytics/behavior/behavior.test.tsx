import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { jsonResponse, mockFetch } from '../../../../test/fetchMock';
import { renderWithProviders } from '../../../../test/utils';
import AnalyticsPage from '../../AnalyticsPage';
import { nextSort } from './ScreensSection';
import { StepRow } from './UserDrawer';
import {
  actionsFixture,
  flowsFixture,
  overviewFixture,
  screensFixture,
  userDetailFixture,
  usersFixture,
} from './fixtures';

const FULL = ['analytics.read', 'users.pii', 'users.read'];
const rbac = (perms: string[]) => ({
  userId: 1,
  email: 'a@bingol.edu.tr',
  displayName: 'Yönetici',
  profile: 'FULL',
  pinned: true,
  permissions: perms,
});

interface Opts {
  perms?: string[];
  overview?: unknown;
  fail?: string[];
}

function setup(opts: Opts = {}) {
  const perms = opts.perms ?? FULL;
  return mockFetch((url) => {
    const u = new URL(url, 'http://x');
    const path = u.pathname;
    if (path.endsWith('/rbac/me')) return jsonResponse(200, rbac(perms));
    if ((opts.fail ?? []).some((f) => path.includes(f)))
      return jsonResponse(500, { code: 'X', message: 'x' });
    if (path.endsWith('/behavior/overview')) return jsonResponse(200, opts.overview ?? overviewFixture);
    if (path.endsWith('/behavior/screens')) {
      const page = Number(u.searchParams.get('page') ?? 0);
      return jsonResponse(200, screensFixture(page, 20, 45));
    }
    if (path.endsWith('/behavior/flows')) return jsonResponse(200, flowsFixture);
    if (path.endsWith('/behavior/actions')) return jsonResponse(200, actionsFixture);
    if (/\/behavior\/users\/\d+$/.test(path)) return jsonResponse(200, userDetailFixture);
    if (path.endsWith('/behavior/users')) {
      const page = Number(u.searchParams.get('page') ?? 0);
      return jsonResponse(200, usersFixture(page, 20, 45));
    }
    return jsonResponse(404, { code: 'NOPE', message: 'yok' });
  });
}

const calls = (fn: ReturnType<typeof setup>, part: string) =>
  fn.mock.calls.map((c) => String(c[0])).filter((u) => u.includes(part));

describe('Davranış sekmesi: özet', () => {
  it('KPI kartlarını ve süre dağılımını çizer', async () => {
    setup();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior' });
    expect(screen.getByRole('tab', { name: 'Davranış' })).toHaveAttribute('aria-selected', 'true');
    expect(await screen.findByText('Ortalama oturum süresi')).toBeInTheDocument();
    expect(screen.getByText('2 dk 14 sn')).toBeInTheDocument(); // ortalama
    expect(screen.getByText('1 dk 2 sn')).toBeInTheDocument(); // medyan
    expect(screen.getByText('%9,4')).toBeInTheDocument(); // hemen kapatma
    expect(screen.getByText('%18,2')).toBeInTheDocument(); // bounce
    expect(screen.getByRole('list', { name: 'Oturum süresi dağılımı' })).toBeInTheDocument();
    // genel "tek tek kullanıcı listelenmez" notu bu sekmede yoktur, sekmenin kendi notu vardır
    expect(screen.getByText(/Kullanıcılar bölümü kişi bazlıdır/)).toBeInTheDocument();
    expect(screen.queryByText(/Tek tek kullanıcıların davranışı listelenmez/)).not.toBeInTheDocument();
  });

  it('aralık son 7 gündür ve istek from/to taşır', async () => {
    const f = setup();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior' });
    await screen.findByText('Ortalama oturum süresi');
    expect(screen.getByRole('button', { name: 'Son 7 gün' })).toHaveAttribute('aria-pressed', 'true');
    const [url] = calls(f, '/behavior/overview');
    expect(url).toMatch(/from=\d{4}-\d{2}-\d{2}/);
    expect(url).toMatch(/to=\d{4}-\d{2}-\d{2}/);
  });

  it('hazır aralığa basınca yeni aralıkla yeniden sorgular', async () => {
    const f = setup();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior' });
    await screen.findByText('Ortalama oturum süresi');
    await userEvent.setup().click(screen.getByRole('button', { name: 'Son 30 gün' }));
    await waitFor(() => expect(calls(f, '/behavior/overview').length).toBe(2));
    expect(screen.getByRole('button', { name: 'Son 30 gün' })).toHaveAttribute('aria-pressed', 'true');
  });

  it('45 günden uzun URL aralığı 45 güne indirilir', async () => {
    const f = setup();
    renderWithProviders(<AnalyticsPage />, {
      route: '/admin/analytics?tab=behavior&from=2026-01-01&to=2026-11-03',
    });
    await screen.findByText('Ortalama oturum süresi');
    const [url] = calls(f, '/behavior/overview');
    expect(url).toContain('from=2026-09-20');
    expect(url).toContain('to=2026-11-03');
    expect(screen.getByText(/Seçili aralık 45 gün/)).toBeInTheDocument();
  });

  it('veri yoksa boş durum, hatada neden + tekrar dene gösterir', async () => {
    setup({ overview: { ...overviewFixture, sessions: 0, users: 0, byDay: [], durationBuckets: [] } });
    const { unmount } = renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior' });
    expect(await screen.findByText('Bu aralıkta oturum verisi yok')).toBeInTheDocument();
    unmount();

    setup({ fail: ['/behavior/overview'] });
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior' });
    expect(await screen.findByRole('button', { name: 'Tekrar dene' })).toBeInTheDocument();
  });

  it('yüklenirken iskelet gösterilir', () => {
    mockFetch(() => new Promise<Response>(() => {}));
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior' });
    expect(document.querySelector('[aria-busy="true"]')).not.toBeNull();
  });
});

describe('Davranış sekmesi: ekranlar', () => {
  it('okunur ekran adlarını yazar, bilinmeyeni olduğu gibi bırakır', async () => {
    setup();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior&sub=screens' });
    await screen.findByText('Haber Detayı');
    const table = screen.getByRole('table', { name: 'Ekran bazlı süre ve çıkış' });
    expect(within(table).getByText('Ana Sayfa')).toBeInTheDocument();
    expect(within(table).getByText('Haber Detayı')).toBeInTheDocument();
    expect(within(table).getByText('Etkinlik Detayı')).toBeInTheDocument();
    expect(within(table).getByText('/yeni-ekran-x')).toBeInTheDocument();
  });

  it('sütun başlığı sıralar (ilk tıklama çoktan aza), sayfalayıcı sonraki sayfayı ister', async () => {
    const f = setup();
    const user = userEvent.setup();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior&sub=screens' });
    await screen.findByRole('table', { name: 'Ekran bazlı süre ve çıkış' });
    expect(calls(f, '/behavior/screens')[0]).toContain('sort=views');
    expect(calls(f, '/behavior/screens')[0]).toContain('dir=desc');
    expect(calls(f, '/behavior/screens')[0]).toContain('size=20');

    await user.click(screen.getByRole('button', { name: /Çıkış %/ }));
    await waitFor(() =>
      expect(
        calls(f, '/behavior/screens').some((u) => u.includes('sort=exitRate') && u.includes('dir=desc')),
      ).toBe(true),
    );
    await user.click(screen.getByRole('button', { name: /Çıkış %/ }));
    await waitFor(() =>
      expect(
        calls(f, '/behavior/screens').some((u) => u.includes('sort=exitRate') && u.includes('dir=asc')),
      ).toBe(true),
    );

    await user.click(screen.getByRole('button', { name: 'Sonraki sayfa' }));
    await waitFor(() => expect(calls(f, '/behavior/screens').some((u) => u.includes('page=1'))).toBe(true));
    expect(await screen.findByText(/Sayfa 2/)).toBeInTheDocument();
  });

  it('nextSort: yeni sütun çoktan aza başlar, aynı sütun yönü korur', () => {
    expect(nextSort({ key: 'views', dir: 'desc' }, { key: 'users', dir: 'asc' })).toEqual({
      key: 'users',
      dir: 'desc',
    });
    expect(nextSort({ key: 'views', dir: 'desc' }, { key: 'views', dir: 'asc' })).toEqual({
      key: 'views',
      dir: 'asc',
    });
  });
});

describe('Davranış sekmesi: akışlar ve eylemler', () => {
  it('geçişleri, giriş/çıkış ve terk edilen ekranları listeler', async () => {
    setup();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior&sub=flows' });
    expect(await screen.findByText('Ana Sayfa → Haber Detayı')).toBeInTheDocument();
    expect(screen.getByRole('list', { name: 'Giriş ekranları' })).toBeInTheDocument();
    expect(screen.getByRole('list', { name: 'Çıkış ekranları' })).toBeInTheDocument();
    expect(screen.getByRole('table', { name: 'Terk edilen ekranlar' })).toBeInTheDocument();
  });

  it('eylem türlerini Türkçe adlarıyla ve ekran kırılımıyla gösterir', async () => {
    setup();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior&sub=actions' });
    const table = await screen.findByRole('table', { name: 'Eylem ayrıntıları' });
    expect(within(table).getByText('Beğeni')).toBeInTheDocument();
    expect(within(table).getByText('Mesaj gönderme')).toBeInTheDocument();
    expect(within(table).getAllByText(/Ana Sayfa/).length).toBeGreaterThan(0);
  });

  it('boş akış ve eylemde açıklayıcı boş durum çıkar', async () => {
    mockFetch((url) =>
      url.includes('/behavior/flows')
        ? jsonResponse(200, { topTransitions: [], entryScreens: [], exitScreens: [], dropOff: [] })
        : jsonResponse(200, { items: [] }),
    );
    const { unmount } = renderWithProviders(<AnalyticsPage />, {
      route: '/admin/analytics?tab=behavior&sub=flows',
    });
    expect(await screen.findByText('Bu aralıkta akış verisi yok')).toBeInTheDocument();
    unmount();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior&sub=actions' });
    expect(await screen.findByText('Bu aralıkta eylem verisi yok')).toBeInTheDocument();
  });
});

describe('Davranış sekmesi: kullanıcılar', () => {
  it('users.pii yoksa Kullanıcılar bölümü görünmez ve istek atılmaz', async () => {
    const f = setup({ perms: ['analytics.read'] });
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior&sub=users' });
    await screen.findByText('Ortalama oturum süresi'); // özete düştü
    await waitFor(() => expect(screen.queryByRole('tab', { name: 'Kullanıcılar' })).not.toBeInTheDocument());
    expect(calls(f, '/behavior/users')).toHaveLength(0);
  });

  it('users.pii ile sekme vardır; tablo sayfalanır, sıralanır ve aranır', async () => {
    const f = setup();
    const user = userEvent.setup();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior&sub=users' });
    await screen.findByText('Test Kullanıcı 1');
    const table = screen.getByRole('table', { name: 'Kullanıcı bazlı davranış' });
    expect(within(table).getByText('Test Kullanıcı 1')).toBeInTheDocument();
    expect(screen.getByText('Denetim kaydına yazılır')).toBeInTheDocument();
    expect(calls(f, '/behavior/users')[0]).toContain('sort=totalMs');

    await user.click(screen.getByRole('button', { name: /Oturum$/ }));
    await waitFor(() =>
      expect(calls(f, '/behavior/users').some((u) => u.includes('sort=sessions'))).toBe(true),
    );

    await user.click(screen.getByRole('button', { name: 'Sonraki sayfa' }));
    await waitFor(() => expect(calls(f, '/behavior/users').some((u) => u.includes('page=1'))).toBe(true));
    expect(await screen.findByText('Test Kullanıcı 21')).toBeInTheDocument();

    await user.type(screen.getByRole('searchbox'), 'ayşe');
    await waitFor(() =>
      expect(calls(f, '/behavior/users').some((u) => u.includes('q=ay%C5%9Fe'))).toBe(true),
    );
  });

  it('satıra basınca çekmece açılır: özet ve oturum zaman çizelgesi', async () => {
    const f = setup();
    const user = userEvent.setup();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior&sub=users' });
    await screen.findByText('Test Kullanıcı 1');
    const table = screen.getByRole('table', { name: 'Kullanıcı bazlı davranış' });
    await user.click(within(table).getByText('Test Kullanıcı 1'));

    const dlg = await screen.findByRole('dialog');
    expect(await within(dlg).findByText('Test Kullanıcı 1: davranış')).toBeInTheDocument();
    expect(calls(f, '/behavior/users/1')[0]).toMatch(/from=\d{4}-\d{2}-\d{2}/);
    expect(calls(f, '/behavior/users/1')[0]).toMatch(/to=\d{4}-\d{2}-\d{2}/);
    // iki oturum: biri hemen kapatma + bounce rozetli
    expect(within(dlg).getByText('Hemen kapattı')).toBeInTheDocument();
    expect(within(dlg).getAllByText('Bounce').length).toBeGreaterThan(0);
    expect(within(dlg).getByText('Arka plana atıldı')).toBeInTheDocument();
    // ilk oturum açık: adımlar (ekran, süre, eylem)
    const steps = within(dlg).getByRole('list', { name: 'Oturum adımları' });
    expect(within(steps).getByText('Haber Detayı')).toBeInTheDocument();
    expect(within(steps).getByText('Beğeni')).toBeInTheDocument();
    expect(within(steps).getByText('Yenileme (aşağı çekme)')).toBeInTheDocument();
    expect(within(steps).getByText(/süre ölçülemedi/)).toBeInTheDocument();
    expect(within(dlg).getByRole('link', { name: 'Kullanıcı kartını aç' })).toHaveAttribute(
      'href',
      expect.stringContaining('/users/1'),
    );

    // ikinci oturum kapalıdır; açınca adımı görünür
    expect(within(dlg).getAllByRole('list', { name: 'Oturum adımları' })).toHaveLength(1);
    await user.click(within(dlg).getByText('Uygulamadan çıkıldı'));
    await waitFor(() =>
      expect(within(dlg).getAllByRole('list', { name: 'Oturum adımları' })).toHaveLength(2),
    );
  });

  it('geçmiş tarih seçilince kullanıcı detayı da aynı tarih aralığını ister', async () => {
    const f = setup();
    renderWithProviders(<AnalyticsPage />, {
      route: '/admin/analytics?tab=behavior&sub=users&uid=1&from=2026-10-01&to=2026-10-03',
    });
    const dlg = await screen.findByRole('dialog');
    await within(dlg).findByText('Test Kullanıcı 1: davranış');
    const url = calls(f, '/behavior/users/1')[0];
    expect(url).toContain('from=2026-10-01');
    expect(url).toContain('to=2026-10-03');
    expect(url).not.toContain('days=');
    expect(within(dlg).getByText('2026-10-01 – 2026-10-03')).toBeInTheDocument();
    expect(
      within(dlg).getByRole('table', { name: 'Bu kullanıcı hangi sayfalarda vakit geçiriyor?' }),
    ).toBeInTheDocument();
  });

  it('çekmece hatasında neden gösterilir (403)', async () => {
    mockFetch((url) => {
      const path = new URL(url, 'http://x').pathname;
      if (path.endsWith('/rbac/me')) return jsonResponse(200, rbac(FULL));
      if (/\/behavior\/users\/\d+$/.test(path))
        return jsonResponse(403, { code: 'ADMIN_PERMISSION_DENIED', message: 'yok' });
      return jsonResponse(200, usersFixture());
    });
    const user = userEvent.setup();
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior&sub=users' });
    await screen.findByText('Test Kullanıcı 1');
    const table = screen.getByRole('table', { name: 'Kullanıcı bazlı davranış' });
    await user.click(within(table).getByText('Test Kullanıcı 1'));
    const dlg = await screen.findByRole('dialog');
    expect(await within(dlg).findByRole('alert')).toBeInTheDocument();
  });

  it('kullanıcı listesi boşsa açıklayıcı boş durum', async () => {
    mockFetch((url) => {
      const path = new URL(url, 'http://x').pathname;
      if (path.endsWith('/rbac/me')) return jsonResponse(200, rbac(FULL));
      return jsonResponse(200, { items: [], page: 0, size: 20, total: 0 });
    });
    renderWithProviders(<AnalyticsPage />, { route: '/admin/analytics?tab=behavior&sub=users' });
    expect(await screen.findByText('Kullanıcı bulunamadı')).toBeInTheDocument();
  });
});

describe('StepRow', () => {
  it('eylem ve ekran adımını farklı yazar', () => {
    const start = '2026-11-03T08:20:00Z';
    renderWithProviders(
      <ol>
        <StepRow
          start={start}
          step={{ type: 'screen', screen: '/menu', dwellMs: 134_000, at: '2026-11-03T08:20:30Z' }}
        />
        <StepRow
          start={start}
          step={{ type: 'action', screen: '/menu', kind: 'rate_menu', at: '2026-11-03T08:21:00Z' }}
        />
      </ol>,
    );
    expect(screen.getByText('Yemek Listesi', { selector: 'strong' })).toBeInTheDocument();
    expect(screen.getByText(/2 dk 14 sn/)).toBeInTheDocument();
    expect(screen.getByText('Menü puanlama')).toBeInTheDocument();
    expect(screen.getByText('+0:30')).toBeInTheDocument();
    expect(screen.getByText('+1:00')).toBeInTheDocument();
  });
});
