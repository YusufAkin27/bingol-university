import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import ProfanityPage from './ProfanityPage';

afterEach(() => vi.unstubAllGlobals());

const TERM = {
  id: 7,
  term: 'ornekkelime',
  kind: 'BLOCK',
  lang: 'TR',
  note: 'deneme notu',
  createdBy: 1,
  createdAt: '2026-10-01T10:00:00Z',
};

interface Call {
  url: string;
  init: RequestInit;
}

function setup() {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    const method = init.method ?? 'GET';
    if (url.includes('/admin/profanity/info'))
      return jsonResponse(200, {
        builtIn: { tr: 120, en: 220, ar: 40, allow: 30, source: 'LDNOOBW (CC-BY-4.0)' },
        adminBlock: 1,
        adminAllow: 0,
        settings: { enabled: true, mode: 'BLOCK' },
      });
    if (url.includes('/admin/profanity/stats'))
      return jsonResponse(200, {
        last24h: { total: 3, byField: [] },
        last7d: { total: 9, byField: [{ entity: 'CLUB', field: 'name', count: 9 }] },
      });
    if (url.includes('/admin/profanity/check'))
      return jsonResponse(200, { blocked: true, matches: ['kok1'], normalized: 'deneme metni' });
    if (url.includes('/admin/profanity') && method === 'POST') return jsonResponse(201, TERM);
    if (url.includes('/admin/profanity') && method === 'DELETE') return new Response(null, { status: 204 });
    if (url.includes('/admin/profanity')) return jsonResponse(200, { items: [TERM], nextCursor: null });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

describe('Uygunsuz ifade filtresi sayfası', () => {
  it('yerleşik liste bilgisini, istatistikleri ve kayıtları gösterir', async () => {
    setup();
    renderWithProviders(<ProfanityPage />);
    expect(await screen.findByText('ornekkelime')).toBeInTheDocument();
    expect(await screen.findByText(/Yerleşik liste: 380 kelime \(tr 120, en 220, ar 40\)/)).toBeInTheDocument();
    expect((await screen.findAllByText('9')).length).toBeGreaterThan(0);
    expect(screen.getByText('CLUB / name')).toBeInTheDocument();
  }, 20000);

  it('metni dene kutusu eşleşmeyi yöneticiye gösterir', async () => {
    const calls = setup();
    renderWithProviders(<ProfanityPage />);
    await screen.findByText('ornekkelime');
    await userEvent.type(screen.getByLabelText('Denenecek metin'), 'merhaba');
    await userEvent.click(screen.getByRole('button', { name: 'Denetle' }));
    expect(await screen.findByText('Engellenir')).toBeInTheDocument();
    expect(screen.getByText(/kok1/)).toBeInTheDocument();
    expect(calls.some((c) => c.url.includes('/admin/profanity/check') && c.init.method === 'POST')).toBe(true);
  });

  it('kelime ekleme POST gönderir', async () => {
    const calls = setup();
    renderWithProviders(<ProfanityPage />);
    await screen.findByText('ornekkelime');
    await userEvent.type(screen.getByLabelText(/^Kelime/), 'yenikelime');
    await userEvent.click(screen.getByRole('button', { name: 'Ekle' }));
    await waitFor(() =>
      expect(
        calls.some(
          (c) =>
            c.init.method === 'POST' &&
            c.url.endsWith('/admin/profanity') &&
            String(c.init.body).includes('yenikelime') &&
            String(c.init.body).includes('"kind":"BLOCK"'),
        ),
      ).toBe(true),
    );
  });

  it('silme onayı DELETE gönderir', async () => {
    const calls = setup();
    renderWithProviders(<ProfanityPage />);
    await screen.findByText('ornekkelime');
    await userEvent.click(screen.getByRole('button', { name: 'Sil' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Sil' }));
    await waitFor(() => expect(calls.some((c) => c.init.method === 'DELETE' && c.url.endsWith('/admin/profanity/7'))).toBe(true));
  });
});
