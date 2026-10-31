// P05: haber gizleme, SSS silme/sayfalama/kaydedilmemiş uyarı ve sözleşme editörü çıkış uyarısı.
import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdminNewsRow, FaqAdminView } from '../../api/types';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import FaqAdminPage from './FaqAdminPage';
import LegalAdminPage from './LegalAdminPage';
import NewsAdminPage from './NewsAdminPage';

afterEach(() => vi.unstubAllGlobals());

interface Call {
  url: string;
  init: RequestInit;
}
const hdr = (c: Call, name: string) => (c.init.headers as Record<string, string>)[name];

// ---------- Haber ----------
const NEWS: AdminNewsRow = {
  id: 5,
  type: 'HABER',
  title: 'Kayıtlar uzatıldı',
  summary: null,
  imageUrl: null,
  publishedDate: '2026-10-01',
  url: 'https://www.bingol.edu.tr/x',
  hidden: false,
};

function newsSetup() {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    if (url.includes('/admin/news') && (init.method ?? 'GET') === 'GET')
      return jsonResponse(200, { items: [NEWS], page: 0, totalPages: 1, totalItems: 1 });
    if (url.includes('/admin/news/') && init.method === 'PATCH') return jsonResponse(204);
    if (url.endsWith('/status')) return jsonResponse(200, { NEWS: { maintenance: false }, MENU: { maintenance: false } });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}
const patches = (calls: Call[]) => calls.filter((c) => c.init.method === 'PATCH');

describe('Haber gizleme', () => {
  it('onay penceresi açılır; onaysız istek gitmez, vazgeçince de gitmez', async () => {
    const calls = newsSetup();
    renderWithProviders(<NewsAdminPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /^Gizle: Kayıtlar uzatıldı/ }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('Haber gizlensin mi?');
    expect(dialog).toHaveTextContent('Kayıtlar uzatıldı');
    expect(patches(calls)).toHaveLength(0);
    await user.click(within(dialog).getByRole('button', { name: 'Vazgeç' }));
    expect(patches(calls)).toHaveLength(0);
  });

  it('sebep isteğe bağlı: boş da, yazılı da gönderilir; çift tıklama tek istek', async () => {
    const calls = newsSetup();
    renderWithProviders(<NewsAdminPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /^Gizle: Kayıtlar uzatıldı/ }));
    const dialog = await screen.findByRole('alertdialog');
    await user.type(within(dialog).getByRole('textbox'), 'Yanlış bilgi içeriyor');
    const confirm = within(dialog).getByRole('button', { name: 'Gizle' });
    await user.dblClick(confirm);
    await waitFor(() => expect(patches(calls)).toHaveLength(1));
    expect(patches(calls)[0].url).toBe('/api/admin/news/5');
    expect(JSON.parse(String(patches(calls)[0].init.body))).toEqual({ hidden: true });
    expect(decodeURIComponent(hdr(patches(calls)[0], 'X-Admin-Reason'))).toBe('Yanlış bilgi içeriyor');
    expect(hdr(patches(calls)[0], 'Idempotency-Key')).toBeTruthy();
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    expect(patches(calls)).toHaveLength(1);
  });

  it('haber gizleme gerekçe ister (W1-B T-013): gerekçesiz gönderilmez, başlıkta gider', async () => {
    const calls = newsSetup();
    renderWithProviders(<NewsAdminPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: /^Gizle: Kayıtlar uzatıldı/ }));
    const dialog = await screen.findByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Gizle' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'abcd');
    expect(confirm).toBeDisabled();
    expect(patches(calls)).toHaveLength(0);
    await user.type(within(dialog).getByRole('textbox'), 'e');
    await user.click(confirm);
    await waitFor(() => expect(patches(calls)).toHaveLength(1));
    expect(JSON.parse(String(patches(calls)[0].init.body))).toEqual({ hidden: true });
    expect(decodeURIComponent(hdr(patches(calls)[0], 'X-Admin-Reason') ?? '')).toBe('abcde');
  });
});

// ---------- SSS ----------
const faq = (id: number, extra: Partial<FaqAdminView> = {}): FaqAdminView => ({
  id,
  lang: 'tr',
  category: 'Genel',
  question: `Soru ${id}`,
  answer: `Cevap ${id}`,
  sortOrder: id,
  published: true,
  ...extra,
});

function faqSetup(opts: { paged?: boolean } = {}) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    const method = init.method ?? 'GET';
    if (url.startsWith('/api/admin/faq') && method === 'GET') {
      const cursor = new URL(url, 'http://x').searchParams.get('cursor');
      if (opts.paged && !cursor)
        return new Response(JSON.stringify([faq(1), faq(2)]), {
          status: 200,
          headers: { 'Content-Type': 'application/json', 'X-Next-Cursor': '1' },
        });
      if (opts.paged && cursor === '1') return jsonResponse(200, [faq(3, { category: 'Hesap' })]);
      return jsonResponse(200, [faq(1), faq(2)]);
    }
    if (method === 'DELETE') return jsonResponse(204);
    if (method === 'PUT' || method === 'POST') return jsonResponse(200, faq(9));
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

describe('SSS yönetimi', () => {
  it('silme: onay penceresi çıkar, onaysız istek gitmez; onaylayınca tek DELETE', async () => {
    const calls = faqSetup();
    renderWithProviders(<FaqAdminPage />);
    const user = userEvent.setup();
    await screen.findByText('Soru 1');
    await user.click(screen.getAllByRole('button', { name: 'Sil' })[0]);
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('Soru silinsin mi?');
    expect(calls.filter((c) => c.init.method === 'DELETE')).toHaveLength(0);
    await user.click(within(dialog).getByRole('button', { name: 'Vazgeç' }));
    expect(calls.filter((c) => c.init.method === 'DELETE')).toHaveLength(0);

    await user.click(screen.getAllByRole('button', { name: 'Sil' })[0]);
    const again = await screen.findByRole('alertdialog');
    await user.dblClick(within(again).getByRole('button', { name: 'Sil' }));
    await waitFor(() => expect(calls.filter((c) => c.init.method === 'DELETE')).toHaveLength(1));
    const del = calls.find((c) => c.init.method === 'DELETE')!;
    expect(del.url).toBe('/api/admin/faq/1');
    expect(hdr(del, 'Idempotency-Key')).toBeTruthy();
  });

  it('X-Next-Cursor varsa "Daha fazla yükle" sonraki sayfayı getirir; son sayfada düğme kalkar', async () => {
    const calls = faqSetup({ paged: true });
    renderWithProviders(<FaqAdminPage />);
    const user = userEvent.setup();
    await screen.findByText('Soru 2');
    expect(screen.queryByText('Soru 3')).toBeNull();
    await user.click(screen.getByRole('button', { name: 'Daha fazla yükle' }));
    expect(await screen.findByText('Soru 3')).toBeInTheDocument();
    const gets = calls.filter((c) => (c.init.method ?? 'GET') === 'GET');
    expect(gets[0].url).toContain('limit=50');
    expect(gets[1].url).toContain('cursor=1');
    expect(screen.queryByRole('button', { name: 'Daha fazla yükle' })).toBeNull();
  });

  it('sonraki sayfa yoksa düğme gösterilmez', async () => {
    faqSetup();
    renderWithProviders(<FaqAdminPage />);
    await screen.findByText('Soru 1');
    expect(screen.queryByRole('button', { name: 'Daha fazla yükle' })).toBeNull();
  });

  it('düzenleme formunda değişiklik varken Vazgeç uyarı ister; "Sayfada kal" formu korur', async () => {
    faqSetup();
    renderWithProviders(<FaqAdminPage />);
    const user = userEvent.setup();
    await screen.findByText('Soru 1');
    await user.click(screen.getAllByRole('button', { name: 'Düzenle' })[0]);
    const form = await screen.findByRole('dialog');
    // değişiklik yokken kapatmak doğrudan kapatır
    await user.click(within(form).getByRole('button', { name: 'Vazgeç' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());

    await user.click(screen.getAllByRole('button', { name: 'Düzenle' })[0]);
    const form2 = await screen.findByRole('dialog');
    await user.type(within(form2).getByLabelText(/^Soru/), ' ek');
    await user.click(within(form2).getByRole('button', { name: 'Vazgeç' }));
    const warn = await screen.findByRole('alertdialog');
    expect(warn).toHaveTextContent('Kaydedilmemiş değişiklikler var');
    await user.click(within(warn).getByRole('button', { name: 'Sayfada kal' }));
    expect(screen.getByDisplayValue('Soru 1 ek')).toBeInTheDocument();
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Vazgeç' }));
    await user.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Ayrıl' }));
    await waitFor(() => expect(screen.queryByDisplayValue('Soru 1 ek')).toBeNull());
  });

  it('kaydet: çift tıklama tek PUT gönderir', async () => {
    const calls = faqSetup();
    renderWithProviders(<FaqAdminPage />);
    const user = userEvent.setup();
    await screen.findByText('Soru 1');
    await user.click(screen.getAllByRole('button', { name: 'Düzenle' })[0]);
    const form = await screen.findByRole('dialog');
    await user.type(within(form).getByLabelText(/^Soru/), '?');
    await user.dblClick(within(form).getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(calls.filter((c) => c.init.method === 'PUT')).toHaveLength(1));
    expect(calls.filter((c) => c.init.method === 'PUT')).toHaveLength(1);
  });
});

// ---------- Sözleşme editörü ----------
describe('Sözleşme editörü kaydedilmemiş uyarısı', () => {
  it('taslak varken başka sözleşme türüne geçmek uyarı diyaloğu açar', async () => {
    mockFetch((url) => (url.includes('/versions') ? jsonResponse(200, []) : jsonResponse(200, [])));
    renderWithProviders(<LegalAdminPage />);
    const user = userEvent.setup();
    await user.click(screen.getByRole('tab', { name: /Yeni sürüm/ }));
    await user.type(screen.getByRole('textbox', { name: /^Başlık/ }), 'Taslak');
    fireEvent.change(document.getElementById('legal-content') as HTMLTextAreaElement, { target: { value: 'metin' } });
    const privacy = document.querySelector('[data-type="PRIVACY"]') as HTMLElement;
    await user.click(privacy);
    const warn = await screen.findByRole('alertdialog');
    expect(warn).toHaveTextContent('Kaydedilmemiş değişiklikler var');
    await user.click(within(warn).getByRole('button', { name: 'Sayfada kal' }));
    expect(document.querySelector('[data-type="TERMS"]')).toHaveAttribute('aria-pressed', 'true');
    await user.click(privacy);
    await user.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Ayrıl' }));
    await waitFor(() => expect(document.querySelector('[data-type="PRIVACY"]')).toHaveAttribute('aria-pressed', 'true'));
  });
});
