import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { AuthProvider } from '../../auth/AuthProvider';
import { AppRoutes } from '../../routes';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';

const GROUPS = [
  { category: 'Hesap', items: [{ id: 1, question: 'Şifremi unuttum, ne yapmalıyım?', answer: 'Sıfırlama isteyin.' }] },
  { category: 'Bildirimler', items: [{ id: 3, question: 'Bildirimleri nasıl kapatırım?', answer: 'Ayarlardan.' }] },
];

const INFO = {
  appName: 'BÜ Kampüs',
  website: null,
  contactEmail: null,
  supportEmail: null,
  phone: null,
  address: null,
  social: { instagram: null, twitter: null, youtube: null },
  banner: null,
  maintenance: { enabled: false, message: null },
  languages: ['tr', 'en', 'ar'],
};
const api = (url: string) => (url.includes('/faq') ? jsonResponse(200, GROUPS) : jsonResponse(200, INFO));

function renderAt(route: string) {
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>,
    { route, lang: 'tr' },
  );
}

describe('yardım merkezi + SSS (RD06)', () => {
  it('yardım aramasi sorguyu SSS sayfasina tasir ve liste suzulur', async () => {
    mockFetch(api);
    renderAt('/help');
    const user = userEvent.setup();
    await user.type(await screen.findByRole('searchbox', { name: 'Yardım merkezinde ara' }), 'bildirim{Enter}');
    await screen.findByRole('heading', { level: 1, name: 'Sık sorulan sorular' });
    expect(await screen.findByRole('searchbox', { name: 'Sorularda ara' })).toHaveValue('bildirim');
    expect(screen.getByRole('button', { name: /Bildirimleri nasıl/ })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Şifremi unuttum/ })).toBeNull();
  });

  it('kategori çipleri listeyi kategoriye göre süzer', async () => {
    mockFetch(api);
    renderAt('/faq');
    const user = userEvent.setup();
    const chip = await screen.findByRole('button', { name: 'Bildirimler' });
    expect(chip).toHaveAttribute('aria-pressed', 'false');
    await user.click(chip);
    expect(chip).toHaveAttribute('aria-pressed', 'true');
    expect(screen.queryByRole('button', { name: /Şifremi unuttum/ })).toBeNull();
    await user.click(screen.getByRole('button', { name: 'Tümü' }));
    expect(screen.getByRole('button', { name: /Şifremi unuttum/ })).toBeInTheDocument();
  });
});
