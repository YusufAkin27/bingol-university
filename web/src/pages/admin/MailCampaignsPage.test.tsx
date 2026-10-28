import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import MailCampaignsPage from './MailCampaignsPage';

vi.setConfig({ testTimeout: 20000 });

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const counters = (over: Record<string, unknown> = {}) => ({
  target: 1240,
  pending: 400,
  queued: 800,
  skipped: 38,
  failed: 2,
  cancelled: 0,
  skippedByReason: { SUPPRESSED: 30, INACTIVE: 8 },
  languages: { tr: 1100, en: 80 },
  languageFallback: 12,
  progressPercent: 67,
  ...over,
});
const campaign = (over: Record<string, unknown> = {}) => ({
  id: 5,
  name: 'Bahar şenliği',
  templateId: 7,
  templateName: 'Şenlik şablonu',
  templateVersion: 2,
  status: 'SENDING',
  audience: { type: 'ALL' },
  scheduledAt: null,
  resolvedAt: null,
  startedAt: '2026-11-01T06:00:10Z',
  finishedAt: null,
  createdBy: 1,
  createdAt: '2026-10-28T10:00:00Z',
  updatedAt: '2026-11-01T06:00:40Z',
  error: null,
  counters: counters(),
  ...over,
});
const PREVIEW = {
  total: 1240,
  willSend: 1198,
  skipped: 42,
  skippedByReason: { SUPPRESSED: 30, INACTIVE: 8, DUPLICATE_ADDRESS: 2, INVALID_ADDRESS: 2 },
  unmatched: 0,
  languages: { tr: 1100, en: 80, ar: 18 },
  languageFallback: 12,
};

function renderPage(route: string) {
  return renderWithProviders(
    <Routes>
      <Route path="/admin/mail/campaigns" element={<MailCampaignsPage />} />
      <Route path="/admin/mail/campaigns/:id" element={<MailCampaignsPage />} />
    </Routes>,
    { route },
  );
}

describe('kampanya listesi', () => {
  it('durumu metinle ve ilerleme çubuğuyla gösterir', async () => {
    mockFetch(() =>
      jsonResponse(200, { items: [campaign()], page: 0, totalPages: 1, totalItems: 1 }),
    );
    renderPage('/admin/mail/campaigns');
    expect(await screen.findByText('Bahar şenliği')).toBeInTheDocument();
    expect(screen.getAllByText('Gönderiliyor').length).toBeGreaterThan(0);
    const bar = screen.getByRole('progressbar');
    expect(bar).toHaveAttribute('aria-valuenow', '67');
  });

  it('boş durumda yönlendirir', async () => {
    mockFetch(() => jsonResponse(200, { items: [], page: 0, totalPages: 0, totalItems: 0 }));
    renderPage('/admin/mail/campaigns');
    expect(await screen.findByText('Henüz mail kampanyası yok')).toBeInTheDocument();
  });
});

describe('kampanya sihirbazı', () => {
  function setup(opts: { preview?: unknown; schedule?: () => Response } = {}) {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/admin/mail/templates'))
        return jsonResponse(200, {
          items: [{ id: 7, name: 'Şenlik şablonu', description: null, category: 'ANNOUNCEMENT', status: 'PUBLISHED', version: 2, languages: ['tr', 'en'], updatedAt: '2026-10-28T10:00:00Z' }],
          page: 0,
          totalPages: 1,
          totalItems: 1,
        });
      if (url.endsWith('/campaigns/audience/preview')) return jsonResponse(200, opts.preview ?? PREVIEW);
      if (url.endsWith('/admin/mail/campaigns') && init.method === 'POST')
        return jsonResponse(201, campaign({ status: 'DRAFT', counters: counters({ target: 0 }) }));
      if (url.endsWith('/campaigns/5/schedule')) return opts.schedule ? opts.schedule() : jsonResponse(202, campaign());
      if (url.includes('/campaigns/5/recipients')) return jsonResponse(200, { items: [], page: 0, totalPages: 0, totalItems: 0 });
      if (url.endsWith('/campaigns/5')) return jsonResponse(200, campaign());
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    return calls;
  }

  async function toPreview(user: ReturnType<typeof userEvent.setup>) {
    await user.type(screen.getByRole('textbox', { name: /^Kampanya adı/ }), 'Bahar şenliği');
    await user.selectOptions(await screen.findByLabelText(/^Şablon/), '7');
    await user.click(screen.getByRole('button', { name: 'İleri' }));
    await user.click(screen.getByRole('button', { name: 'İleri' })); // kitle: Tümü
  }

  it('yalnız yayındaki şablonları ister; şablon seçilmeden ilerlenemez', async () => {
    const calls = setup();
    renderPage('/admin/mail/campaigns/new');
    expect(await screen.findByLabelText(/^Şablon/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'İleri' })).toBeDisabled();
    expect(calls.some((c) => c.url.includes('status=PUBLISHED'))).toBe(true);
  });

  it('akış: önizleme sayıları, zamanlama, onay ve tek seferlik gönderim', async () => {
    const calls = setup();
    const user = userEvent.setup();
    renderPage('/admin/mail/campaigns/new');
    await toPreview(user);
    expect(await screen.findByTestId('will-send')).toHaveTextContent('1.198');
    expect(screen.getByText('Abonelikten çıkmış / bastırılmış adres')).toBeInTheDocument();
    expect(screen.getByText(/12 alıcı için şablonda kendi dili yok/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'İleri' })); // -> zamanlama
    await user.click(screen.getByRole('button', { name: 'İleri' })); // hemen -> onay
    expect(screen.getByText('Göndermeden önce kontrol edin')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Şimdi gönder' }));
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/campaigns/5/schedule'))).toBe(true));
    const create = calls.find((c) => c.url.endsWith('/admin/mail/campaigns') && c.init.method === 'POST');
    const body = JSON.parse(String(create?.init.body)) as { templateId: number; audience: unknown; requestKey: string; name: string };
    expect(body.templateId).toBe(7);
    expect(body.audience).toEqual({ type: 'ALL' });
    expect(body.requestKey).toMatch(/[0-9a-f-]{8,}/);
    expect(calls.filter((c) => c.url.endsWith('/admin/mail/campaigns') && c.init.method === 'POST')).toHaveLength(1);
    // başarıdan sonra ayrıntı sayfasına gider
    expect(await screen.findByRole('progressbar')).toBeInTheDocument();
  });

  it('alıcı çıkmıyorsa ileri engellenir ve açıklama gösterilir', async () => {
    setup({ preview: { ...PREVIEW, total: 3, willSend: 0, skipped: 3 } });
    const user = userEvent.setup();
    renderPage('/admin/mail/campaigns/new');
    await toPreview(user);
    expect(await screen.findByText('Bu kitlede gönderilecek alıcı yok.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'İleri' })).toBeDisabled();
  });

  it('süzgeç boşken ileri engellenir', async () => {
    setup();
    const user = userEvent.setup();
    renderPage('/admin/mail/campaigns/new');
    await user.type(screen.getByRole('textbox', { name: /^Kampanya adı/ }), 'x');
    await user.selectOptions(await screen.findByLabelText(/^Şablon/), '7');
    await user.click(screen.getByRole('button', { name: 'İleri' }));
    await user.click(screen.getByRole('radio', { name: /Süzgeç/ }));
    expect(screen.getByRole('button', { name: 'İleri' })).toBeDisabled();
    await user.type(screen.getByLabelText('Fakülte'), 'Mühendislik');
    expect(screen.getByRole('button', { name: 'İleri' })).toBeEnabled();
  });

  it('zamanlama hatasında yeniden denemede kampanya ikinci kez oluşturulmaz', async () => {
    let n = 0;
    const calls = setup({
      schedule: () => (n++ === 0 ? jsonResponse(400, { code: 'MAIL_CAMPAIGN_NO_RECIPIENTS', message: 'x' }) : jsonResponse(202, campaign())),
    });
    const user = userEvent.setup();
    renderPage('/admin/mail/campaigns/new');
    await toPreview(user);
    await user.click(await screen.findByRole('button', { name: 'İleri' }));
    await user.click(screen.getByRole('button', { name: 'İleri' }));
    await user.click(screen.getByRole('button', { name: 'Şimdi gönder' }));
    expect((await screen.findAllByText('Bu kitlede gönderilecek alıcı yok.')).length).toBeGreaterThan(0);
    await user.click(screen.getByRole('button', { name: 'Şimdi gönder' }));
    await waitFor(() => expect(calls.filter((c) => c.url.endsWith('/campaigns/5/schedule'))).toHaveLength(2));
    expect(calls.filter((c) => c.url.endsWith('/admin/mail/campaigns') && c.init.method === 'POST')).toHaveLength(1);
  });
});

describe('kampanya ayrıntısı', () => {
  it('sayaçları, kırılımları ve duraklatma onayını gösterir', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/recipients'))
        return jsonResponse(200, {
          items: [{ userId: 1, status: 'FAILED', skipReason: null, errorCode: 'ENQUEUE_ERROR', lang: 'tr', langFallback: false, email: 'a***@bingol.edu.tr', updatedAt: '2026-11-01T06:01:00Z' }],
          page: 0,
          totalPages: 1,
          totalItems: 1,
        });
      if (url.endsWith('/campaigns/5/pause')) return jsonResponse(200, campaign({ status: 'PAUSED' }));
      if (url.endsWith('/campaigns/5')) return jsonResponse(200, campaign());
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    const user = userEvent.setup();
    renderPage('/admin/mail/campaigns/5');
    expect(await screen.findByText('Gönderim sürerken bu sayfa 5 saniyede bir yenilenir.')).toBeInTheDocument();
    expect(screen.getByText('Abonelikten çıkmış / bastırılmış adres')).toBeInTheDocument();
    expect(await screen.findByText('a***@bingol.edu.tr')).toBeInTheDocument();
    expect(screen.getByText('ENQUEUE_ERROR')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Duraklat' }));
    const dlg = await screen.findByRole('dialog');
    await user.click(within(dlg).getByRole('button', { name: 'Duraklat' }));
    await waitFor(() => expect(calls.some((c) => c.url.endsWith('/campaigns/5/pause'))).toBe(true));
    expect((await screen.findAllByText('Duraklatıldı')).length).toBeGreaterThan(0);
  });

  it('bitmiş kampanyada işlem düğmesi ve yenileme notu yoktur', async () => {
    mockFetch((url) => {
      if (url.includes('/recipients')) return jsonResponse(200, { items: [], page: 0, totalPages: 0, totalItems: 0 });
      return jsonResponse(200, campaign({ status: 'DONE', counters: counters({ pending: 0, progressPercent: 100 }) }));
    });
    renderPage('/admin/mail/campaigns/5');
    await screen.findAllByText('Bitti');
    expect(screen.queryByRole('button', { name: 'İptal et' })).not.toBeInTheDocument();
    expect(screen.queryByText(/5 saniyede bir/)).not.toBeInTheDocument();
  });

  it('bulunamadı hatasını çevirir', async () => {
    mockFetch(() => jsonResponse(404, { code: 'MAIL_CAMPAIGN_NOT_FOUND', message: 'x' }));
    renderPage('/admin/mail/campaigns/5');
    expect(await screen.findByText('Kampanya bulunamadı.')).toBeInTheDocument();
  });
});
