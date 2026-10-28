import { screen, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import { CampaignFailures } from './CampaignFailures';
import { codeKey, dayRate, failureCounts, parseCampaignId, percent, validDate } from './lib';

afterEach(() => vi.unstubAllGlobals());

describe('CampaignFailures (kampanya çekmecesi "Hatalar")', () => {
  it('FCM hata koduna göre gruplu sayıları ve durum toplamlarını gösterir; alıcı kimliği yok', async () => {
    mockFetch((url) =>
      url === '/api/admin/push/campaigns/7/failures'
        ? jsonResponse(200, {
            campaignId: 7,
            linked: true,
            totals: { PENDING: 0, SENDING: 0, SENT: 940, FAILED: 3, DEAD: 57, CANCELLED: 0 },
            groups: [
              { errorCode: 'UNREGISTERED', status: 'DEAD', count: 50, lastAt: '2026-10-28T09:00:00Z' },
              { errorCode: 'INVALID_ARGUMENT', status: 'DEAD', count: 7, lastAt: '2026-10-28T09:00:00Z' },
              { errorCode: 'QUOTA_EXCEEDED', status: 'FAILED', count: 3, lastAt: null },
            ],
            truncated: false,
          })
        : jsonResponse(404, { code: 'X', message: 'x' }),
    );
    renderWithProviders(<CampaignFailures campaignId={7} />);
    const table = await screen.findByRole('table', { name: /gönderim hataları/ });
    expect(within(table).getByText('UNREGISTERED')).toBeInTheDocument();
    expect(within(table).getByText('50')).toBeInTheDocument();
    expect(within(table).getByText('INVALID_ARGUMENT')).toBeInTheDocument();
    expect(within(table).getByText(/Firebase gönderim kotası aşıldı/)).toBeInTheDocument();
    expect(screen.getByTestId('push-failure-totals')).toHaveTextContent('Gönderildi: 940');
    expect(screen.getByTestId('push-failure-totals')).toHaveTextContent('Başarısız (vazgeçildi): 57');
    expect(screen.queryByTestId('push-failure-totals')?.textContent).not.toContain('İptal');
  });

  it('bağlı kayıt yoksa açıklama; hata yoksa olumlu mesaj; uç yoksa sessiz not', async () => {
    mockFetch(() =>
      jsonResponse(200, { campaignId: 8, linked: false, totals: {}, groups: [], truncated: false }),
    );
    const { unmount } = renderWithProviders(<CampaignFailures campaignId={8} />);
    expect(await screen.findByText(/Bu kampanyaya bağlı kuyruk kaydı yok/)).toBeInTheDocument();
    unmount();

    mockFetch(() =>
      jsonResponse(200, { campaignId: 9, linked: true, totals: { SENT: 10 }, groups: [], truncated: false }),
    );
    const second = renderWithProviders(<CampaignFailures campaignId={9} />);
    expect(await screen.findByText('Cihaz bazında gönderim hatası yok.')).toBeInTheDocument();
    second.unmount();

    mockFetch(() => jsonResponse(404, { code: 'CAMPAIGN_NOT_FOUND', message: 'x' }));
    renderWithProviders(<CampaignFailures campaignId={10} />);
    expect(await screen.findByText('Hata bilgisi şu an alınamadı.')).toBeInTheDocument();
  });
});

describe('push altyapısı yardımcıları', () => {
  it('kod anahtarı, yüzde, tarih ve kampanya numarası doğrulaması', () => {
    expect(codeKey('UNREGISTERED')).toBe('admin.p14.code.UNREGISTERED');
    expect(codeKey('SOMETHING_NEW')).toBeNull();
    expect(codeKey(null)).toBeNull();
    expect(percent(0.4237)).toBe(42.4);
    expect(percent(null)).toBeNull();
    expect(dayRate(0, 0)).toBeNull();
    expect(dayRate(3, 1)).toBe(33.3);
    expect(validDate('')).toBe(true);
    expect(validDate('2026-10-01')).toBe(true);
    expect(validDate('01.10.2026')).toBe(false);
    expect(parseCampaignId('#12')).toBe(12);
    expect(parseCampaignId(' 7 ')).toBe(7);
    expect(parseCampaignId('0')).toBeNull();
    expect(parseCampaignId('1e3')).toBeNull();
    expect(failureCounts([{ code: 'A' }, { code: 'B' }, { code: 'A' }])).toEqual({ A: 2, B: 1 });
  });
});
