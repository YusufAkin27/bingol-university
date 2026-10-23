import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import CampaignComposePage from './CampaignComposePage';
import { DRAFT_KEY, clearDraft } from './campaigns/lib';

afterEach(() => {
  cleanup(); // ayrılırken yazılan taslak da silinsin (storage.ts bellek yedeği testler arası sızmasın)
  clearDraft();
  vi.unstubAllGlobals();
});

function setup(count: number | ((body: { type: string }) => number) = 1240) {
  const calls: { url: string; init: RequestInit }[] = [];
  mockFetch((url, init) => {
    calls.push({ url, init });
    if (url.includes('/admin/push/audience-count')) {
      const body = JSON.parse(String(init.body)) as { type: string };
      return jsonResponse(200, { count: typeof count === 'function' ? count(body) : count });
    }
    if (url.includes('/departments')) return jsonResponse(200, ['Bilgisayar Mühendisliği', 'Hukuk']);
    if (url.includes('/admin/push/campaigns')) return jsonResponse(202, { id: 1 });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  const utils = renderWithProviders(<CampaignComposePage />, { route: '/admin/campaigns/new' });
  return { calls, ...utils };
}

describe('kampanya oluşturucu', () => {
  it('seçilen kitleye göre anlık kitle büyüklüğünü gösterir', async () => {
    setup(1240);
    const counter = screen.getByTestId('audience-count');
    await waitFor(() => expect(counter).toHaveTextContent('1.240'));
    expect(counter).toHaveTextContent('kişiye gidecek');
  });

  it('kitle 0 ise gönder düğmesi engellenir ve uyarı gösterilir', async () => {
    setup(0);
    await waitFor(() => expect(screen.getByTestId('audience-count')).toHaveTextContent('Bu kitlede alıcı yok'));
    expect(screen.getByTestId('send-button')).toBeDisabled();
  });

  it('SYSTEM türü seçilince kırmızı uyarı gösterir', async () => {
    setup();
    const user = userEvent.setup();
    expect(screen.queryByText('Kullanıcı tercihlerini yok sayar')).not.toBeInTheDocument();
    await user.click(screen.getByRole('radio', { name: /Sistem/ }));
    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('Kullanıcı tercihlerini yok sayar');
    expect(alert).toHaveTextContent('Yalnızca önemli duyurular için');
  });

  it('başlık ve metin karakter sayaçları ile sınır aşımı uyarısı', async () => {
    setup();
    const user = userEvent.setup();
    await user.type(screen.getByLabelText('Başlık'), 'Merhaba');
    expect(screen.getByText('7 / 100')).toBeInTheDocument();
    expect(screen.getByText('0 / 300')).toBeInTheDocument();
    await user.click(screen.getByLabelText('Metin', { exact: true }));
    await user.paste('a'.repeat(301));
    expect(screen.getByText('301 / 300')).toBeInTheDocument();
    expect(screen.getAllByText('Karakter sınırı aşıldı.').length).toBeGreaterThan(0);
  });

  it('boş bırakılan dilde Türkçe gideceğini söyler ve önizleme Türkçeye düşer', async () => {
    setup();
    const user = userEvent.setup();
    await user.type(screen.getByLabelText('Başlık'), 'Duyuru');
    await user.type(screen.getByLabelText('Metin', { exact: true }), 'Metin');
    await user.click(screen.getByRole('tab', { name: /English/ }));
    expect(screen.getByText(/boş bırakılırsa bu dili kullanan kişilere Türkçe metin gider/)).toBeInTheDocument();
    expect(screen.getByTestId('phone-notification')).toHaveTextContent('Duyuru');
    expect(screen.getByTestId('phone-notification')).toHaveAttribute('lang', 'tr');
  });

  it('Arapça önizleme sağdan sola yönlendirilir', async () => {
    setup();
    const user = userEvent.setup();
    await user.click(screen.getByRole('tab', { name: /العربية/ }));
    await user.type(screen.getByLabelText('Başlık'), 'عنوان');
    await user.type(screen.getByLabelText('Metin', { exact: true }), 'نص');
    const n = screen.getByTestId('phone-notification');
    expect(n).toHaveAttribute('dir', 'rtl');
    expect(n).toHaveAttribute('lang', 'ar');
    expect(n).toHaveTextContent('عنوان');
  });

  it('URL hedefi https:// olmayınca hata verir', async () => {
    setup();
    const user = userEvent.setup();
    await user.selectOptions(screen.getByLabelText('Açılacak yer'), 'URL');
    await user.type(screen.getByLabelText(/Bağlantı \(https/), 'http://zararli.example');
    expect(await screen.findByText('Bağlantı https:// ile başlamalıdır.')).toBeInTheDocument();
  });

  it('gönderme: özet penceresi ve ALL için ek onay kutusu', async () => {
    const { calls } = setup(1240);
    const user = userEvent.setup();
    await user.click(screen.getByRole('radio', { name: /Tüm kullanıcılar/ }));
    await waitFor(() => expect(screen.getByTestId('audience-count')).toHaveTextContent('1.240'));
    await user.type(screen.getByLabelText('Başlık'), 'Duyuru');
    await user.type(screen.getByLabelText('Metin', { exact: true }), 'Metin');
    await user.click(screen.getByTestId('send-button'));
    const dialog = await screen.findByRole('dialog');
    expect(dialog).toHaveTextContent('1.240 kişiye şu içerikle gönderilecek');
    expect(dialog).toHaveTextContent('Bu işlem geri alınamaz');
    const confirm = within(dialog).getByTestId('confirm-send');
    expect(confirm).toBeDisabled();
    await user.click(within(dialog).getByLabelText(/Tüm kullanıcılara/));
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() =>
      expect(calls.some((c) => c.url.endsWith('/admin/push/campaigns') && c.init.method === 'POST')).toBe(true),
    );
    const post = calls.find((c) => c.url.endsWith('/admin/push/campaigns'));
    expect(JSON.parse(String(post?.init.body))).toMatchObject({
      type: 'ANNOUNCEMENT',
      audience: { type: 'ALL' },
      tr: { title: 'Duyuru', body: 'Metin' },
    });
  });

  it('taslak yazdıkça tarayıcı deposuna kaydedilir', async () => {
    setup();
    const user = userEvent.setup();
    await user.type(screen.getByLabelText('Başlık'), 'Taslak başlık');
    await waitFor(() => expect(window.localStorage.getItem(DRAFT_KEY)).toContain('Taslak başlık'), { timeout: 2000 });
  });

  it('kayıtlı taslak açılışta geri yüklenir', async () => {
    window.localStorage.setItem(
      DRAFT_KEY,
      JSON.stringify({
        audienceType: 'ADMINS',
        contents: { tr: { title: 'Eski başlık', body: 'Eski metin' }, en: { title: '', body: '' }, ar: { title: '', body: '' } },
        notifType: 'NEWS',
      }),
    );
    setup();
    expect(screen.getByLabelText('Başlık')).toHaveValue('Eski başlık');
    expect(screen.getByRole('radio', { name: /Yöneticiler/ })).toBeChecked();
    expect(screen.getByText(/Önceki taslağınız geri yüklendi/)).toBeInTheDocument();
  });
});
