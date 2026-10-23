import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { I18nProvider } from '../i18n/I18nProvider';
import { ThemeProvider } from '../lib/theme';
import LoginPage from '../pages/admin/LoginPage';
import { jsonResponse, mockFetch } from '../test/fetchMock';
import { AuthProvider } from './AuthProvider';
import { RequireAdmin } from './RequireAdmin';
import { getAccessToken, getRefreshToken, setTokens } from './tokens';

const tokens = { accessToken: 'a1', refreshToken: 'r1', expiresInSeconds: 900, tokenType: 'Bearer' };
const adminMe = { id: 1, email: 'admin@bingol.edu.tr', displayName: 'Yönetici', role: 'ADMIN' };

function App({ route }: { route: string }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return (
    <QueryClientProvider client={qc}>
      <I18nProvider>
        <ThemeProvider>
          <MemoryRouter initialEntries={[route]}>
            <AuthProvider>
              <Routes>
                <Route path="/admin/login" element={<LoginPage />} />
                <Route
                  path="/admin"
                  element={
                    <RequireAdmin>
                      <p>gizli panel</p>
                    </RequireAdmin>
                  }
                />
              </Routes>
            </AuthProvider>
          </MemoryRouter>
        </ThemeProvider>
      </I18nProvider>
    </QueryClientProvider>
  );
}

afterEach(() => vi.unstubAllGlobals());

describe('RequireAdmin', () => {
  it('oturum yoksa giriş sayfasına yönlendirir', async () => {
    mockFetch(() => jsonResponse(500));
    render(<App route="/admin" />);
    expect(await screen.findByRole('heading', { name: 'Yönetim paneli girişi' })).toBeInTheDocument();
    expect(screen.queryByText('gizli panel')).toBeNull();
  });

  it('geçerli ADMIN oturumunda içeriği gösterir', async () => {
    setTokens('a1', 'r1');
    const f = mockFetch((url) =>
      url.endsWith('/admin/me') ? jsonResponse(200, adminMe) : jsonResponse(404),
    );
    render(<App route="/admin" />);
    expect(await screen.findByText('gizli panel')).toBeInTheDocument();
    expect(f).toHaveBeenCalledTimes(1);
  });

  it('ADMIN olmayan kullanıcıya "yetkiniz yok" ekranı gösterir (403)', async () => {
    setTokens('a1', 'r1');
    mockFetch(() => jsonResponse(403, { code: 'FORBIDDEN', message: 'x' }));
    render(<App route="/admin" />);
    expect(await screen.findByText('Bu alana erişim yetkiniz yok')).toBeInTheDocument();
    expect(screen.queryByText('gizli panel')).toBeNull();
  });

  it('rolü ADMIN dönmeyen yanıtı da reddeder', async () => {
    setTokens('a1', 'r1');
    mockFetch(() => jsonResponse(200, { ...adminMe, role: 'USER' }));
    render(<App route="/admin" />);
    expect(await screen.findByRole('alert')).toHaveTextContent('Bu alana erişim yetkiniz yok');
  });

  it("süresi dolmuş ve yenilenemeyen oturumda girişe düşer, token'lar silinir", async () => {
    setTokens('old', 'rr');
    mockFetch(() => jsonResponse(401, { code: 'UNAUTHORIZED', message: 'x' }));
    render(<App route="/admin" />);
    expect(await screen.findByRole('heading', { name: 'Yönetim paneli girişi' })).toBeInTheDocument();
    expect(getAccessToken()).toBeNull();
    expect(getRefreshToken()).toBeNull();
  });
});

describe('giriş sayfası', () => {
  it("başarılı girişte token'ları saklar ve panele geçer", async () => {
    const user = userEvent.setup();
    mockFetch((url) => {
      if (url.endsWith('/auth/login')) return jsonResponse(200, tokens);
      if (url.endsWith('/admin/me')) return jsonResponse(200, adminMe);
      return jsonResponse(404);
    });
    render(<App route="/admin/login" />);
    await user.type(screen.getByLabelText(/E-posta/), 'admin@bingol.edu.tr');
    await user.type(screen.getByLabelText(/Şifre/, { selector: 'input' }), 'sifre1234');
    await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
    expect(await screen.findByText('gizli panel')).toBeInTheDocument();
    expect(getAccessToken()).toBe('a1');
    expect(getRefreshToken()).toBe('r1');
  });

  it('hata kodunu çevrilmiş mesajla gösterir (EMAIL_NOT_VERIFIED)', async () => {
    const user = userEvent.setup();
    mockFetch(() => jsonResponse(403, { code: 'EMAIL_NOT_VERIFIED', message: 'sunucu mesajı' }));
    render(<App route="/admin/login" />);
    await user.type(screen.getByLabelText(/E-posta/), 'x@bingol.edu.tr');
    await user.type(screen.getByLabelText(/Şifre/, { selector: 'input' }), 'sifre1234');
    await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
    expect(await screen.findByText(/henüz doğrulanmamış/)).toBeInTheDocument();
  });

  it('yanlış şifrede INVALID_CREDENTIALS mesajı çıkar, boş alanlar doğrulanır', async () => {
    const user = userEvent.setup();
    const f = mockFetch(() => jsonResponse(401, { code: 'INVALID_CREDENTIALS', message: 'x' }));
    render(<App route="/admin/login" />);
    await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
    expect(screen.getAllByText('Bu alan zorunludur.')).toHaveLength(2);
    expect(f).not.toHaveBeenCalled();
    await user.type(screen.getByLabelText(/E-posta/), 'x@bingol.edu.tr');
    await user.type(screen.getByLabelText(/Şifre/, { selector: 'input' }), 'yanlis');
    await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
    await waitFor(() => expect(screen.getByText('E-posta veya şifre hatalı.')).toBeInTheDocument());
  });

  it('ADMIN olmayan hesapla girişte "yetkiniz yok" ekranı gelir', async () => {
    const user = userEvent.setup();
    mockFetch((url) =>
      url.endsWith('/auth/login')
        ? jsonResponse(200, tokens)
        : jsonResponse(403, { code: 'FORBIDDEN', message: 'x' }),
    );
    render(<App route="/admin/login" />);
    await user.type(screen.getByLabelText(/E-posta/), 'ogr@ogr.bingol.edu.tr');
    await user.type(screen.getByLabelText(/Şifre/, { selector: 'input' }), 'sifre1234');
    await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
    expect(await screen.findByText('Bu alana erişim yetkiniz yok')).toBeInTheDocument();
  });
});
