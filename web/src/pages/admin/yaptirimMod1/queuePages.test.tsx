// Mod1: itiraz ve askı önerisi kuyruğu: öncelik sırası, yaş grafiği, toplu karar, klavye kısayolu, boş/hata durumu.
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import AppealsPage from '../AppealsPage';
import SuspendRecommendationsPage from '../SuspendRecommendationsPage';
import { DAY_MS } from './queueLogic';

afterEach(() => vi.unstubAllGlobals());

const ago = (ms: number) => new Date(Date.now() - ms).toISOString();
const appeal = (id: number, ageMs: number, over: Record<string, unknown> = {}) => ({
  id,
  userId: id,
  targetType: 'USER_AVATAR',
  targetId: id,
  message: `itiraz-${id}`,
  status: 'OPEN',
  adminNote: null,
  createdAt: ago(ageMs),
  decidedAt: null,
  ...over,
});
const rec = (id: number, strikes: number, ageMs: number) => ({
  id,
  userId: 100 + id,
  strikeCount: strikes,
  status: 'OPEN',
  createdAt: ago(ageMs),
});

interface Call {
  url: string;
  init: RequestInit;
}

function serve(items: unknown[], opts: { status?: number } = {}) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    if (init.method === 'POST') return jsonResponse(204);
    if (url.includes('/admin/moderation/appeals') || url.includes('/suspend-recommendations')) {
      if (opts.status && opts.status >= 400) return jsonResponse(opts.status, { code: 'SERVER_ERROR', message: 'x' });
      return jsonResponse(200, { items, nextCursor: null });
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

const fillReason = async (dialog: HTMLElement, text: string) =>
  userEvent.type(within(dialog).getByLabelText(/^İşlem gerekçesi/), text);

describe('İtirazlar: kuyruk', () => {
  it('en eski/acil itiraz üstte; yaş grafiği tek cümleyle yorumlar', async () => {
    serve([appeal(1, 1 * DAY_MS), appeal(2, 10 * DAY_MS), appeal(3, 4 * DAY_MS)]);
    renderWithProviders(<AppealsPage />);
    await screen.findByText('itiraz-2');
    const order = screen.getAllByText(/^itiraz-\d$/).map((e) => e.textContent);
    expect(order).toEqual(['itiraz-2', 'itiraz-3', 'itiraz-1']);
    expect(screen.getByText(/3 itiraz bekliyor; 1 tanesi bir haftayı geçti/)).toBeInTheDocument();
    expect(screen.getAllByText('Acil').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Dikkat').length).toBeGreaterThan(0);
  });

  it('boş kuyrukta "kuyruk temiz" der ve kısayol çubuğu çıkmaz', async () => {
    serve([]);
    renderWithProviders(<AppealsPage />);
    expect(await screen.findByText(/Şu an bekleyen itiraz yok; kuyruk temiz/)).toBeInTheDocument();
    expect(screen.queryByText('Klavye kısayolları')).not.toBeInTheDocument();
  });

  it('sunucu hatasında özet ve liste hata durumu gösterir', async () => {
    serve([], { status: 500 });
    renderWithProviders(<AppealsPage />);
    const retry = await screen.findAllByRole('button', { name: /Tekrar dene/ });
    expect(retry.length).toBeGreaterThan(0);
  });

  it('iki itiraz seçilip tek gerekçeyle toplu reddedilir (her biri için ayrı POST)', async () => {
    const calls = serve([appeal(1, 1 * DAY_MS), appeal(2, 10 * DAY_MS), appeal(3, 4 * DAY_MS)]);
    renderWithProviders(<AppealsPage />);
    await screen.findByText('itiraz-2');
    const boxes = screen.getAllByRole('checkbox', { name: /kaydını seç/ });
    await userEvent.click(boxes[0]);
    await userEvent.click(boxes[1]);
    await userEvent.click(await screen.findByRole('button', { name: 'Seçilenleri reddet' }));
    const dialog = await screen.findByRole('dialog');
    await fillReason(dialog, 'Toplu inceleme tamam');
    await userEvent.click(within(dialog).getByRole('button', { name: '2 itirazı reddet' }));
    await waitFor(() => expect(calls.filter((c) => c.init.method === 'POST')).toHaveLength(2));
    const urls = calls.filter((c) => c.init.method === 'POST').map((c) => c.url);
    expect(urls.some((u) => u.includes('/appeals/2/decide'))).toBe(true);
    expect(urls.some((u) => u.includes('/appeals/3/decide'))).toBe(true);
    const body = JSON.parse(String(calls.find((c) => c.init.method === 'POST')!.init.body));
    expect(body.accept).toBe(false);
  });

  it('J ile satır seçilir, R reddetme penceresini açar; yazı alanında kısayol çalışmaz', async () => {
    serve([appeal(1, 1 * DAY_MS), appeal(2, 10 * DAY_MS)]);
    renderWithProviders(<AppealsPage />);
    await screen.findByText('itiraz-2');
    await userEvent.keyboard('j');
    await userEvent.keyboard('r');
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByRole('button', { name: 'Reddet' })).toBeInTheDocument();
    // pencere açıkken kısayol yutulur: gerekçe alanına yazılan "a" kabul penceresi açmaz
    await userEvent.type(within(dialog).getByLabelText(/^İşlem gerekçesi/), 'a');
    expect(screen.getAllByRole('dialog')).toHaveLength(1);
  });
});

describe('Askı önerileri: kuyruk', () => {
  it('çok ihlalli kişi üstte; ihlal dağılımı ve bekleme cümlesi görünür', async () => {
    serve([rec(1, 3, 1 * DAY_MS), rec(2, 6, 2 * DAY_MS), rec(3, 4, 9 * DAY_MS)]);
    renderWithProviders(<SuspendRecommendationsPage />);
    await screen.findByText('6 ihlal');
    const order = screen.getAllByText(/^[346] ihlal$/).map((e) => e.textContent);
    expect(order).toEqual(['6 ihlal', '4 ihlal', '3 ihlal']);
    expect(screen.getByText(/3 askı önerisi bekliyor; 1 tanesi bir haftayı geçti/)).toBeInTheDocument();
    expect(screen.getByText('6 ihlali olanlar')).toBeInTheDocument();
  });

  it('iki öneri toplu yoksayılır', async () => {
    const calls = serve([rec(1, 3, 1 * DAY_MS), rec(2, 6, 2 * DAY_MS)]);
    renderWithProviders(<SuspendRecommendationsPage />);
    await screen.findByText('6 ihlal');
    for (const box of screen.getAllByRole('checkbox', { name: /kaydını seç/ })) await userEvent.click(box);
    await userEvent.click(await screen.findByRole('button', { name: 'Seçilenleri yoksay' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: '2 öneriyi yoksay' }));
    await waitFor(() =>
      expect(calls.filter((c) => c.init.method === 'POST' && c.url.includes('/dismiss'))).toHaveLength(2),
    );
  });

  it('toplu askıya almada saatlik sınır (20) uyarısı çıkar', async () => {
    const many = Array.from({ length: 22 }, (_, i) => rec(i + 1, 3, 1 * DAY_MS));
    serve(many);
    renderWithProviders(<SuspendRecommendationsPage />);
    await screen.findAllByText('3 ihlal');
    await userEvent.click(screen.getByRole('checkbox', { name: /Görünen 22 kaydın hepsini seç/ }));
    await userEvent.click(await screen.findByRole('button', { name: 'Seçilenleri askıya al' }));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByText(/yalnız ilk 20 kişi işlenir/)).toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: '20 kişiyi askıya al' })).toBeInTheDocument();
  });
});
