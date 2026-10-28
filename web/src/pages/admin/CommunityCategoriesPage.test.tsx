import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import CommunityCategoriesPage from './CommunityCategoriesPage';

vi.setConfig({ testTimeout: 20000 }); // yavaş CI/yerel makinede kullanıcı yazma adımları uzun sürebilir

afterEach(() => vi.unstubAllGlobals());

const base = { icon: null, createdAt: '2026-10-01T10:00:00Z', updatedAt: '2026-10-01T10:00:00Z' };
const SPOR = { ...base, id: 1, key: 'spor', nameTr: 'Spor', nameEn: 'Sports', nameAr: 'رياضة', sortOrder: 10, active: true, usageCount: 3 };
const SANAT = { ...base, id: 2, key: 'sanat', nameTr: 'Sanat', nameEn: 'Arts', nameAr: 'فنون', sortOrder: 20, active: false, usageCount: 0 };

interface Call {
  url: string;
  init: RequestInit;
}

function setup(opts: { deleteStatus?: number } = {}) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    const method = init.method ?? 'GET';
    if (url.includes('/admin/community-categories/order') && method === 'PUT')
      return jsonResponse(200, { items: [SANAT, SPOR], activeCount: 1, maxActive: 20 });
    if (url.includes('/admin/community-categories') && method === 'DELETE') {
      if (opts.deleteStatus === 409)
        return jsonResponse(409, { code: 'COMMUNITY_CATEGORY_IN_USE', message: 'Kategori 3 kulüpte kullanıldığı için silinemez.' });
      return new Response(null, { status: 204 });
    }
    if (url.includes('/admin/community-categories') && method === 'POST') return jsonResponse(201, SPOR);
    if (url.includes('/active') && method === 'PATCH') return jsonResponse(200, { ...SANAT, active: true });
    if (url.includes('/admin/community-categories'))
      return jsonResponse(200, { items: [SPOR, SANAT], activeCount: 1, maxActive: 20 });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

describe('Kulüp kategorileri sayfası', () => {
  it('kategorileri, durumu ve kullanım sayısını listeler', async () => {
    setup();
    renderWithProviders(<CommunityCategoriesPage />);
    expect(await screen.findByText('Spor')).toBeInTheDocument();
    expect(screen.getByText('3 kulüpte kullanılıyor')).toBeInTheDocument();
    expect(screen.getByText('Aktif kategori: 1 / 20')).toBeInTheDocument();
    expect(screen.getByText('Pasif')).toBeInTheDocument();
  }, 20000);

  it('ekleme formu POST gönderir ve Türkçe ad zorunludur', async () => {
    const calls = setup();
    renderWithProviders(<CommunityCategoriesPage />);
    await screen.findByText('Spor');
    await userEvent.click(screen.getByRole('button', { name: 'Kategori ekle' }));
    await userEvent.click(screen.getByRole('button', { name: 'Kaydet' }));
    expect(await screen.findByText('Türkçe ad zorunludur.')).toBeInTheDocument();
    await userEvent.type(screen.getByLabelText(/^Ad \(Türkçe\)/), 'Müzik');
    await userEvent.click(screen.getByRole('button', { name: 'Kaydet' }));
    await waitFor(() =>
      expect(
        calls.some(
          (c) =>
            c.init.method === 'POST' &&
            c.url.endsWith('/admin/community-categories') &&
            String(c.init.body).includes('"nameTr":"Müzik"'),
        ),
      ).toBe(true),
    );
  });

  it('aşağı taşıma tam sıralamayı PUT /order ile gönderir', async () => {
    const calls = setup();
    renderWithProviders(<CommunityCategoriesPage />);
    await screen.findByText('Spor');
    await userEvent.click(screen.getByRole('button', { name: 'Spor kategorisini aşağı taşı' }));
    await waitFor(() =>
      expect(
        calls.some(
          (c) => c.init.method === 'PUT' && c.url.endsWith('/order') && String(c.init.body) === '{"ids":[2,1]}',
        ),
      ).toBe(true),
    );
  });

  it('pasif kategoriyi aktifleştirir (PATCH)', async () => {
    const calls = setup();
    renderWithProviders(<CommunityCategoriesPage />);
    await screen.findByText('Sanat');
    await userEvent.click(screen.getByRole('button', { name: 'Aktifleştir' }));
    await waitFor(() =>
      expect(calls.some((c) => c.init.method === 'PATCH' && c.url.endsWith('/2/active'))).toBe(true),
    );
  });

  it('silme onayı DELETE gönderir; 409 sunucu mesajı gösterilir', async () => {
    const calls = setup({ deleteStatus: 409 });
    renderWithProviders(<CommunityCategoriesPage />);
    await screen.findByText('Spor');
    await userEvent.click(screen.getAllByRole('button', { name: 'Sil' })[0]!);
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Sil' }));
    await waitFor(() =>
      expect(calls.some((c) => c.init.method === 'DELETE' && c.url.endsWith('/admin/community-categories/1'))).toBe(true),
    );
    expect(await screen.findByText(/kulüpte kullanıldığı için silinemez/)).toBeInTheDocument();
  });
});
