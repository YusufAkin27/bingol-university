import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { AppRoutes } from '../../routes';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';

afterEach(() => vi.unstubAllGlobals());

function open(lang: 'tr' | 'en' = 'tr') {
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>,
    { route: '/admin/login', lang },
  );
}

async function fill(user: ReturnType<typeof userEvent.setup>, email: string, password: string) {
  if (email) await user.type(screen.getByLabelText(/E-posta/), email);
  if (password) await user.type(screen.getByLabelText(/Şifre/, { selector: 'input' }), password);
  await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
}

describe('yönetici girişi', () => {
  it('site dili İngilizce olsa da Türkçedir ve dil seçici içermez', async () => {
    mockFetch(() => jsonResponse(404));
    open('en');
    expect(await screen.findByRole('heading', { level: 1, name: 'Yönetim paneli girişi' })).toBeInTheDocument();
    expect(screen.queryByRole('combobox')).toBeNull();
    expect(screen.getByRole('link', { name: 'Ana siteye dön' })).toBeInTheDocument();
  });

  it('tarayıcı parola yöneticisi için autocomplete ve göster/gizle düğmesi vardır', async () => {
    const user = userEvent.setup();
    mockFetch(() => jsonResponse(404));
    open();
    const email = await screen.findByLabelText(/E-posta/);
    const pw = screen.getByLabelText(/Şifre/, { selector: 'input' });
    expect(email).toHaveAttribute('autocomplete', 'username');
    expect(pw).toHaveAttribute('autocomplete', 'current-password');
    expect(pw).toHaveAttribute('type', 'password');
    await user.click(screen.getByRole('button', { name: 'Şifreyi göster' }));
    expect(pw).toHaveAttribute('type', 'text');
    await user.click(screen.getByRole('button', { name: 'Şifreyi gizle' }));
    expect(pw).toHaveAttribute('type', 'password');
  });

  it('@ içermeyen e-posta istek atmadan doğrulanır', async () => {
    const user = userEvent.setup();
    const f = mockFetch(() => jsonResponse(404));
    open();
    await screen.findByLabelText(/E-posta/);
    await fill(user, 'yonetici', 'sifre1234');
    expect(screen.getByText('Geçerli bir e-posta adresi girin.')).toBeInTheDocument();
    expect(f.mock.calls.some(([u]) => String(u).endsWith('/auth/login'))).toBe(false);
  });

  it('401 hatalı bilgi, 429 hız sınırı için ayrı Türkçe mesaj verir', async () => {
    const user = userEvent.setup();
    let status = 401;
    mockFetch((url) =>
      url.endsWith('/auth/login')
        ? jsonResponse(status, { code: status === 429 ? 'RATE_LIMITED' : 'INVALID_CREDENTIALS', message: 'x' })
        : jsonResponse(404),
    );
    open();
    await screen.findByLabelText(/E-posta/);
    await fill(user, 'x@bingol.edu.tr', 'yanlis');
    expect(await screen.findByText('E-posta veya şifre hatalı.')).toBeInTheDocument();

    status = 429;
    await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
    expect(await screen.findByText(/Çok fazla giriş denemesi/)).toBeInTheDocument();
  });

  it('sunucuya ulaşılamazsa ağ hatası mesajı gösterir', async () => {
    const user = userEvent.setup();
    mockFetch((url) => {
      if (url.endsWith('/auth/login')) throw new TypeError('Failed to fetch');
      return jsonResponse(404);
    });
    open();
    await screen.findByLabelText(/E-posta/);
    await fill(user, 'x@bingol.edu.tr', 'sifre1234');
    expect(await screen.findByText('Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.')).toBeInTheDocument();
  });
});
