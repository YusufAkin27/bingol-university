import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import CampaignComposePage from './CampaignComposePage';
import CampaignsPage from './CampaignsPage';
import { clearDraft } from './campaigns/lib';

afterEach(() => {
  cleanup();
  clearDraft();
  vi.unstubAllGlobals();
});

interface Call {
  url: string;
  init: RequestInit;
}

function setupCompose(count = 10) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    if (url.includes('/admin/push/audience/preview'))
      return jsonResponse(200, {
        count: 10,
        willReceive: 8,
        optedOut: 2,
        byLanguage: { tr: 7, en: 3 },
        sample: [{ id: 5, displayName: 'Ayse Yilmaz', email: 'ayse@bingol.edu.tr', language: 'tr' }],
        notFound: ['yok@bingol.edu.tr'],
      });
    if (url.includes('/admin/push/audience-count')) return jsonResponse(200, { count });
    if (url.includes('/faculties')) return jsonResponse(200, ['Mühendislik Fakültesi', 'Fen-Edebiyat Fakültesi']);
    if (url.includes('/departments')) return jsonResponse(200, ['Hukuk']);
    if (url.endsWith('/admin/push/campaigns/test')) return jsonResponse(202, { id: 2 });
    if (url.endsWith('/admin/push/campaigns')) return jsonResponse(409, { code: 'CAMPAIGN_DUPLICATE', message: 'x' });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  renderWithProviders(<CampaignComposePage />, { route: '/admin/campaigns/new' });
  return calls;
}

const bodies = (calls: Call[], suffix: string) =>
  calls.filter((c) => c.url.endsWith(suffix)).map((c) => JSON.parse(String(c.init.body)) as Record<string, unknown>);

describe('bildirim gönderimi: oluşturucu', () => {
  it('alıcı önizleme sayıları, dil kırılımı, örnek kişileri ve bulunamayanları gösterir', async () => {
    const calls = setupCompose();
    const user = userEvent.setup();
    await user.click(screen.getByTestId('preview-button'));
    const box = await screen.findByTestId('preview-result');
    expect(box).toHaveTextContent('Tercihi nedeniyle atlanacak');
    expect(box).toHaveTextContent('Ayse Yilmaz');
    expect(box).toHaveTextContent('yok@bingol.edu.tr');
    expect(box).toHaveTextContent('Türkçe 7');
    expect(bodies(calls, '/admin/push/audience/preview')[0]).toMatchObject({
      audience: { type: 'SELF' },
      type: 'ANNOUNCEMENT',
    });
  });

  it('fakülte kitlesi seçiciyle değer gönderir', async () => {
    const calls = setupCompose(5);
    const user = userEvent.setup();
    await user.click(screen.getByRole('radio', { name: /Fakülte/ }));
    await user.selectOptions(await screen.findByRole('combobox', { name: /Fakülte/ }), 'Mühendislik Fakültesi');
    await waitFor(() =>
      expect(bodies(calls, '/audience-count')).toContainEqual({ type: 'FACULTY', value: 'Mühendislik Fakültesi' }),
    );
  });

  it('e-posta listesi yapıştırılınca sayıyı gösterir ve EMAILS kitlesi gönderir', async () => {
    const calls = setupCompose(3);
    const user = userEvent.setup();
    await user.click(screen.getByRole('radio', { name: /E-posta \/ numara listesi/ }));
    await user.click(screen.getByTestId('emails-input'));
    await user.paste('a@bingol.edu.tr, 1234\nb@bingol.edu.tr a@bingol.edu.tr');
    expect(screen.getByText('3 / 500 girdi')).toBeInTheDocument();
    await waitFor(() =>
      expect(bodies(calls, '/audience-count')).toContainEqual({
        type: 'EMAILS',
        value: 'a@bingol.edu.tr\n1234\nb@bingol.edu.tr',
      }),
    );
  });

  it('Kendime test gönder içerik dolunca açılır ve /campaigns/test uç noktasına gider', async () => {
    const calls = setupCompose(1);
    const user = userEvent.setup();
    const btn = screen.getByTestId('self-test');
    expect(btn).toBeDisabled();
    await user.type(screen.getByLabelText('Başlık'), 'Deneme');
    await user.type(screen.getByLabelText('Metin', { exact: true }), 'Metin');
    expect(btn).toBeEnabled();
    await user.click(btn);
    await waitFor(() => expect(bodies(calls, '/admin/push/campaigns/test')).toHaveLength(1));
    expect(bodies(calls, '/admin/push/campaigns/test')[0]).toMatchObject({ tr: { title: 'Deneme', body: 'Metin' } });
  });

  it('sessiz saat notu ve POLL hedefi görünür', () => {
    setupCompose();
    expect(screen.getByText(/Sessiz saatler toplu gönderimde uygulanmaz/)).toBeInTheDocument();
    expect(screen.getByRole('option', { name: 'Anket' })).toBeInTheDocument();
  });

  it('409 CAMPAIGN_DUPLICATE gönderimde çevrilmiş mesaj gösterir', async () => {
    setupCompose(4);
    const user = userEvent.setup();
    await waitFor(() => expect(screen.getByTestId('audience-count')).toHaveTextContent('4'));
    await user.type(screen.getByLabelText('Başlık'), 'Duyuru');
    await user.type(screen.getByLabelText('Metin', { exact: true }), 'Metin');
    await user.click(screen.getByTestId('send-button'));
    const dialog = await screen.findByRole('dialog');
    await user.click(within(dialog).getByTestId('confirm-send'));
    expect(await within(dialog).findAllByText(/İki dakika sonra yeniden deneyin/)).not.toHaveLength(0);
  });
});

const campaign = (over: Record<string, unknown> = {}) => ({
  id: 7,
  createdBy: 1,
  type: 'ANNOUNCEMENT',
  audience: { type: 'FACULTY', value: 'Hukuk Fakültesi' },
  tr: { title: 'Kampanya başlığı', body: 'Metin' },
  en: null,
  ar: null,
  target: { type: 'POLL', value: '3' },
  status: 'SCHEDULED',
  scheduledAt: '2099-01-01T10:00:00Z',
  startedAt: null,
  finishedAt: null,
  recipientCount: 80,
  audienceSize: 100,
  skippedCount: 20,
  source: 'CAMPAIGN',
  error: null,
  createdAt: '2026-10-01T10:00:00Z',
  ...over,
});

describe('bildirim gönderimi: kampanya listesi', () => {
  function setupList(status = 'SCHEDULED') {
    const calls: Call[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (/\/admin\/push\/campaigns\/7\/(pause|resume|cancel)$/.test(url)) return jsonResponse(204);
      if (url.includes('/admin/push/campaigns/7')) return jsonResponse(200, campaign({ status }));
      if (url.includes('/admin/push/campaigns')) return jsonResponse(200, { items: [campaign({ status })], nextCursor: null });
      if (url.includes('/admin/users/')) return jsonResponse(200, { id: 1, displayName: 'Yönetici', email: 'a@bingol.edu.tr' });
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderWithProviders(<CampaignsPage />, { route: '/admin/campaigns' });
    return calls;
  }

  it('sayaçları gösterir: alıcı / kitle ve tercihle atlananlar', async () => {
    setupList();
    expect(await screen.findByText('Kampanya başlığı')).toBeInTheDocument();
    expect(screen.getByText(/80 \/ 100/)).toBeInTheDocument();
    expect(screen.getByText('20 kişi tercihi nedeniyle atlandı')).toBeInTheDocument();
  });

  it('durum sekmesi sunucuya status süzgeci gönderir', async () => {
    const calls = setupList();
    const user = userEvent.setup();
    await screen.findByText('Kampanya başlığı');
    await user.click(screen.getByRole('tab', { name: 'Duraklatıldı' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('status=PAUSED'))).toBe(true));
  });

  it('zamanlanmış kampanya çekmecesinde duraklat çağrısı yapılır', async () => {
    const calls = setupList('SCHEDULED');
    const user = userEvent.setup();
    await user.click(await screen.findByText('Kampanya başlığı'));
    const dialog = await screen.findByRole('dialog');
    await user.click(await within(dialog).findByRole('button', { name: 'Duraklat' }));
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/campaigns/7/pause') && c.init.method === 'POST')).toBe(true));
    expect(within(dialog).getByText(/Sessiz saatler toplu gönderimde uygulanmaz/)).toBeInTheDocument();
  });

  it('duraklatılmış kampanyada devam ettir görünür, duraklat görünmez', async () => {
    const calls = setupList('PAUSED');
    const user = userEvent.setup();
    await user.click(await screen.findByText('Kampanya başlığı'));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).queryByRole('button', { name: 'Duraklat' })).not.toBeInTheDocument();
    await user.click(await within(dialog).findByRole('button', { name: 'Devam ettir' }));
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/campaigns/7/resume'))).toBe(true));
  });
});
