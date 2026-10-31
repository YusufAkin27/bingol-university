/**
 * W2-K / T-157: push cihaz son sonucu (lastPush*), FCM kapalı nedeni, DEAD hata kodu dağılımı.
 */
import { screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import { PushDevicesTab } from '../users/PushDevicesTab';
import { DeadCodes } from './DeadCodes';
import { FcmTab } from './FcmTab';
import { fcmOffReason, groupByErrorCode } from './lib';

afterEach(() => vi.unstubAllGlobals());

describe('groupByErrorCode', () => {
  it('çoktan aza sıralar, kodsuzları UNKNOWN sayar, eşitlikte koda göre', () => {
    const rows = [
      { errorCode: 'UNREGISTERED' },
      { errorCode: 'THIRD_PARTY_AUTH_ERROR' },
      { errorCode: 'UNREGISTERED' },
      { errorCode: null },
      { errorCode: '  ' },
      { errorCode: 'EXPIRED' },
    ];
    expect(groupByErrorCode(rows)).toEqual([
      { code: 'UNKNOWN', count: 2 },
      { code: 'UNREGISTERED', count: 2 },
      { code: 'EXPIRED', count: 1 },
      { code: 'THIRD_PARTY_AUTH_ERROR', count: 1 },
    ]);
    expect(groupByErrorCode([])).toEqual([]);
  });
});

describe('fcmOffReason', () => {
  it('NO_CREDENTIALS / INIT_FAILED:<sınıf> / diğer / boş', () => {
    expect(fcmOffReason('NO_CREDENTIALS')).toEqual({ kind: 'NO_CREDENTIALS', detail: null });
    expect(fcmOffReason('INIT_FAILED:IOException')).toEqual({ kind: 'INIT_FAILED', detail: 'IOException' });
    expect(fcmOffReason('INIT_FAILED')).toEqual({ kind: 'INIT_FAILED', detail: null });
    expect(fcmOffReason('bilinmeyen')).toEqual({ kind: 'OTHER', detail: 'bilinmeyen' });
    expect(fcmOffReason(null)).toBeNull();
    expect(fcmOffReason('  ')).toBeNull();
  });
});

describe('FcmTab kapalı nedeni (A3-23)', () => {
  it('kimlik yoksa Türkçe açıklama gösterir', async () => {
    mockFetch(() => jsonResponse(200, { enabled: false, validated: false, projectId: null, error: 'NO_CREDENTIALS' }));
    renderWithProviders(<FcmTab />);
    const why = await screen.findByTestId('fcm-why');
    expect(why).toHaveTextContent('FCM neden kapalı?');
    expect(why).toHaveTextContent('Firebase kimlik bilgisi girilmemiş');
  });

  it('başlatma hatasında hata sınıfını da yazar', async () => {
    mockFetch(() =>
      jsonResponse(200, { enabled: false, validated: false, projectId: null, error: 'INIT_FAILED:IllegalStateException' }),
    );
    renderWithProviders(<FcmTab />);
    const why = await screen.findByTestId('fcm-why');
    expect(why).toHaveTextContent('Firebase başlatılamadı');
    expect(why).toHaveTextContent('IllegalStateException');
  });

  it('FCM açıkken neden bölümü yoktur', async () => {
    mockFetch(() => jsonResponse(200, { enabled: true, validated: false, projectId: 'bu-kampus-prod', error: null }));
    renderWithProviders(<FcmTab />);
    await screen.findByText('bu-kampus-prod');
    expect(screen.queryByTestId('fcm-why')).toBeNull();
  });
});

describe('DeadCodes (A3-23)', () => {
  it('DEAD kayıtların hata kodlarını açıklamalarıyla sayar ve yalnız DEAD ister', async () => {
    const f = mockFetch(() =>
      jsonResponse(200, {
        items: [
          { id: 1, status: 'DEAD', errorCode: 'UNREGISTERED' },
          { id: 2, status: 'DEAD', errorCode: 'UNREGISTERED' },
          { id: 3, status: 'DEAD', errorCode: 'THIRD_PARTY_AUTH_ERROR' },
        ],
        page: 0,
        totalPages: 1,
        totalItems: 3,
      }),
    );
    renderWithProviders(<DeadCodes />);
    const table = await screen.findByRole('table', { name: 'DEAD kayıtlar hata koduna göre' });
    const rows = within(table).getAllByRole('row');
    expect(rows[1]).toHaveTextContent('UNREGISTERED');
    expect(rows[1]).toHaveTextContent('2');
    expect(rows[1]).toHaveTextContent('uygulama silinmiş');
    expect(rows[2]).toHaveTextContent('THIRD_PARTY_AUTH_ERROR');
    expect(String(f.mock.calls[0][0])).toContain('status=DEAD');
  });
});

describe('PushDevicesTab son push sonucu (A3-07)', () => {
  const device = (extra: Record<string, unknown>) => ({
    id: 1,
    platform: 'ios',
    appVersion: '2.0.3',
    locale: 'tr',
    tokenTail: 'abc123',
    createdAt: '2026-10-01T10:00:00Z',
    lastSeenAt: '2026-10-30T10:00:00Z',
    ...extra,
  });

  it('başarısız son push için durum + hata kodu + Türkçe açıklama + cihaz dili gösterilir', async () => {
    mockFetch(() =>
      jsonResponse(200, [
        device({ lastPushStatus: 'DEAD', lastPushErrorCode: 'THIRD_PARTY_AUTH_ERROR', lastPushAt: '2026-10-30T09:00:00Z' }),
      ]),
    );
    renderWithProviders(<PushDevicesTab userId={7} />);
    const last = await screen.findByTestId('last-push');
    expect(last).toHaveTextContent('Son push');
    expect(last).toHaveTextContent('Başarısız (vazgeçildi)');
    const err = screen.getByTestId('last-push-error');
    expect(err).toHaveTextContent('THIRD_PARTY_AUTH_ERROR');
    expect(err).toHaveTextContent('Apple (APNs) kimlik doğrulaması başarısız');
    expect(screen.getByText(/Cihaz dili: tr/)).toBeInTheDocument();
  });

  it('kuyruk kaydı yoksa "kayıt yok" notu; başarılıysa hata satırı yok; bilinmeyen kod ham gösterilir', async () => {
    mockFetch(() =>
      jsonResponse(200, [
        device({ id: 1 }),
        device({ id: 2, lastPushStatus: 'SENT', lastPushAt: '2026-10-30T09:00:00Z' }),
        device({ id: 3, lastPushStatus: 'DEAD', lastPushErrorCode: 'ZZ_YENI_KOD' }),
      ]),
    );
    renderWithProviders(<PushDevicesTab userId={7} />);
    await waitFor(() => expect(screen.getAllByTestId('last-push')).toHaveLength(3));
    const [a, b] = screen.getAllByTestId('last-push');
    expect(a).toHaveTextContent('push kaydı yok');
    expect(b).toHaveTextContent('Gönderildi');
    const errs = screen.getAllByTestId('last-push-error');
    expect(errs).toHaveLength(1);
    expect(errs[0]).toHaveTextContent('ZZ_YENI_KOD');
    expect(errs[0]).toHaveTextContent('Açıklaması yok');
  });
});
