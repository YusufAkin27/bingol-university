// UPDATEGATE: sürüm dağılımı, durum rozeti, "Yeni sürümü yayınla" sihirbazı (etki önizlemesi, uyarılar, sebep + ZORLA onayı),
// ekran önizlemesi ve izin kontrolü.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import AppVersionsPage from './AppVersionsPage';

vi.setConfig({ testTimeout: 20000 });

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

interface Call {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: unknown;
}

const dist = (over: Record<string, unknown> = {}) => ({
  distribution: [
    { platform: 'android', version: '2.0.4', devices: 100 },
    { platform: 'android', version: '2.0.2', devices: 30 },
    { platform: 'android', version: null, devices: 7 },
    { platform: 'ios', version: '2.0.2', devices: 11 },
  ],
  platforms: [
    { platform: 'android', minVersion: '2.0.3', latestVersion: '2.0.5', state: 'FORCE', total: 137, unknownVersion: 7, belowMin: 30, belowLatest: 130 },
    { platform: 'ios', minVersion: '1.0.0', latestVersion: '1.0.0', state: 'OFF', total: 11, unknownVersion: 0, belowMin: 0, belowLatest: 0 },
  ],
  total: 148,
  belowMin: 30,
  belowLatest: 30,
  source: 'USER_DEVICE_LOG',
  sourceNote: 'Giriş yapmış kullanıcıların son 30 günde sunucuya ulaşan istekleri.',
  windowDays: 30,
  ...over,
});

const settings = {
  store_url_android: '',
  store_url_ios: '',
  store_package_android: 'tr.com.bukampus.app',
  apple_app_id_ios: '',
  update_message_tr: 'Önemli bir düzeltme yayınlandı.',
  update_message_en: '',
  update_message_ar: '',
};

function setup(perms = ['settings.read', 'settings.write', 'admin.full'], d = dist()) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({
      url,
      method,
      headers: (init.headers ?? {}) as Record<string, string>,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
    });
    if (url === '/api/admin/rbac/me') return jsonResponse(200, { profile: 'FULL', permissions: perms, twoPerson: false });
    if (url === '/api/admin/app-versions' && method === 'GET') return jsonResponse(200, d);
    if (url === '/api/admin/settings') return jsonResponse(200, settings);
    if (url === '/api/admin/app-versions/enforce' && method === 'POST') {
      return jsonResponse(200, {
        platform: 'android', mode: 'FORCE', state: 'FORCE', minVersion: '2.0.5', latestVersion: '2.0.5',
        previousMin: '2.0.3', previousLatest: '2.0.4', affectedDevices: 130, platformDevices: 137,
        source: 'USER_DEVICE_LOG', sourceNote: 'x',
      });
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}
const writes = (calls: Call[]) => calls.filter((c) => c.method !== 'GET' && c.url.includes('enforce'));

describe('dağılım', () => {
  it('durum rozeti, sürümler, "bu sürümün altında" vurgusu ve kaynak notu görünür', async () => {
    setup();
    renderWithProviders(<AppVersionsPage />);
    const android = await screen.findByRole('region', { name: 'Android' });
    expect(within(android).getByText('Zorunlu güncelleme AÇIK')).toBeInTheDocument();
    expect(within(android).getByText('Yayındaki sürüm')).toBeInTheDocument();
    expect(screen.getByTestId('uv-below-android')).toHaveTextContent('Bu sürümün altında: 30 cihaz');
    const table = within(android).getByRole('table');
    expect(within(table).getByText('Zorunlu güncelleme görür')).toBeInTheDocument();
    expect(within(table).getByText('Güncelleme önerilir')).toBeInTheDocument();
    expect(within(table).getByText('Bilinmiyor')).toBeInTheDocument();
    const ios = screen.getByRole('region', { name: 'iOS' });
    expect(within(ios).getByText('Kapalı')).toBeInTheDocument();
    expect(screen.getByTestId('uv-below-ios')).toHaveTextContent('Zorunlu en düşük sürümün altında cihaz yok.');
    expect(screen.getByText(/Cihaz sayıları nereden geliyor/)).toBeInTheDocument();
    expect(screen.getByText(/son 30 günde sunucuya ulaşan istekleri/)).toBeInTheDocument();
  });

  it('min > latest tutarsızlığı uyarısı', async () => {
    const d = dist();
    d.platforms[0] = { ...d.platforms[0], minVersion: '2.1.0', latestVersion: '2.0.4' };
    setup(undefined, d);
    renderWithProviders(<AppVersionsPage />);
    expect(await screen.findByText(/büyük görünüyor/)).toBeInTheDocument();
  });
});

describe('sihirbaz', () => {
  it('etki önizlemesi gösterir, sebep + ZORLA ister ve zorlama isteğini sebep başlığıyla gönderir', async () => {
    const calls = setup();
    renderWithProviders(<AppVersionsPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByTestId('uv-publish-android'));
    const modal = await screen.findByRole('dialog');
    const version = within(modal).getByTestId('uv-version');
    await user.clear(version);
    await user.type(version, '2.0.5');
    expect(within(modal).getByTestId('uv-impact')).toHaveTextContent('yaklaşık 130 cihaz güncelleme ekranını görür');
    await user.click(within(modal).getByTestId('uv-next'));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('Zorunlu güncelleme açılsın mı?');
    const confirm = within(dialog).getByRole('button', { name: 'Zorunlu güncelle' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByLabelText(/Sebep/), 'kritik hata düzeltmesi');
    expect(confirm).toBeDisabled(); // ZORLA yazılmadı
    await user.type(within(dialog).getByLabelText('Onay metni'), 'ZORLA');
    await user.click(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    const w = writes(calls)[0];
    expect(w.body).toEqual({ platform: 'android', mode: 'FORCE', version: '2.0.5' });
    expect(decodeURIComponent(w.headers['X-Admin-Reason'])).toBe('kritik hata düzeltmesi');
    expect(w.headers['Idempotency-Key']).toBeTruthy();
  });

  it('yayındakinden düşük zorunlu sürüm hata verir ve ilerlenemez', async () => {
    setup();
    renderWithProviders(<AppVersionsPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByTestId('uv-publish-android'));
    const modal = await screen.findByRole('dialog');
    const version = within(modal).getByTestId('uv-version');
    await user.clear(version);
    await user.type(version, '2.0.1');
    expect(within(modal).getByRole('alert')).toHaveTextContent('yayındaki sürümden (2.0.5) düşük olamaz');
    expect(within(modal).getByTestId('uv-next')).toBeDisabled();
  });

  it('iOS bağlantısızken FORCE uyarısı: düğme çalışmaz', async () => {
    setup();
    renderWithProviders(<AppVersionsPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByTestId('uv-publish-ios'));
    const modal = await screen.findByRole('dialog');
    const version = within(modal).getByTestId('uv-version');
    await user.clear(version);
    await user.type(version, '2.0.5');
    expect(within(modal).getByText(/"Güncelle" düğmesi çalışmaz/)).toBeInTheDocument();
    expect(within(modal).getByText(/iOS uygulaması henüz mağazada değilse/)).toBeInTheDocument();
  });

  it('zorunluluğu kaldır: sürüm istemez, ZORLA gerekmez, gövdede sürüm yok', async () => {
    const calls = setup();
    renderWithProviders(<AppVersionsPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByTestId('uv-publish-android'));
    const modal = await screen.findByRole('dialog');
    await user.click(within(modal).getByLabelText(/Zorunluluğu kaldır/));
    expect(within(modal).queryByTestId('uv-version')).not.toBeInTheDocument();
    expect(within(modal).getByTestId('uv-impact')).toHaveTextContent('Zorunluluk kalkar');
    await user.click(within(modal).getByTestId('uv-next'));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).queryByLabelText('Onay metni')).not.toBeInTheDocument();
    await user.type(within(dialog).getByLabelText(/Sebep/), 'geri alındı');
    await user.click(within(dialog).getByRole('button', { name: 'Zorunluluğu kaldır' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].body).toEqual({ platform: 'android', mode: 'OFF' });
  });
});

describe('önizleme ve izin', () => {
  it('telefon önizlemesi yönetici metnini gösterir, dil değişince varsayılan metne düşer', async () => {
    setup();
    renderWithProviders(<AppVersionsPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByTestId('uv-preview-android'));
    const dialog = await screen.findByRole('dialog');
    await waitFor(() => expect(within(dialog).getByTestId('uv-phone-body')).toHaveTextContent('Önemli bir düzeltme yayınlandı.'));
    expect(within(dialog).getByText('Güncelle')).toBeInTheDocument();
    expect(within(dialog).getByText(/Google Play \(tr\.com\.bukampus\.app\)/)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'EN' }));
    // İngilizce boş: Türkçe metne düşer (sunucuyla aynı)
    expect(within(dialog).getByTestId('uv-phone-body')).toHaveTextContent('Önemli bir düzeltme yayınlandı.');
  });

  it('iOS önizlemesinde bağlantı yoksa düğme yerine yazı çıkar', async () => {
    setup();
    renderWithProviders(<AppVersionsPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByTestId('uv-preview-ios'));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByText('Mağazadan güncelleyin')).toBeInTheDocument();
    expect(within(dialog).queryByText('Güncelle')).not.toBeInTheDocument();
  });

  it('yazma izni yoksa "Yeni sürümü yayınla" kapalı', async () => {
    setup(['settings.read']);
    renderWithProviders(<AppVersionsPage />);
    await screen.findByRole('region', { name: 'Android' });
    await waitFor(() => expect(screen.getByTestId('uv-publish-android')).toBeDisabled());
  });
});
