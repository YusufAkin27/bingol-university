import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { clearTokens, setTokens } from '../../auth/tokens';
import { headerOf, jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import CampusMapPage from './CampusMapPage';

const BOUNDARY = [
  [38.87, 40.48],
  [38.87, 40.52],
  [38.9, 40.52],
  [38.9, 40.48],
];

const config = {
  center: { lat: 38.8847, lng: 40.4981 },
  zoom: { initial: 16, min: 14, max: 19 },
  boundary: BOUNDARY,
  tiles: { urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', attribution: '© OpenStreetMap', maxNativeZoom: 19 },
};

const place = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  name: `Yer ${id}`,
  category: 'faculty',
  lat: 38.88 + id / 1000,
  lng: 40.49,
  summary: null,
  photoUrl: null,
  units: [],
  footprint: null,
  sortKey: id,
  active: true,
  ...over,
});

const PLACES = [
  place(1, { name: 'Mühendislik Fakültesi', units: ['Bilgisayar Mühendisliği'], updatedAt: '2026-10-30T10:00:00Z' }),
  place(2, { name: 'Merkez Kütüphane', category: 'library', active: false }),
  place(3, { name: 'Çınar Yemekhanesi', category: 'dining' }),
];

interface Call {
  url: string;
  method: string;
  body: unknown;
  reason?: string;
}

interface Opts {
  permissions?: string[];
  places?: unknown;
  placesStatus?: number;
  configStatus?: number;
  hang?: boolean;
}

function setup(opts: Opts = {}) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({
      url,
      method,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
      reason: headerOf(init, 'X-Admin-Reason'),
    });
    if (url.endsWith('/admin/me')) {
      return jsonResponse(200, { id: 1, email: 'a@bingol.edu.tr', displayName: 'Yönetici', role: 'ADMIN' });
    }
    if (url.endsWith('/admin/rbac/me')) {
      return opts.permissions
        ? jsonResponse(200, { userId: 1, email: 'a@bingol.edu.tr', displayName: 'Y', profile: 'VIEWER', pinned: false, permissions: opts.permissions })
        : jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    }
    if (url.includes('/admin/campus/places')) {
      if (method === 'GET') {
        if (opts.hang) return new Promise<Response>(() => undefined);
        if (opts.placesStatus) return jsonResponse(opts.placesStatus, { code: 'SERVER_ERROR', message: 'x' });
        const items = opts.places ?? PLACES;
        return jsonResponse(200, { items, page: 0, totalPages: 1, totalItems: (items as unknown[]).length });
      }
      return jsonResponse(method === 'DELETE' ? 204 : 200, method === 'DELETE' ? undefined : place(9));
    }
    if (url.endsWith('/admin/campus/config')) {
      if (method === 'PUT') return jsonResponse(200, config);
      if (opts.configStatus) return jsonResponse(opts.configStatus, { code: 'SERVER_ERROR', message: 'x' });
      return jsonResponse(200, config);
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  renderWithProviders(
    <AuthProvider>
      <CampusMapPage />
    </AuthProvider>,
    { route: '/admin/campus' },
  );
  return calls;
}

const WRITE = ['campus.read', 'campus.write'];

beforeEach(() => setTokens('a', 'r'));
afterEach(() => {
  vi.unstubAllGlobals();
  clearTokens();
});

describe('Kampüs haritası: göstergeler ve liste', () => {
  it('3 göstergeyi, kategori dağılımını ve yer satırlarını çizer', async () => {
    setup({ permissions: WRITE });
    expect(await screen.findByText('Mühendislik Fakültesi')).toBeInTheDocument();
    const stats = screen.getByRole('group', { name: 'Kampüs haritası özeti' });
    expect(within(stats).getByText('Toplam yer')).toBeInTheDocument();
    expect(within(stats).getByText('2 aktif, 1 pasif')).toBeInTheDocument();
    expect(within(stats).getByText('Kategori dağılımı')).toBeInTheDocument();
    expect(within(stats).getByText('Son güncelleme')).toBeInTheDocument();
    // kategori çubukları: fakülte/kütüphane/yemekhane etiketleri
    expect(within(stats).getByText('Kütüphane')).toBeInTheDocument();
    expect(screen.getByText('Merkez Kütüphane')).toBeInTheDocument();
    expect(screen.getByText('Pasif', { selector: 'span' })).toBeInTheDocument();
    expect(screen.getByText('3 yer listeleniyor')).toBeInTheDocument();
  });

  it('tüm yerleri sayfa sayfa çeker (totalPages > 1)', async () => {
    const calls: string[] = [];
    mockFetch((url) => {
      calls.push(url);
      if (url.endsWith('/admin/rbac/me')) return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
      if (url.includes('/admin/campus/places')) {
        const page = Number(new URL(url, 'http://x').searchParams.get('page'));
        return jsonResponse(200, { items: [place(page + 1)], page, totalPages: 2, totalItems: 2 });
      }
      if (url.endsWith('/admin/campus/config')) return jsonResponse(200, config);
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderWithProviders(
      <AuthProvider>
        <CampusMapPage />
      </AuthProvider>,
      { route: '/admin/campus' },
    );
    expect(await screen.findByText('Yer 2')).toBeInTheDocument();
    expect(screen.getByText('Yer 1')).toBeInTheDocument();
    expect(calls.filter((u) => u.includes('/admin/campus/places')).length).toBe(2);
  });

  it('arama ve kategori süzgeci listeyi daraltır; eşleşme yoksa süzgeç boş durumu çıkar', async () => {
    setup({ permissions: WRITE });
    await screen.findByText('Mühendislik Fakültesi');
    await userEvent.type(screen.getByRole('searchbox', { name: 'Yer ara' }), 'cinar');
    await waitFor(() => expect(screen.queryByText('Merkez Kütüphane')).not.toBeInTheDocument());
    expect(screen.getByText('Çınar Yemekhanesi')).toBeInTheDocument();
    expect(screen.getByText('1 yer listeleniyor')).toBeInTheDocument();
    await userEvent.clear(screen.getByRole('searchbox', { name: 'Yer ara' }));
    await userEvent.type(screen.getByRole('searchbox', { name: 'Yer ara' }), 'yokboyleyer');
    expect(await screen.findByText('Süzgece uyan yer yok')).toBeInTheDocument();
  });

  it('yükleniyor durumunda iskelet gösterir', async () => {
    setup({ permissions: WRITE, hang: true });
    const tile = await screen.findByRole('group', { name: 'Toplam yer' });
    expect(tile).toHaveAttribute('aria-busy', 'true');
  });

  it('boş listede yönlendirici boş durum ve "Yer ekle" çıkar', async () => {
    setup({ permissions: WRITE, places: [] });
    expect(await screen.findByText('Henüz yer eklenmemiş')).toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: 'Yer ekle' }).length).toBeGreaterThanOrEqual(2);
  });

  it('hata durumunda uyarı ve "Tekrar dene" gösterir', async () => {
    setup({ permissions: WRITE, placesStatus: 500 });
    const alerts = await screen.findAllByRole('alert');
    expect(alerts.length).toBeGreaterThan(0);
    expect(screen.getAllByRole('button', { name: 'Tekrar dene' }).length).toBeGreaterThan(0);
  });
});

describe('Kampüs haritası: yetki', () => {
  it('yalnız okuma izniyle yazma düğmeleri GİZLİDİR, "Haritada gör" kalır', async () => {
    setup({ permissions: ['campus.read'] });
    await screen.findByText('Mühendislik Fakültesi');
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Yer ekle' })).not.toBeInTheDocument());
    expect(screen.queryByRole('button', { name: /^Düzenle/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^Sil/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^Pasife al/ })).not.toBeInTheDocument();
    const link = screen.getAllByRole('link', { name: /Haritada gör/ })[0]!;
    expect(link.getAttribute('href')).toMatch(/^https:\/\/www\.openstreetmap\.org\/\?mlat=.*&mlon=/);
    expect(link).toHaveAttribute('rel', expect.stringContaining('noopener'));
  });

  it('yazma izniyle düğmeler görünür', async () => {
    setup({ permissions: WRITE });
    await screen.findByText('Mühendislik Fakültesi');
    expect(await screen.findByRole('button', { name: 'Yer ekle' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^Düzenle.*Mühendislik/ })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^Sil.*Mühendislik/ })).toBeInTheDocument();
  });

  it('okuma izniyle ayarlar salt okunur: alanlar kapalı, kaydet düğmesi yok', async () => {
    setup({ permissions: ['campus.read'] });
    await screen.findByText('Mühendislik Fakültesi');
    await userEvent.click(screen.getByRole('tab', { name: 'Harita ayarları' }));
    expect(await screen.findByText(/yalnızca görüntüleyebilirsiniz/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Ayarları kaydet' })).not.toBeInTheDocument();
    expect(screen.getByLabelText(/^Karo adresi/)).toBeDisabled();
  });
});

describe('Kampüs haritası: yer ekleme', () => {
  async function openForm() {
    const calls = setup({ permissions: WRITE });
    await screen.findByText('Mühendislik Fakültesi');
    await userEvent.click(await screen.findByRole('button', { name: 'Yer ekle' }));
    const dialog = await screen.findByRole('dialog');
    return { calls, dialog };
  }

  it('boş gönderimde alan hatalarını gösterir ve istek atmaz', async () => {
    const { calls, dialog } = await openForm();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    expect(await within(dialog).findAllByText('Bu alan zorunlu.')).not.toHaveLength(0);
    expect(calls.some((c) => c.method === 'POST')).toBe(false);
  });

  it('enlem/boylam aralığı dışındaysa hata verir', async () => {
    const { dialog } = await openForm();
    const lat = within(dialog).getByLabelText(/^Enlem/);
    await userEvent.type(lat, '95');
    await userEvent.tab();
    expect(await within(dialog).findByText('Enlem -90 ile 90 arasında olmalı.')).toBeInTheDocument();
    const lng = within(dialog).getByLabelText(/^Boylam/);
    await userEvent.type(lng, '190');
    await userEvent.tab();
    expect(await within(dialog).findByText('Boylam -180 ile 180 arasında olmalı.')).toBeInTheDocument();
  });

  it('kampüs sınırı dışındaki noktada UYARI çıkar ama kayıt engellenmez', async () => {
    const { calls, dialog } = await openForm();
    await userEvent.type(within(dialog).getByLabelText(/^Yer adı/), 'Uzak Bina');
    await userEvent.selectOptions(within(dialog).getByLabelText(/^Kategori/), 'dormitory');
    await userEvent.type(within(dialog).getByLabelText(/^Enlem/), '39.5');
    await userEvent.type(within(dialog).getByLabelText(/^Boylam/), '40.4981');
    expect(await within(dialog).findByText(/kampüs sınırının dışında görünüyor/)).toBeInTheDocument();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true));
  });

  it('koordinatı yapıştırınca iki alan dolar; "Haritada kontrol et" mlat/mlon bağlantısı verir', async () => {
    const { dialog } = await openForm();
    const paste = within(dialog).getByLabelText('Koordinatı yapıştır');
    paste.focus();
    await userEvent.paste('38.8847, 40.4981');
    expect(within(dialog).getByLabelText(/^Enlem/)).toHaveValue('38.8847');
    expect(within(dialog).getByLabelText(/^Boylam/)).toHaveValue('40.4981');
    const check = within(dialog).getByRole('link', { name: /Haritada kontrol et/ });
    expect(check).toHaveAttribute('href', 'https://www.openstreetmap.org/?mlat=38.8847&mlon=40.4981#map=18/38.8847/40.4981');
    expect(check).toHaveAttribute('target', '_blank');
    expect(screen.getByTestId('campus-preview')).toBeInTheDocument();
  });

  it('bozuk yapıştırmada hata mesajı çıkar', async () => {
    const { dialog } = await openForm();
    const paste = within(dialog).getByLabelText('Koordinatı yapıştır');
    paste.focus();
    await userEvent.paste('merhaba');
    expect(await within(dialog).findByText(/Koordinat çifti okunamadı/)).toBeInTheDocument();
  });

  it('birim etiketi ekler, tekrarı eklemez; geçerli form POST gövdesini doğru üretir', async () => {
    const { calls, dialog } = await openForm();
    await userEvent.type(within(dialog).getByLabelText(/^Yer adı/), '  Spor Salonu ');
    await userEvent.selectOptions(within(dialog).getByLabelText(/^Kategori/), 'sports');
    await userEvent.type(within(dialog).getByLabelText(/^Enlem/), '38,885');
    await userEvent.type(within(dialog).getByLabelText(/^Boylam/), '40.499');
    const units = within(dialog).getByLabelText('Birimler');
    await userEvent.type(units, 'Beden Eğitimi{Enter}');
    await userEvent.type(units, 'beden eğitimi{Enter}');
    expect(within(dialog).getAllByText('Beden Eğitimi')).toHaveLength(1);
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'POST' && c.url.endsWith('/admin/campus/places'))).toBe(true));
    const post = calls.find((c) => c.method === 'POST')!;
    expect(post.body).toEqual({
      name: 'Spor Salonu',
      category: 'sports',
      lat: 38.885,
      lng: 40.499,
      summary: null,
      photoUrl: null,
      units: ['Beden Eğitimi'],
      footprint: null,
      sortKey: 0,
      active: true,
    });
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
  });

  it('bozuk bina izi hata verir (az nokta)', async () => {
    const { dialog } = await openForm();
    await userEvent.type(within(dialog).getByLabelText(/^Bina izi/), '38.88, 40.49{Enter}38.88, 40.50');
    expect(await within(dialog).findByText('Çokgen için en az 3 farklı nokta gerekir.')).toBeInTheDocument();
  });
});

describe('Kampüs haritası: düzenleme, aç-kapat, silme', () => {
  it('pasife al: tüm alanlar korunarak PUT gönderir', async () => {
    const calls = setup({ permissions: WRITE });
    await userEvent.click(await screen.findByRole('button', { name: /^Pasife al.*Mühendislik/ }));
    await waitFor(() => expect(calls.some((c) => c.method === 'PUT' && c.url.endsWith('/places/1'))).toBe(true));
    const put = calls.find((c) => c.method === 'PUT')!;
    expect(put.body).toMatchObject({ name: 'Mühendislik Fakültesi', active: false, units: ['Bilgisayar Mühendisliği'] });
  });

  it('düzenle: form mevcut değerlerle açılır, kaydedince PUT gider', async () => {
    const calls = setup({ permissions: WRITE });
    await userEvent.click(await screen.findByRole('button', { name: /^Düzenle.*Merkez Kütüphane/ }));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByLabelText(/^Yer adı/)).toHaveValue('Merkez Kütüphane');
    await userEvent.clear(within(dialog).getByLabelText(/^Yer adı/));
    await userEvent.type(within(dialog).getByLabelText(/^Yer adı/), 'Kütüphane');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'PUT' && c.url.endsWith('/places/2'))).toBe(true));
    expect(calls.find((c) => c.method === 'PUT')!.body).toMatchObject({ name: 'Kütüphane', active: false });
  });

  it('silme gerekçe ister; gerekçeyle DELETE X-Admin-Reason taşır', async () => {
    const calls = setup({ permissions: WRITE });
    await userEvent.click(await screen.findByRole('button', { name: /^Sil.*Çınar/ }));
    const dialog = await screen.findByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Sil' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByLabelText(/Silme gerekçesi/), 'Yinelenen kayıt');
    expect(confirm).toBeEnabled();
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true));
    const del = calls.find((c) => c.method === 'DELETE')!;
    expect(del.url).toMatch(/\/admin\/campus\/places\/3$/);
    expect(decodeURIComponent(del.reason ?? '')).toBe('Yinelenen kayıt');
  });
});

describe('Kampüs haritası: harita ayarları', () => {
  async function openSettings(permissions = WRITE) {
    const calls = setup({ permissions });
    await screen.findByText('Mühendislik Fakültesi');
    await userEvent.click(screen.getByRole('tab', { name: 'Harita ayarları' }));
    await screen.findByLabelText(/^Karo adresi/);
    return calls;
  }

  it('mevcut ayarları gösterir ve OpenStreetMap uyarısını verir', async () => {
    await openSettings();
    expect(screen.getByLabelText(/^Karo adresi/)).toHaveValue(config.tiles.urlTemplate);
    expect(screen.getByText(/yoğun kullanıma izin vermez/)).toBeInTheDocument();
    expect(screen.getByText('Herkese açık OpenStreetMap sunucusu')).toBeInTheDocument();
    expect(screen.getByLabelText(/^İlk yakınlaştırma/)).toHaveValue('16');
    expect(screen.getByRole('button', { name: 'Ayarları kaydet' })).toBeDisabled(); // değişiklik yok
  });

  it('geçersiz karo adresi hata verir ve kaydı kapatır', async () => {
    await openSettings();
    const url = screen.getByLabelText(/^Karo adresi/);
    await userEvent.clear(url);
    await userEvent.type(url, 'http://tile.example.com/{{z}/{{x}/{{y}.png');
    expect(await screen.findByText('Adres https:// ile başlamalı.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Ayarları kaydet' })).toBeDisabled();
    await userEvent.clear(url);
    await userEvent.type(url, 'https://tile.example.com/z/x/y.png');
    expect(await screen.findByText(/yer tutucularının üçünü de içermeli/)).toBeInTheDocument();
  });

  it('yakınlaştırma sırası bozuksa hata verir', async () => {
    await openSettings();
    const max = screen.getByLabelText(/^En çok yakınlaştırma/);
    await userEvent.clear(max);
    await userEvent.type(max, '10');
    expect(await screen.findByText('En çok yakınlaştırma, en azdan küçük olamaz.')).toBeInTheDocument();
  });

  it('kampüs sınırı bozuksa hata verir', async () => {
    await openSettings();
    const b = screen.getByLabelText(/^Köşe noktaları/);
    await userEvent.clear(b);
    await userEvent.type(b, '38.87, 40.48{Enter}38.87, 40.52');
    expect(await screen.findByText('Çokgen için en az 3 farklı nokta gerekir.')).toBeInTheDocument();
  });

  it('değişiklik gerekçeyle kaydedilir: PUT gövdesi ve X-Admin-Reason', async () => {
    const calls = await openSettings();
    const attribution = screen.getByLabelText(/^Atıf metni/);
    await userEvent.clear(attribution);
    await userEvent.type(attribution, '© Harita katkıcıları');
    const save = screen.getByRole('button', { name: 'Ayarları kaydet' });
    await waitFor(() => expect(save).toBeEnabled());
    await userEvent.click(save);
    const dialog = await screen.findByRole('dialog');
    const confirm = within(dialog).getByRole('button', { name: 'Ayarları kaydet' });
    expect(confirm).toBeDisabled(); // gerekçe şart
    await userEvent.type(within(dialog).getByLabelText(/Değişiklik gerekçesi/), 'Atıf metni güncellendi');
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'PUT' && c.url.endsWith('/admin/campus/config'))).toBe(true));
    const put = calls.find((c) => c.method === 'PUT' && c.url.endsWith('/admin/campus/config'))!;
    expect(put.body).toMatchObject({
      center: { lat: 38.8847, lng: 40.4981 },
      zoom: { initial: 16, min: 14, max: 19 },
      tiles: { attribution: '© Harita katkıcıları', maxNativeZoom: 19 },
    });
    expect((put.body as { boundary: unknown[] }).boundary).toHaveLength(4);
    expect(decodeURIComponent(put.reason ?? '')).toBe('Atıf metni güncellendi');
  });

  it('ayar sorgusu hata verirse hata durumu çıkar', async () => {
    setup({ permissions: WRITE, configStatus: 500 });
    await screen.findByText('Mühendislik Fakültesi');
    await userEvent.click(screen.getByRole('tab', { name: 'Harita ayarları' }));
    expect(await screen.findByRole('alert')).toBeInTheDocument();
  });
});
