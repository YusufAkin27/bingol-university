import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import SettingsPage from './SettingsPage';

afterEach(() => vi.unstubAllGlobals());

const SERVER = {
  app_name: 'Bingöl Üniversitesi',
  website: 'https://www.bingol.edu.tr',
  banner_text_tr: '',
  banner_text_en: '',
  banner_text_ar: '',
  banner_url: '',
  maintenance_mode: 'false',
  maintenance_message_tr: 'Bakımda',
  maintenance_message_en: 'Maintenance',
  maintenance_message_ar: 'صيانة',
  faculties: 'Mühendislik Fakültesi;Fen Fakültesi',
  min_version_android: '1.0.0',
  latest_version_android: '1.0.0',
  store_url_android: '',
  min_version_ios: '1.0.0',
  latest_version_ios: '1.0.0',
  store_url_ios: '',
};

function setup() {
  const puts: { key: string; value: string }[] = [];
  const reasons: (string | undefined)[] = [];
  mockFetch((url, init) => {
    if (url.endsWith('/admin/settings') && (init.method ?? 'GET') === 'GET') return jsonResponse(200, SERVER);
    const m = /\/admin\/settings\/([^/?]+)$/.exec(url);
    if (m && init.method === 'PUT') {
      puts.push({ key: decodeURIComponent(m[1]), value: (JSON.parse(String(init.body)) as { value: string }).value });
      const r = (init.headers as Record<string, string>)['X-Admin-Reason'];
      reasons.push(r === undefined ? undefined : decodeURIComponent(r));
      return jsonResponse(204);
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  renderWithProviders(<SettingsPage />, { route: '/admin/settings' });
  return { puts, reasons };
}

describe('ayarlar sayfası', () => {
  it('alan değişince vurgulanır, “Kaydedilmemiş” gösterir ve tek alan kaydedilir', async () => {
    const { puts } = setup();
    const user = userEvent.setup();
    const field = await screen.findByLabelText('Uygulama adı');
    const row = field.closest('[data-key]') as HTMLElement;
    expect(row).not.toHaveAttribute('data-dirty');
    expect(within(row).getByRole('button', { name: 'Kaydet' })).toBeDisabled();
    await user.clear(field);
    await user.type(field, 'Yeni ad');
    expect(row).toHaveAttribute('data-dirty', 'true');
    expect(within(row).getByText('Kaydedilmemiş')).toBeInTheDocument();
    await user.click(within(row).getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(puts).toEqual([{ key: 'app_name', value: 'Yeni ad' }]));
  });

  it('bağlantı https:// değilse kaydetmeyi engeller', async () => {
    setup();
    const user = userEvent.setup();
    const field = await screen.findByLabelText('Web sitesi');
    await user.clear(field);
    await user.type(field, 'http://x.example');
    expect(await screen.findByText('Bağlantı https:// ile başlamalıdır.')).toBeInTheDocument();
    expect(screen.getByTestId('save-website')).toBeDisabled();
  });

  it('mağaza sekmesi sürüm doğrulamasını gösterir', async () => {
    setup();
    const user = userEvent.setup();
    await user.click(await screen.findByRole('tab', { name: /Mağaza ve sürümler/ }));
    const min = screen.getAllByLabelText('En düşük sürüm (zorunlu)')[0];
    await user.clear(min);
    await user.type(min, '1.x');
    expect(await screen.findByText(/Sürüm sayılardan ve noktalardan/)).toBeInTheDocument();
    expect(screen.getByTestId('save-min_version_android')).toBeDisabled();
  });

  it('fakülte çip düzenleyici: ekle, sırala, sil ve `;` ile kaydet', async () => {
    const { puts } = setup();
    const user = userEvent.setup();
    await user.click(await screen.findByRole('tab', { name: /Fakülteler/ }));
    const list = screen.getByRole('list', { name: 'Fakülteler' });
    expect(within(list).getAllByRole('listitem')).toHaveLength(2);
    const add = screen.getByLabelText('Fakülte ekle');
    await user.type(add, 'Hukuk Fakültesi{Enter}');
    expect(within(list).getAllByRole('listitem')).toHaveLength(3);
    // yinelenen ad eklenmez
    await user.type(add, 'Fen Fakültesi{Enter}');
    expect(within(list).getAllByRole('listitem')).toHaveLength(3);
    await user.click(screen.getByRole('button', { name: 'Hukuk Fakültesi yukarı taşı' }));
    await user.click(screen.getByRole('button', { name: 'Mühendislik Fakültesi sil' }));
    expect(screen.getByText('Kaydedilmemiş')).toBeInTheDocument();
    await user.click(screen.getByTestId('save-faculties'));
    await waitFor(() => expect(puts).toEqual([{ key: 'faculties', value: 'Hukuk Fakültesi;Fen Fakültesi' }]));
  });

  it('fakülte: yapıştırılan `;` listesi çiplere bölünür', async () => {
    const { puts } = setup();
    const user = userEvent.setup();
    await user.click(await screen.findByRole('tab', { name: /Fakülteler/ }));
    await user.click(screen.getByLabelText('Fakülte ekle'));
    await user.paste('Edebiyat;Hukuk;;Tıp');
    await user.click(screen.getByTestId('save-faculties'));
    await waitFor(() =>
      expect(puts[0]).toEqual({ key: 'faculties', value: 'Mühendislik Fakültesi;Fen Fakültesi;Edebiyat;Hukuk;Tıp' }),
    );
  });

  it('bakım modunu açmak onay ister; vazgeçince kaydedilmez', async () => {
    const { puts } = setup();
    const user = userEvent.setup();
    await user.click(await screen.findByRole('tab', { name: /^Bakım modu/ }));
    await user.click(screen.getByRole('switch'));
    await user.click(screen.getByTestId('save-maintenance_mode'));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('tüm kullanıcılar bakım mesajını görür');
    await user.click(within(dialog).getByRole('button', { name: 'Vazgeç' }));
    expect(puts).toHaveLength(0);
  });

  it('bakım modu: BAKIM yazılmadan onay kapalı; yazınca kaydedilir', async () => {
    const { puts, reasons } = setup();
    const user = userEvent.setup();
    await user.click(await screen.findByRole('tab', { name: /^Bakım modu/ }));
    await user.click(screen.getByRole('switch'));
    await user.click(screen.getByTestId('save-maintenance_mode'));
    const dialog = await screen.findByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Bakım modunu aç' });
    expect(confirm).toBeDisabled();
    const [reasonBox, box] = within(dialog).getAllByRole('textbox');
    await user.type(reasonBox, 'Veritabanı geçişi');
    expect(confirm).toBeDisabled(); // BAKIM henüz yazılmadı
    await user.type(box, 'bak');
    expect(confirm).toBeDisabled();
    await user.type(box, 'ım'); // "bakım" (küçük harf de kabul)
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(puts).toEqual([{ key: 'maintenance_mode', value: 'true' }]));
    expect(reasons).toEqual(['Veritabanı geçişi']);
  });

  it('kritik anahtar (mağaza sürümü): eski → yeni fark önizlemesi gösterir, onaysız kaydetmez', async () => {
    const { puts, reasons } = setup();
    const user = userEvent.setup();
    await user.click(await screen.findByRole('tab', { name: /Mağaza ve sürümler/ }));
    const min = screen.getAllByLabelText('En düşük sürüm (zorunlu)')[0];
    await user.clear(min);
    await user.type(min, '1.4.0');
    await user.click(screen.getByTestId('save-min_version_android'));
    const dialog = await screen.findByRole('alertdialog');
    expect(puts).toHaveLength(0);
    expect(within(dialog).getByTestId('diff-old')).toHaveTextContent('1.0.0');
    expect(within(dialog).getByTestId('diff-new')).toHaveTextContent('1.4.0');
    expect(dialog).toHaveTextContent('güncellenene kadar kullanılamaz');
    const confirm = within(dialog).getByRole('button', { name: 'Değişikliği kaydet' });
    expect(confirm).toBeDisabled(); // sebep yok
    await user.type(within(dialog).getByRole('textbox'), 'abc');
    expect(confirm).toBeDisabled(); // sebep çok kısa
    await user.type(within(dialog).getByRole('textbox'), 'de');
    await user.click(confirm);
    await waitFor(() => expect(puts).toEqual([{ key: 'min_version_android', value: '1.4.0' }]));
    expect(reasons).toEqual(['abcde']);
  });

  it('kritik anahtar: önizlemede vazgeçilirse kaydedilmez; boş eski değer "(boş)" gösterilir', async () => {
    const { puts } = setup();
    const user = userEvent.setup();
    await user.click(await screen.findByRole('tab', { name: /Mağaza ve sürümler/ }));
    const url = screen.getAllByLabelText('Mağaza bağlantısı')[0];
    await user.type(url, 'https://play.google.com/x');
    await user.click(screen.getByTestId('save-store_url_android'));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByTestId('diff-old')).toHaveTextContent('(boş)');
    await user.click(within(dialog).getByRole('button', { name: 'Vazgeç' }));
    expect(puts).toHaveLength(0);
  });

  it('kritik olmayan anahtar (uygulama adı) onaysız doğrudan kaydedilir', async () => {
    const { puts } = setup();
    const user = userEvent.setup();
    const field = await screen.findByLabelText('Uygulama adı');
    await user.clear(field);
    await user.type(field, 'X');
    await user.click(within(field.closest('[data-key]') as HTMLElement).getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(puts).toHaveLength(1));
    expect(screen.queryByRole('alertdialog')).toBeNull();
  });

  it('kaydet sürerken ikinci tıklama/Enter yeni istek göndermez (tek PUT)', async () => {
    let puts = 0;
    let release: (r: Response) => void = () => undefined;
    mockFetch((url, init) => {
      if (url.endsWith('/admin/settings') && (init.method ?? 'GET') === 'GET') return jsonResponse(200, SERVER);
      if (init.method === 'PUT') {
        puts++;
        return new Promise<Response>((res) => (release = res)) as unknown as Response;
      }
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderWithProviders(<SettingsPage />, { route: '/admin/settings' });
    const user = userEvent.setup();
    const field = await screen.findByLabelText('Uygulama adı');
    await user.clear(field);
    await user.type(field, 'Y');
    const save = within(field.closest('[data-key]') as HTMLElement).getByRole('button', { name: 'Kaydet' });
    await user.click(save);
    await user.click(save);
    await user.click(save);
    expect(puts).toBe(1);
    release(new Response(null, { status: 204 }));
    await waitFor(() => expect(screen.queryByText('Kaydedilmemiş')).toBeNull());
    expect(puts).toBe(1);
  });

  it('kaydedilmemiş değişiklik varken bağlantıya tıklamak uyarı diyaloğu açar', async () => {
    setup();
    const user = userEvent.setup();
    const field = await screen.findByLabelText('Uygulama adı');
    await user.type(field, 'Z');
    const a = document.createElement('a');
    a.href = '/baska';
    a.textContent = 'git';
    document.body.append(a);
    await user.click(a);
    expect(await screen.findByRole('alertdialog')).toHaveTextContent('Kaydedilmemiş değişiklikler var');
    a.remove();
  });

  it('banner önizlemesi seçili dili gösterir; boşsa Türkçeye düşer', async () => {
    setup();
    const user = userEvent.setup();
    await user.click(await screen.findByRole('tab', { name: /Duyuru bandı/ }));
    await user.type(screen.getByLabelText('Bant metni (Türkçe)'), 'Kayıtlar uzatıldı');
    expect(screen.getByTestId('banner-preview')).toHaveTextContent('Kayıtlar uzatıldı');
    await user.click(screen.getByRole('button', { name: 'AR' }));
    const prev = screen.getByTestId('banner-preview');
    expect(prev).toHaveTextContent('Kayıtlar uzatıldı');
    expect(prev).toHaveAttribute('lang', 'tr');
    await user.type(screen.getByLabelText('Bant metni (العربية)'), 'تم التمديد');
    expect(screen.getByTestId('banner-preview')).toHaveAttribute('dir', 'rtl');
  });
});
