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
import { getAccessToken, getRefreshToken } from './tokens';

const tokens = { accessToken: 'a2', refreshToken: 'r2', expiresInSeconds: 900, tokenType: 'Bearer' };
const adminMe = { id: 1, email: 'admin@bingol.edu.tr', displayName: 'Yönetici', role: 'ADMIN' };
const challenge = {
  twoFactorRequired: true,
  challengeToken: 'chal-1',
  emailHint: 'ad***@bingol.edu.tr',
  expiresInSeconds: 600,
};

function App() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return (
    <QueryClientProvider client={qc}>
      <I18nProvider>
        <ThemeProvider>
          <MemoryRouter initialEntries={['/admin/login']}>
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

function body(init: RequestInit | undefined): Record<string, unknown> {
  return JSON.parse(String(init?.body)) as Record<string, unknown>;
}

async function passwordStep(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByLabelText(/E-posta/), 'admin@bingol.edu.tr');
  await user.type(screen.getByLabelText(/Şifre/, { selector: 'input' }), 'sifre1234');
  await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
}

describe('yönetici girişi: iki faktörlü adım', () => {
  it('202 gelince token saklanmaz, kod adımı açılır; kod doğrulanınca oturum açılır', async () => {
    const user = userEvent.setup();
    const f = mockFetch((url) => {
      if (url.endsWith('/auth/login')) return jsonResponse(202, challenge);
      if (url.endsWith('/auth/login/2fa')) return jsonResponse(200, tokens);
      if (url.endsWith('/admin/me')) return jsonResponse(200, adminMe);
      return jsonResponse(404);
    });
    render(<App />);
    await passwordStep(user);

    expect(await screen.findByRole('heading', { name: 'Giriş kodu' })).toBeInTheDocument();
    expect(screen.getByText('ad***@bingol.edu.tr')).toBeInTheDocument();
    expect(getAccessToken()).toBeNull();

    await user.type(screen.getByLabelText(/Giriş kodu/, { selector: 'input' }), '123456');
    await user.click(screen.getByRole('button', { name: 'Doğrula ve giriş yap' }));

    expect(await screen.findByText('gizli panel')).toBeInTheDocument();
    expect(getAccessToken()).toBe('a2');
    expect(getRefreshToken()).toBe('r2');
    const verify = f.mock.calls.find(([u]) => String(u).endsWith('/auth/login/2fa'));
    // "Bu tarayıcıya güven" varsayılan olarak işaretlidir
    expect(body(verify?.[1] as RequestInit)).toEqual({
      challengeToken: 'chal-1',
      code: '123456',
      trustDevice: true,
    });
  });

  it('güven kutusu kaldırılırsa trustDevice=false gider; 6 hane yoksa istek atılmaz', async () => {
    const user = userEvent.setup();
    const f = mockFetch((url) => {
      if (url.endsWith('/auth/login')) return jsonResponse(202, challenge);
      if (url.endsWith('/auth/login/2fa')) return jsonResponse(200, tokens);
      if (url.endsWith('/admin/me')) return jsonResponse(200, adminMe);
      return jsonResponse(404);
    });
    render(<App />);
    await passwordStep(user);
    const code = await screen.findByLabelText(/Giriş kodu/, { selector: 'input' });

    await user.type(code, '12');
    await user.click(screen.getByRole('button', { name: 'Doğrula ve giriş yap' }));
    expect(await screen.findByText('6 haneli kodu girin.')).toBeInTheDocument();
    expect(f.mock.calls.some(([u]) => String(u).endsWith('/auth/login/2fa'))).toBe(false);

    await user.type(code, '3456');
    await user.click(screen.getByRole('checkbox'));
    await user.click(screen.getByRole('button', { name: 'Doğrula ve giriş yap' }));
    await screen.findByText('gizli panel');
    const verify = f.mock.calls.find(([u]) => String(u).endsWith('/auth/login/2fa'));
    expect(body(verify?.[1] as RequestInit).trustDevice).toBe(false);
  });

  it('yanlış kod çevrilmiş hata gösterir ve oturum açılmaz', async () => {
    const user = userEvent.setup();
    mockFetch((url) => {
      if (url.endsWith('/auth/login')) return jsonResponse(202, challenge);
      if (url.endsWith('/auth/login/2fa'))
        return jsonResponse(400, { code: 'TWO_FACTOR_CODE_INVALID', message: 'x' });
      return jsonResponse(404);
    });
    render(<App />);
    await passwordStep(user);
    await user.type(await screen.findByLabelText(/Giriş kodu/, { selector: 'input' }), '000000');
    await user.click(screen.getByRole('button', { name: 'Doğrula ve giriş yap' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Kod hatalı');
    expect(getAccessToken()).toBeNull();
  });

  it('süresi dolmuş kod ve 429 durumlarını gösterir', async () => {
    const user = userEvent.setup();
    let n = 0;
    mockFetch((url) => {
      if (url.endsWith('/auth/login')) return jsonResponse(202, challenge);
      if (url.endsWith('/auth/login/2fa')) {
        n++;
        return n === 1
          ? jsonResponse(400, { code: 'TWO_FACTOR_CHALLENGE_EXPIRED', message: 'x' })
          : jsonResponse(429, { code: 'RATE_LIMITED', message: 'x' });
      }
      return jsonResponse(404);
    });
    render(<App />);
    await passwordStep(user);
    await user.type(await screen.findByLabelText(/Giriş kodu/, { selector: 'input' }), '111111');
    await user.click(screen.getByRole('button', { name: 'Doğrula ve giriş yap' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Kodun süresi doldu');

    await user.click(screen.getByRole('button', { name: 'Doğrula ve giriş yap' }));
    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('Çok fazla deneme'));
  });

  it('"Yeniden gönder" 3 dakika dolana dek kapalı ve geri sayım (3:00) gösterir; sunucu süresi varsa ondan başlar', async () => {
    const user = userEvent.setup();
    mockFetch((url) => {
      if (url.endsWith('/auth/login')) return jsonResponse(202, { ...challenge, resendAfterSeconds: 95 });
      return jsonResponse(404);
    });
    render(<App />);
    await passwordStep(user);
    const btn = await screen.findByRole('button', { name: /Kodu yeniden gönder/ });
    expect(btn).toBeDisabled();
    expect(btn).toHaveTextContent('Yeniden gönder (1:35)');
  });

  it('sunucu süre vermezse varsayılan 3:00 ile başlar', async () => {
    const user = userEvent.setup();
    mockFetch((url) => (url.endsWith('/auth/login') ? jsonResponse(202, challenge) : jsonResponse(404)));
    render(<App />);
    await passwordStep(user);
    expect(await screen.findByRole('button', { name: /Kodu yeniden gönder/ })).toHaveTextContent('Yeniden gönder (3:00)');
  });

  it('kodu yeniden gönderir ve bilgi mesajı gösterir', async () => {
    const user = userEvent.setup();
    const f = mockFetch((url) => {
      if (url.endsWith('/auth/login')) return jsonResponse(202, { ...challenge, resendAfterSeconds: 0 });
      if (url.endsWith('/auth/login/2fa/resend')) return jsonResponse(202, { expiresInSeconds: 600 });
      return jsonResponse(404);
    });
    render(<App />);
    await passwordStep(user);
    await user.click(await screen.findByRole('button', { name: 'Kodu yeniden gönder' }));
    expect(await screen.findByText('Yeni kod e-postanıza gönderildi.')).toBeInTheDocument();
    const resend = f.mock.calls.find(([u]) => String(u).endsWith('/auth/login/2fa/resend'));
    expect(body(resend?.[1] as RequestInit)).toEqual({ challengeToken: 'chal-1' });
  });

  it('"Girişe dön" şifre adımına geri götürür', async () => {
    const user = userEvent.setup();
    mockFetch((url) => (url.endsWith('/auth/login') ? jsonResponse(202, challenge) : jsonResponse(404)));
    render(<App />);
    await passwordStep(user);
    await user.click(await screen.findByRole('button', { name: 'Girişe dön' }));
    expect(await screen.findByRole('heading', { name: 'Yönetim paneli girişi' })).toBeInTheDocument();
  });
});
