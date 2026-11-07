import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { clearTokens, setTokens } from '../../auth/tokens';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import UnitNewsAdminPage from './UnitNewsAdminPage';
import { parseKeys } from './unitnews/MappingModal';

const sources = [
  {
    code: 'mmf', name: 'Mühendislik ve Mimarlık Fakültesi', kind: 'FACULTY', baseUrl: 'https://mmf.bingol.edu.tr',
    enabled: true, graduate: false, facultyKeys: ['Mühendislik Fakültesi'], departmentCount: 6, announcementCount: 42,
    lastSuccessAt: '2026-10-31T22:00:00Z', lastAttemptAt: '2026-10-31T22:00:00Z', lastMessage: null, maintenance: false,
  },
  {
    code: 'fbe', name: 'Fen Bilimleri Enstitüsü', kind: 'INSTITUTE', baseUrl: 'https://fbe.bingol.edu.tr',
    enabled: false, graduate: true, facultyKeys: [], departmentCount: 0, announcementCount: 0,
    lastSuccessAt: null, lastAttemptAt: '2026-10-31T22:00:00Z', lastMessage: 'Yapı değişti', maintenance: true,
  },
  {
    code: 'ydyo', name: 'Yabancı Diller Yüksekokulu', kind: 'LANGUAGE', baseUrl: 'https://ydyo.bingol.edu.tr',
    enabled: true, graduate: false, facultyKeys: [], departmentCount: 0, announcementCount: 3,
    lastSuccessAt: '2026-10-30T22:00:00Z', lastAttemptAt: null, lastMessage: null, maintenance: false,
  },
];

const announcement = (id: number, hidden = false) => ({
  id, sourceCode: 'mmf', sourceName: 'Mühendislik ve Mimarlık Fakültesi', unitName: 'Bilgisayar Mühendisliği',
  title: `Vize Programı ${id}`, url: `https://mmf.bingol.edu.tr/duyuru/${id}/`, publishedDate: '2026-10-28',
  attachmentCount: 2, hidden,
});

interface Call { url: string; method: string; body: unknown }

function setup(opts: { permissions?: string[] } = {}) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({ url, method, body: init.body ? JSON.parse(String(init.body)) : undefined });
    if (url.endsWith('/admin/me')) {
      return jsonResponse(200, { id: 1, email: 'a@bingol.edu.tr', displayName: 'Yönetici', role: 'ADMIN' });
    }
    // İzinler GET /admin/rbac/me'den gelir (P16); verilmediyse arayüz serbest (sunucu denetler).
    if (url.endsWith('/admin/rbac/me')) {
      return opts.permissions
        ? jsonResponse(200, { userId: 1, email: 'a@bingol.edu.tr', displayName: 'Yönetici', profile: 'VIEWER', pinned: false, permissions: opts.permissions })
        : jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    }
    if (url.includes('/admin/unit-news/sources/mmf/departments')) {
      return jsonResponse(200, [
        { slug: 'bilgisayar-muhendisligi', name: 'Bilgisayar Mühendisliği', nameKey: 'bilgisayar muhendisligi', hasOwnFeed: true },
        { slug: 'insaat-muhendisligi', name: 'İnşaat Mühendisliği', nameKey: 'insaat muhendisligi', hasOwnFeed: false },
      ]);
    }
    if (url.includes('/admin/unit-news/sources/') && method === 'PUT') return jsonResponse(204);
    if (url.includes('/admin/unit-news/sources/') && method === 'POST') return jsonResponse(202);
    if (url.endsWith('/admin/unit-news/sync') && method === 'POST') return jsonResponse(202);
    if (url.endsWith('/admin/unit-news/sources')) return jsonResponse(200, sources);
    if (url.includes('/admin/unit-news/announcements/') && method === 'PUT') return jsonResponse(204);
    if (url.includes('/admin/unit-news/announcements')) {
      return jsonResponse(200, {
        content: [announcement(1), announcement(2, true)], totalElements: 2, totalPages: 1, number: 0, size: 20,
      });
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  renderWithProviders(
    <AuthProvider>
      <UnitNewsAdminPage />
    </AuthProvider>,
    { route: '/admin/content/unit-news' },
  );
  return calls;
}

beforeEach(() => setTokens('a', 'r'));
afterEach(() => {
  vi.unstubAllGlobals();
  clearTokens();
});

describe('Birim haberleri yönetimi', () => {
  it('kaynakları, sağlık özetini ve duyuruları listeler', async () => {
    setup();
    expect(await screen.findByRole('link', { name: 'Fen Bilimleri Enstitüsü' })).toBeInTheDocument();
    expect(screen.getByText('Fakülte')).toBeInTheDocument();
    expect(screen.getByText('Enstitü')).toBeInTheDocument();
    expect(screen.getByText('Yabancı Diller', { selector: 'span' })).toBeInTheDocument();
    expect(screen.getByText('Yapı değişti')).toBeInTheDocument();
    // sağlık: yalnız açık kaynaklar sayılır; 2 açık, 2 sağlıklı, 1 kapalı (bakımdaki kaynak kapalı)
    const health = screen.getByTestId('unit-news-health');
    expect(within(health).getByText('Sağlıklı: 2 / 3')).toBeInTheDocument();
    expect(within(health).getByText('Kapalı: 1')).toBeInTheDocument();
    const link = await screen.findByRole('link', { name: /Vize Programı 1/ });
    expect(link).toHaveAttribute('href', 'https://mmf.bingol.edu.tr/duyuru/1/');
    expect(link).toHaveAttribute('rel', expect.stringContaining('noopener'));
    expect(screen.getByText('Gizli', { selector: 'span' })).toBeInTheDocument();
  });

  it('aç/kapat anahtarı PUT /sources/{code} gönderir', async () => {
    const calls = setup();
    const sw = await screen.findByRole('switch', { name: 'Mühendislik ve Mimarlık Fakültesi kaynağı açık' });
    expect(sw).toHaveAttribute('aria-checked', 'true');
    await userEvent.click(sw);
    await waitFor(() =>
      expect(calls.some((c) => c.method === 'PUT' && c.url.endsWith('/admin/unit-news/sources/mmf'))).toBe(true),
    );
    const put = calls.find((c) => c.method === 'PUT' && c.url.endsWith('/sources/mmf'))!;
    expect(put.body).toEqual({ enabled: false, facultyKeys: ['Mühendislik Fakültesi'] });
  });

  it('"Şimdi çek" kaynak başına POST /sources/{code}/sync çağırır', async () => {
    const calls = setup();
    await userEvent.click(await screen.findByRole('button', { name: 'Şimdi çek: Mühendislik ve Mimarlık Fakültesi' }));
    await waitFor(() =>
      expect(calls.some((c) => c.method === 'POST' && c.url.endsWith('/admin/unit-news/sources/mmf/sync'))).toBe(true),
    );
  });

  it('"Tümünü çek" onay ister, sonra POST /sync gönderir', async () => {
    const calls = setup();
    await userEvent.click(await screen.findByRole('button', { name: 'Tümünü çek' }));
    const dialog = await screen.findByRole('dialog');
    expect(calls.some((c) => c.url.endsWith('/admin/unit-news/sync'))).toBe(false);
    await userEvent.click(within(dialog).getByRole('button', { name: 'Çek' }));
    await waitFor(() =>
      expect(calls.some((c) => c.method === 'POST' && c.url.endsWith('/admin/unit-news/sync'))).toBe(true),
    );
  });

  it('eşleme çipleri eklenir ve facultyKeys olarak kaydedilir', async () => {
    const calls = setup();
    await userEvent.click(await screen.findByRole('button', { name: 'Eşleme: Mühendislik ve Mimarlık Fakültesi' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText('Fakülte adı anahtarları'), 'Mimarlık Fakültesi, İktisat{Enter}');
    expect(within(dialog).getByText('Mimarlık Fakültesi')).toBeInTheDocument();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaldır: İktisat' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'PUT' && c.url.endsWith('/sources/mmf'))).toBe(true));
    expect(calls.find((c) => c.method === 'PUT' && c.url.endsWith('/sources/mmf'))!.body).toEqual({
      enabled: true,
      facultyKeys: ['Mühendislik Fakültesi', 'Mimarlık Fakültesi'],
    });
  });

  it('bölümleri salt okunur çekmecede gösterir', async () => {
    setup();
    await userEvent.click(await screen.findByRole('button', { name: 'Bölümleri gör: Mühendislik ve Mimarlık Fakültesi' }));
    const dialog = await screen.findByRole('dialog');
    expect(await within(dialog).findByText('İnşaat Mühendisliği')).toBeInTheDocument();
    expect(within(dialog).getByText('bilgisayar-muhendisligi')).toBeInTheDocument();
    expect(within(dialog).getByText('Var')).toBeInTheDocument();
    expect(within(dialog).getByText('Yok')).toBeInTheDocument();
  });

  it('gizle/göster anahtarı PUT /announcements/{id}/hidden gönderir', async () => {
    const calls = setup();
    const sw = await screen.findByRole('switch', { name: 'Öğrencilere göster: Vize Programı 1' });
    expect(sw).toHaveAttribute('aria-checked', 'true');
    await userEvent.click(sw);
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/announcements/1/hidden'))).toBe(true));
    const put = calls.find((c) => c.url.endsWith('/announcements/1/hidden'))!;
    expect(put.method).toBe('PUT');
    expect(put.body).toEqual({ hidden: true });
    expect(screen.getByRole('switch', { name: 'Öğrencilere göster: Vize Programı 2' })).toHaveAttribute('aria-checked', 'false');
  });

  it('süzgeçler sorgu parametresi olarak gider', async () => {
    const calls = setup();
    await screen.findByRole('link', { name: /Vize Programı 1/ });
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Görünürlük' }), 'hidden');
    await waitFor(() => expect(calls.some((c) => c.url.includes('hidden=true'))).toBe(true));
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Kaynak' }), 'mmf');
    await waitFor(() => expect(calls.some((c) => c.url.includes('source=mmf') && c.url.includes('hidden=true'))).toBe(true));
  });

  it('content.write izni yoksa yazma düğmeleri pasif', async () => {
    setup({ permissions: ['content.read'] });
    const sw = await screen.findByRole('switch', { name: 'Mühendislik ve Mimarlık Fakültesi kaynağı açık' });
    await waitFor(() => expect(sw).toBeDisabled());
    expect(screen.getByRole('button', { name: 'Tümünü çek' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Şimdi çek: Mühendislik ve Mimarlık Fakültesi' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Eşleme: Mühendislik ve Mimarlık Fakültesi' })).toBeDisabled();
    expect(await screen.findByRole('switch', { name: 'Öğrencilere göster: Vize Programı 1' })).toBeDisabled();
    // salt okunur bölüm listesi yine açılabilir
    expect(screen.getByRole('button', { name: 'Bölümleri gör: Mühendislik ve Mimarlık Fakültesi' })).toBeEnabled();
  });
});

describe('parseKeys', () => {
  it('virgülle ayırır, kırpar, büyük/küçük harf duyarsız tekrarı atar', () => {
    expect(parseKeys(' A , b,,a ,İ', ['x'])).toEqual(['x', 'A', 'b', 'İ']);
  });
});
