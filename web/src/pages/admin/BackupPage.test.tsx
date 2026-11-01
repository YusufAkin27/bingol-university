// GD1: yedekleme (Google Drive) sayfası — durum kartları (Bağlı/Kurulmadı/Hata), uç 404 iken rehber, kopyala, adım katlama.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { agoParts, driveState, freshness, isEndpointMissing } from './backup/lib';
import { ApiError } from '../../api/client';
import type { BackupStatus } from '../../api/backup';
import { allGuideKeys, GUIDE_STEPS, RCLONE_AUTH_CMD, RCLONE_CONF_TEMPLATE } from './backup/guide';
import tr from '../../i18n/tr/admin-gd1';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import BackupPage from './BackupPage';

vi.setConfig({ testTimeout: 20000 });

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const iso = (msAgo: number) => new Date(Date.now() - msAgo).toISOString();

const base = (over: Partial<BackupStatus> = {}): BackupStatus => ({
  local: { count: 14, bytes: 3 * 1024 * 1024 * 1024, oldestAt: '2026-10-20T09:00:00Z' },
  remote: {
    configured: true,
    kind: 'drive',
    name: 'gdrive:BU-Kampus-Yedek',
    lastSuccessAt: iso(30 * 60_000),
    lastVerifiedAt: iso(20 * 60_000),
    lastError: null,
    bytes: 2 * 1024 * 1024 * 1024,
    count: 21,
  },
  lastSuccessAt: iso(30 * 60_000),
  lastStatus: 'OK',
  schedule: { cron: '5 * * * *', verifyCron: '30 4 * * 0' },
  retention: { localDaily: 7, localWeekly: 4, localMonthly: 3, remoteDaily: 24, remoteWeekly: 8, remoteMonthly: 6 },
  ...over,
});

function setup(handler: () => Response) {
  return mockFetch((url) => (url.includes('/admin/system/backup') ? handler() : jsonResponse(404, { code: 'NOT_FOUND', message: 'x' })));
}

describe('Yedekleme sayfası durum kartları', () => {
  it('Bağlı ve doğrulandı: kartlar adet/boyut/saklama gösterir, uyarı yok, rehber kapalı', async () => {
    setup(() => jsonResponse(200, base()));
    renderWithProviders(<BackupPage />);
    const drive = await screen.findByTestId('gd-drive');
    expect(within(drive).getByText('Bağlı ve doğrulandı')).toBeInTheDocument();
    expect(within(drive).getByText('Hedef: gdrive:BU-Kampus-Yedek')).toBeInTheDocument();
    expect(within(screen.getByTestId('gd-last')).getByText('Güncel')).toBeInTheDocument();
    expect(within(screen.getByTestId('gd-last')).getByText('30 dk önce')).toBeInTheDocument();
    expect(within(screen.getByTestId('gd-local')).getByText('14 yedek')).toBeInTheDocument();
    expect(within(screen.getByTestId('gd-local')).getByText('3 GB')).toBeInTheDocument();
    expect(within(screen.getByTestId('gd-remote')).getByText('21 yedek')).toBeInTheDocument();
    expect(within(screen.getByTestId('gd-retention')).getByText(/Saatlik 24 · haftalık 8 · aylık 6/)).toBeInTheDocument();
    expect(screen.queryByText('Yedekler yalnız sunucu diskinde', { selector: 'p' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^0\. Neden ve özet/ })).toHaveAttribute('aria-expanded', 'false');
    expect(screen.getByText('Google Drive bağlı görünüyor. Rehber yalnız başvuru içindir.')).toBeInTheDocument();
  });

  it('Kurulmadı: sarı uyarı "Yedekler yalnız sunucu diskinde" ve rehber ilk adım açık', async () => {
    setup(() =>
      jsonResponse(
        200,
        base({
          remote: { configured: false, kind: null, name: null, lastSuccessAt: null, lastVerifiedAt: null, lastError: null, bytes: null, count: null },
        }),
      ),
    );
    renderWithProviders(<BackupPage />);
    const drive = await screen.findByTestId('gd-drive');
    expect(within(drive).getByText('Kurulmadı')).toBeInTheDocument();
    expect(screen.getByText('Yedekler yalnız sunucu diskinde', { selector: 'p' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Kurulum rehberine git' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^0\. Neden ve özet/ })).toHaveAttribute('aria-expanded', 'true');
    expect(within(screen.getByTestId('gd-remote')).getByText('Drive kurulmadığı için yedek yok')).toBeInTheDocument();
  });

  it('Hata: son hata gösterilir, kart tehlike tonunda', async () => {
    setup(() =>
      jsonResponse(
        200,
        base({
          remote: { ...base().remote!, lastError: 'invalid_grant: Token has been expired or revoked.', lastVerifiedAt: null },
        }),
      ),
    );
    renderWithProviders(<BackupPage />);
    const drive = await screen.findByTestId('gd-drive');
    expect(within(drive).getByText('Hata')).toBeInTheDocument();
    expect(within(drive).getByText(/invalid_grant: Token has been expired or revoked\./)).toBeInTheDocument();
    expect(drive).toHaveAttribute('data-tone', 'danger');
  });

  it('uç 404: durum bilgisi notu çıkar ama rehber ve adımlar görünür', async () => {
    setup(() => jsonResponse(404, { code: 'NOT_FOUND', message: 'yok' }));
    renderWithProviders(<BackupPage />);
    expect(await screen.findByText(/Durum bilgisi henüz alınamıyor/)).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Kurulum rehberi' })).toBeInTheDocument();
    expect(screen.getByText(RCLONE_AUTH_CMD)).toBeInTheDocument();
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });

  it('sunucu hatası (500): hata durumu + yeniden dene, rehber yine görünür', async () => {
    setup(() => jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' }));
    renderWithProviders(<BackupPage />);
    expect(await screen.findByText('Durum bilgisi alınamadı.')).toBeInTheDocument();
    expect(screen.getByText(RCLONE_AUTH_CMD)).toBeInTheDocument();
  });
});

describe('Kurulum rehberi', () => {
  it('Kopyala düğmesi komutu panoya yazar', async () => {
    setup(() => jsonResponse(404, { code: 'NOT_FOUND', message: 'x' }));
    const user = userEvent.setup();
    const writeText = vi.spyOn(navigator.clipboard, 'writeText').mockResolvedValue(undefined);
    renderWithProviders(<BackupPage />);
    await screen.findByText(/Durum bilgisi henüz alınamıyor/);
    // 0. adım açık; 2. adımı aç ve kopyala
    await user.click(screen.getByRole('button', { name: /^2\. Google hesabınıza izin verin/ }));
    await user.click(screen.getByRole('button', { name: 'Komutu kopyala: İzin komutu' }));
    expect(writeText).toHaveBeenCalledWith(RCLONE_AUTH_CMD);
    await waitFor(() => expect(screen.getAllByText('Kopyalandı').length).toBeGreaterThan(0));
  });

  it('adımlar katlanır; Tümünü aç/kapat çalışır', async () => {
    setup(() => jsonResponse(404, { code: 'NOT_FOUND', message: 'x' }));
    const user = userEvent.setup();
    renderWithProviders(<BackupPage />);
    await screen.findByText(/Durum bilgisi henüz alınamıyor/);
    const step3 = screen.getByRole('button', { name: /^3\. Sunucuda rclone\.conf/ });
    expect(step3).toHaveAttribute('aria-expanded', 'false');
    await user.click(step3);
    expect(step3).toHaveAttribute('aria-expanded', 'true');
    expect(screen.getByText(/^\[gdrive\]/, { selector: 'code' }).textContent).toBe(RCLONE_CONF_TEMPLATE);
    await user.click(step3);
    expect(step3).toHaveAttribute('aria-expanded', 'false');
    await user.click(screen.getByRole('button', { name: 'Tümünü aç' }));
    const toggles = screen.getAllByRole('button', { expanded: true });
    expect(toggles.length).toBe(GUIDE_STEPS.length + 1);
    await user.click(screen.getByRole('button', { name: 'Tümünü kapat' }));
    expect(screen.queryAllByRole('button', { expanded: true })).toHaveLength(0);
  });

  it('uyarılar: kurtarma anahtarı kasada, 2 adımlı doğrulama, silme geri alınamaz', async () => {
    setup(() => jsonResponse(404, { code: 'NOT_FOUND', message: 'x' }));
    const user = userEvent.setup();
    renderWithProviders(<BackupPage />);
    await screen.findByText(/Durum bilgisi henüz alınamıyor/);
    await user.click(screen.getByRole('button', { name: 'Tümünü aç' }));
    expect(screen.getAllByText('Kurtarma anahtarı sunucuda DEĞİL, kasada olmalı').length).toBeGreaterThan(0);
    expect(screen.getByText('Drive hesabında 2 adımlı doğrulama açın')).toBeInTheDocument();
    expect(screen.getByText('Silme işlemi geri alınamaz')).toBeInTheDocument();
  });

  it('sayfa sır toplamaz: hiçbir metin/parola alanı yok', async () => {
    setup(() => jsonResponse(404, { code: 'NOT_FOUND', message: 'x' }));
    renderWithProviders(<BackupPage />);
    await screen.findByText(/Durum bilgisi henüz alınamıyor/);
    expect(screen.queryAllByRole('textbox')).toHaveLength(0);
    expect(document.querySelectorAll('input, textarea')).toHaveLength(0);
  });
});

describe('lib', () => {
  const now = Date.parse('2026-11-01T12:00:00Z');
  it('driveState', () => {
    expect(driveState(null)).toBe('UNAVAILABLE');
    expect(driveState(base({ remote: { ...base().remote!, configured: false } }))).toBe('NOT_CONFIGURED');
    expect(driveState(base({ remote: { ...base().remote!, lastError: 'x' } }))).toBe('ERROR');
    expect(driveState(base({ remote: { ...base().remote!, lastVerifiedAt: null } }))).toBe('PENDING');
    expect(driveState(base())).toBe('OK');
  });
  it('freshness eşikleri', () => {
    const at = (h: number) => base({ lastSuccessAt: new Date(now - h * 3_600_000).toISOString() });
    expect(freshness(at(1), now)).toBe('FRESH');
    expect(freshness(at(4), now)).toBe('STALE');
    expect(freshness(at(30), now)).toBe('OLD');
    expect(freshness(base({ lastSuccessAt: null, lastStatus: null }), now)).toBe('NONE');
    expect(freshness(base({ lastStatus: 'FAILED' }), now)).toBe('FAILED');
  });
  it('agoParts', () => {
    expect(agoParts('2026-11-01T11:59:40Z', now)).toEqual({ unit: 'now', n: 0 });
    expect(agoParts('2026-11-01T11:15:00Z', now)).toEqual({ unit: 'min', n: 45 });
    expect(agoParts('2026-11-01T07:00:00Z', now)).toEqual({ unit: 'hour', n: 5 });
    expect(agoParts('2026-10-25T12:00:00Z', now)).toEqual({ unit: 'day', n: 7 });
    expect(agoParts(null, now)).toBeNull();
    expect(agoParts('bozuk', now)).toBeNull();
  });
  it('isEndpointMissing', () => {
    expect(isEndpointMissing(new ApiError(404, 'NOT_FOUND', 'x'))).toBe(true);
    expect(isEndpointMissing(new ApiError(501, 'X', 'x'))).toBe(true);
    expect(isEndpointMissing(new ApiError(500, 'X', 'x'))).toBe(false);
    expect(isEndpointMissing(new Error('x'))).toBe(false);
  });
});

describe('i18n ve komutlar', () => {
  it('rehberin kullandığı her çeviri anahtarı Türkçe sözlükte var ve boş değil', () => {
    const dict = tr as Record<string, string>;
    for (const k of allGuideKeys()) {
      expect(dict[k], k).toBeTruthy();
    }
  });
  it('yönetim sözlüğü en/ar paketlerine de katılır (yalnız Türkçe ad alanı)', async () => {
    const mod = await import('../../i18n/bundles/admin-tr-only');
    expect((mod.default as Record<string, string>)['admin.gd1.nav']).toBe('Yedekleme (Google Drive)');
  });
  it('komut blokları sır içermez (yalnız yer tutucu)', () => {
    const all = GUIDE_STEPS.flatMap((s) => s.items)
      .filter((i) => i.kind === 'code')
      .map((i) => (i.kind === 'code' ? i.code : ''))
      .join('\n');
    expect(all).not.toMatch(/refresh_token|access_token|AGE-SECRET-KEY|PRIVATE KEY/i);
    expect(RCLONE_CONF_TEMPLATE).toContain('<');
    expect(RCLONE_AUTH_CMD).toContain('eyJzY29wZSI6ImRyaXZlLmZpbGUifQ');
  });
});
