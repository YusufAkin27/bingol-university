import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { clearTokens } from '../../auth/tokens';
import { I18nProvider } from '../../i18n/I18nProvider';
import { ThemeProvider } from '../../lib/theme';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import AdminRegisterPage from './AdminRegisterPage';
import LoginPage from './LoginPage';

const tokens = { accessToken: 'a1', refreshToken: 'r1', expiresInSeconds: 900, tokenType: 'Bearer' };
const adminMe = { id: 1, email: 'ysufakin23@gmail.com', displayName: 'Yönetici', role: 'ADMIN' };
const userMe = { ...adminMe, role: 'USER' };

function App({ route = '/admin/register' }: { route?: string }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return (
    <QueryClientProvider client={qc}>
      <I18nProvider>
        <ThemeProvider>
          <MemoryRouter initialEntries={[route]}>
            <AuthProvider>
              <Routes>
                <Route path="/admin/login" element={<LoginPage />} />
                <Route path="/admin/register" element={<AdminRegisterPage />} />
                <Route path="/admin" element={<p>panel acildi</p>} />
              </Routes>
            </AuthProvider>
          </MemoryRouter>
        </ThemeProvider>
      </I18nProvider>
    </QueryClientProvider>
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
  clearTokens();
});

async function fillForm(user: ReturnType<typeof userEvent.setup>, email: string, accept = true) {
  await user.type(await screen.findByLabelText(/Ad soyad/), 'Yusuf Yönetici');
  await user.type(screen.getByLabelText(/E-posta/), email);
  await user.type(screen.getByLabelText(/Şifre/, { selector: 'input' }), 'Sifre1234');
  if (accept) await user.click(screen.getByRole('checkbox'));
  await user.click(screen.getByRole('button', { name: 'Kayıt ol ve kod gönder' }));
}

describe('yönetici hesabı kaydı', () => {
  it('gmail gibi okul dışı adres istemcide ENGELLENMEZ: istek sunucuya gider, kod adımına geçilir', async () => {
    const user = userEvent.setup();
    const f = mockFetch((url) => (url.endsWith('/auth/register') ? jsonResponse(202, { message: 'ok' }) : jsonResponse(404)));
    render(<App />);
    await fillForm(user, 'ysufakin23@gmail.com');

    expect(await screen.findByRole('heading', { name: 'E-postanızı doğrulayın' })).toBeInTheDocument();
    const call = f.mock.calls.find(([u]) => String(u).endsWith('/auth/register'))!;
    expect(JSON.parse(String(call[1]?.body))).toMatchObject({
      email: 'ysufakin23@gmail.com',
      acceptTerms: true,
      displayName: 'Yusuf Yönetici',
      language: 'tr',
    });
  });

  it('sunucu alan adını reddederse sunucu mesajı gösterilir, form korunur', async () => {
    const user = userEvent.setup();
    mockFetch((url) =>
      url.endsWith('/auth/register')
        ? jsonResponse(400, { code: 'EMAIL_DOMAIN_NOT_ALLOWED', message: 'Yalnızca bingol.edu.tr uzantılı e-posta ile kayıt olunabilir.' })
        : jsonResponse(404),
    );
    render(<App />);
    await fillForm(user, 'baska@gmail.com');

    expect(await screen.findByText(/Yalnızca bingol\.edu\.tr/)).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'E-postanızı doğrulayın' })).toBeNull();
  });

  it('kabul işaretlenmeden ya da kısa şifreyle istek atılmaz', async () => {
    const user = userEvent.setup();
    const f = mockFetch(() => jsonResponse(404));
    render(<App />);
    await fillForm(user, 'x@gmail.com', false);

    expect(await screen.findByText('Devam etmek için kabul etmelisiniz.')).toBeInTheDocument();
    expect(f.mock.calls.some(([u]) => String(u).endsWith('/auth/register'))).toBe(false);
  });

  it('kod doğrulanınca parola kanıtıyla verify-email, sonra giriş yapılır ve panele geçilir', async () => {
    const user = userEvent.setup();
    const f = mockFetch((url) => {
      if (url.endsWith('/auth/register')) return jsonResponse(202, { message: 'ok' });
      if (url.endsWith('/auth/verify-email') || url.endsWith('/auth/login')) return jsonResponse(200, tokens);
      if (url.endsWith('/admin/me')) return jsonResponse(200, adminMe);
      return jsonResponse(404);
    });
    render(<App />);
    await fillForm(user, 'ysufakin23@gmail.com');
    await user.type(await screen.findByLabelText(/Doğrulama kodu/), '482915');
    await user.click(screen.getByRole('button', { name: 'Doğrula ve giriş yap' }));

    expect(await screen.findByText('panel acildi')).toBeInTheDocument();
    const verify = f.mock.calls.find(([u]) => String(u).endsWith('/auth/verify-email'))!;
    expect(JSON.parse(String(verify[1]?.body))).toMatchObject({
      email: 'ysufakin23@gmail.com',
      code: '482915',
      password: 'Sifre1234',
      client: 'web',
    });
  });

  it('yönetici olmayan hesap doğrulansa da panele alınmaz ("yetkiniz yok")', async () => {
    const user = userEvent.setup();
    mockFetch((url) => {
      if (url.endsWith('/auth/register')) return jsonResponse(202, { message: 'ok' });
      if (url.endsWith('/auth/verify-email') || url.endsWith('/auth/login')) return jsonResponse(200, tokens);
      if (url.endsWith('/admin/me')) return jsonResponse(200, userMe);
      return jsonResponse(404);
    });
    render(<App />);
    await fillForm(user, 'ogrenci@bingol.edu.tr');
    await user.type(await screen.findByLabelText(/Doğrulama kodu/), '111222');
    await user.click(screen.getByRole('button', { name: 'Doğrula ve giriş yap' }));

    expect(await screen.findByRole('heading', { name: 'Bu alana erişim yetkiniz yok' })).toBeInTheDocument();
    expect(screen.queryByText('panel acildi')).toBeNull();
  });

  it('giriş sayfasından kayıt sayfasına bağlantı vardır', async () => {
    mockFetch(() => jsonResponse(404));
    render(<App route="/admin/login" />);
    const link = await screen.findByRole('link', { name: /Yönetici hesabı oluşturun/ });
    expect(link).toHaveAttribute('href', '/admin/register');
  });
});
