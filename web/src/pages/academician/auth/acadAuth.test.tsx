// Akademisyen oturumu: yönetim oturumundan yalıtım, giriş (2FA dahil), kayıt -> başvuru -> beklemede, onay durumuna göre yönlendirme.
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it } from 'vitest';
import { AuthProvider } from '../../../auth/AuthProvider';
import { RequireAdmin } from '../../../auth/RequireAdmin';
import { tokensFor } from '../../../auth/tokens';
import { I18nProvider } from '../../../i18n/I18nProvider';
import { ThemeProvider } from '../../../lib/theme';
import { ToastProvider } from '../../../components/ui/Toast';
import { jsonResponse } from '../../../test/fetchMock';
import { APPROVED_ME, err, mockApi, renderAcademician, setAcadTokens } from '../testUtils';

const acad = tokensFor('acad');
const admin = tokensFor('admin');
const tokenResp = { accessToken: 'new-a', refreshToken: 'new-r', expiresInSeconds: 900, tokenType: 'Bearer' };

afterEach(() => {
  acad.clearTokens();
  admin.clearTokens();
});

describe('oturum yalıtımı (bileşen düzeyi)', () => {
  it('yalnız yönetici oturumu varken panel açılmaz: giriş sayfasına gider, /academician/me çağrılmaz', async () => {
    admin.setTokens('adm-a', 'adm-r');
    const api = mockApi().get('/admin/me', { id: 1, email: 'a@bingol.edu.tr', displayName: 'Y', role: 'ADMIN' });
    api.install();
    renderAcademician('/akademisyen/dersler');
    expect(await screen.findByRole('heading', { name: 'Akademisyen girişi' })).toBeInTheDocument();
    expect(api.callsTo('GET', '/academician/me')).toHaveLength(0);
    // yönetici token'ı hiçbir akademisyen isteğine eklenmedi
    expect(api.calls.every((c) => !String(c.headers.Authorization ?? '').includes('adm-a'))).toBe(true);
  });

  it('yalnız akademisyen oturumu varken yönetim paneli açılmaz', async () => {
    setAcadTokens();
    const api = mockApi().get('/academician/me', APPROVED_ME);
    api.install();
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={qc}>
        <I18nProvider>
          <ThemeProvider>
            <ToastProvider>
              <MemoryRouter initialEntries={['/admin']}>
                <AuthProvider>
                  <Routes>
                    <Route path="/admin/login" element={<p>yonetim girisi</p>} />
                    <Route
                      path="/admin"
                      element={
                        <RequireAdmin>
                          <p>gizli yonetim</p>
                        </RequireAdmin>
                      }
                    />
                  </Routes>
                </AuthProvider>
              </MemoryRouter>
            </ToastProvider>
          </ThemeProvider>
        </I18nProvider>
      </QueryClientProvider>,
    );
    expect(await screen.findByText('yonetim girisi')).toBeInTheDocument();
    expect(screen.queryByText('gizli yonetim')).toBeNull();
    expect(api.callsTo('GET', '/admin/me')).toHaveLength(0);
  });

  it('akademisyen oturumu düşünce /akademisyen/giris\'e gider; yönetim girişine ve yönetici token\'ına dokunmaz', async () => {
    setAcadTokens();
    admin.setTokens('adm-a', 'adm-r');
    const api = mockApi()
      .get('/academician/me', () => err(401, 'UNAUTHORIZED'))
      .post('/auth/refresh', () => err(401, 'REFRESH_INVALID'));
    api.install();
    renderAcademician('/akademisyen/dersler');
    expect(await screen.findByRole('heading', { name: 'Akademisyen girişi' })).toBeInTheDocument();
    expect(screen.queryByText('yonetim girisi')).toBeNull();
    expect(acad.getAccessToken()).toBeNull();
    expect(admin.getAccessToken()).toBe('adm-a');
    expect(admin.getRefreshToken()).toBe('adm-r');
  });

  it('korumalı bir istek 401 + refresh reddi alırsa oturum kapanır ve giriş sayfasına yönlendirilir (yönetim değil)', async () => {
    setAcadTokens();
    const api = mockApi()
      .get('/academician/me', APPROVED_ME)
      .get('/academician/courses', () => err(401, 'UNAUTHORIZED'))
      .post('/auth/refresh', () => err(401, 'REFRESH_INVALID'));
    api.install();
    renderAcademician('/akademisyen/dersler');
    expect(await screen.findByRole('heading', { name: 'Akademisyen girişi' })).toBeInTheDocument();
    expect(acad.getRefreshToken()).toBeNull();
  });
});

describe('giriş', () => {
  it('başarılı giriş (onaylı akademisyen) panele götürür; yönetim girişi kullanılmaz', async () => {
    const api = mockApi()
      .post('/auth/login', tokenResp)
      .get('/academician/me', APPROVED_ME)
      .get('/academician/courses', []);
    api.install();
    renderAcademician('/akademisyen/giris');
    const user = userEvent.setup();
    await user.type(await screen.findByLabelText(/E-posta/), 'hoca@bingol.edu.tr');
    await user.type(screen.getByLabelText(/^Parola/, { selector: 'input' }), 'gizli-parola');
    await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
    expect(await screen.findByRole('heading', { name: /Merhaba, Dr\. Öğr\. Üyesi Hoca/ })).toBeInTheDocument();
    expect(acad.getAccessToken()).toBe('new-a');
    expect(admin.getAccessToken()).toBeNull();
    expect(api.callsTo('GET', '/admin/me')).toHaveLength(0);
  });

  it('iki faktörlü giriş: 202 challenge -> kod -> oturum açılır', async () => {
    const api = mockApi()
      .post('/auth/login', () => jsonResponse(202, { twoFactorRequired: true, challengeToken: 'ch1', emailHint: 'h***@bingol.edu.tr', expiresInSeconds: 600 }))
      .post('/auth/login/2fa', (r) => (JSON.stringify(r.body).includes('123456') ? tokenResp : err(401, 'TWO_FACTOR_CODE_INVALID')))
      .get('/academician/me', APPROVED_ME)
      .get('/academician/courses', []);
    api.install();
    renderAcademician('/akademisyen/giris');
    const user = userEvent.setup();
    await user.type(await screen.findByLabelText(/E-posta/), 'hoca@bingol.edu.tr');
    await user.type(screen.getByLabelText(/^Parola/, { selector: 'input' }), 'gizli-parola');
    await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
    expect(await screen.findByRole('heading', { name: 'Giriş kodu' })).toBeInTheDocument();
    expect(acad.getAccessToken()).toBeNull(); // kod doğrulanmadan oturum yok
    await user.type(screen.getByLabelText(/6 haneli kod/), '123456');
    await user.click(screen.getByRole('button', { name: 'Doğrula' }));
    expect(await screen.findByRole('heading', { name: /Merhaba/ })).toBeInTheDocument();
    expect(acad.getAccessToken()).toBe('new-a');
  });

  it('hatalı parola: hata gösterilir, e-posta alanı korunur', async () => {
    const api = mockApi().post('/auth/login', () => err(401, 'INVALID_CREDENTIALS'));
    api.install();
    renderAcademician('/akademisyen/giris');
    const user = userEvent.setup();
    await user.type(await screen.findByLabelText(/E-posta/), 'hoca@bingol.edu.tr');
    await user.type(screen.getByLabelText(/^Parola/, { selector: 'input' }), 'yanlis');
    await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('E-posta ya da parola hatalı.');
    expect(screen.getByLabelText(/E-posta/)).toHaveValue('hoca@bingol.edu.tr');
  });
});

describe('kayıt -> başvuru -> beklemede', () => {
  it('e-posta + kod + unvan/ad/soyad; fakülte/bölüm/sınıf gönderilmez; PENDING ise beklemede sayfası açılır', async () => {
    let me: Record<string, unknown> = { status: 'NONE', approvalMode: null, title: null, firstName: null, lastName: null, unit: null, rejectReason: null };
    const api = mockApi()
      .post('/auth/register', () => jsonResponse(202, { message: 'ok' }))
      .post('/auth/verify-email', tokenResp)
      .get('/academician/me', () => me)
      .post('/academician/apply', () => {
        me = { ...me, status: 'PENDING', title: 'Prof. Dr.', firstName: 'Deneme', lastName: 'Hoca' };
        return { status: 'PENDING' };
      });
    api.install();
    renderAcademician('/akademisyen/kayit');
    const user = userEvent.setup();
    await user.type(await screen.findByLabelText(/E-posta/), 'deneme.hoca@bingol.edu.tr');
    await user.type(screen.getByLabelText(/^Parola/, { selector: 'input' }), 'gizli-parola');
    await user.click(screen.getByRole('checkbox'));
    await user.click(screen.getByRole('button', { name: 'Kod gönder' }));

    const reg = api.callsTo('POST', '/auth/register')[0].body as Record<string, unknown>;
    expect(reg).toMatchObject({ email: 'deneme.hoca@bingol.edu.tr', acceptTerms: true });
    expect(reg).not.toHaveProperty('faculty');
    expect(reg).not.toHaveProperty('department');
    expect(reg).not.toHaveProperty('grade');

    await user.type(await screen.findByLabelText(/Doğrulama kodu/), '654321');
    await user.click(screen.getByRole('button', { name: 'Doğrula ve devam et' }));
    expect(await screen.findByRole('heading', { name: 'Başvuru bilgileriniz' })).toBeInTheDocument();
    expect(acad.getAccessToken()).toBe('new-a');

    await user.type(screen.getByLabelText(/Unvan/), 'Prof. Dr.');
    await user.type(screen.getByLabelText(/^Ad/), 'Deneme');
    await user.type(screen.getByLabelText(/Soyad/), 'Hoca');
    await user.click(screen.getByRole('button', { name: 'Başvuruyu gönder' }));
    expect(await screen.findByRole('heading', { name: 'Başvurunuz inceleniyor' })).toBeInTheDocument();
    expect(api.callsTo('POST', '/academician/apply')[0].body).toEqual({ title: 'Prof. Dr.', firstName: 'Deneme', lastName: 'Hoca' });
  });

  it('başvuru formu zorunlu alanları doğrular ve hata olunca girdiyi korur', async () => {
    setAcadTokens();
    const api = mockApi()
      .get('/academician/me', { status: 'NONE', approvalMode: null, title: null, firstName: null, lastName: null, unit: null, rejectReason: null })
      .post('/academician/apply', () => err(400, 'AC_FIELD_INVALID'));
    api.install();
    renderAcademician('/akademisyen/beklemede');
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Başvuruyu gönder' }));
    expect((await screen.findAllByText('Bu alan zorunlu.')).length).toBe(3);
    expect(api.callsTo('POST', '/academician/apply')).toHaveLength(0);
    await user.type(screen.getByLabelText(/Unvan/), 'Dr.');
    await user.type(screen.getByLabelText(/^Ad/), 'Deneme');
    await user.type(screen.getByLabelText(/Soyad/), 'Hoca');
    await user.click(screen.getByRole('button', { name: 'Başvuruyu gönder' }));
    expect(await screen.findByText(/Girilen bilgilerden biri geçersiz/)).toBeInTheDocument();
    expect(screen.getByLabelText(/^Ad/)).toHaveValue('Deneme');
  });
});

describe('onay durumuna göre yönlendirme', () => {
  it('onaylı akademisyen panoya düşer', async () => {
    setAcadTokens();
    mockApi().get('/academician/me', APPROVED_ME).get('/academician/courses', []).install();
    renderAcademician('/akademisyen');
    expect(await screen.findByRole('heading', { name: /Merhaba/ })).toBeInTheDocument();
  });

  it('REJECTED: gerekçe gösterilir, düzeltip yeniden başvurulabilir', async () => {
    setAcadTokens();
    const api = mockApi()
      .get('/academician/me', { ...APPROVED_ME, status: 'REJECTED', approvalMode: null, rejectReason: 'Kurumsal kimlik doğrulanamadı.' })
      .post('/academician/apply', { status: 'PENDING' });
    api.install();
    renderAcademician('/akademisyen/dersler');
    expect(await screen.findByRole('heading', { name: 'Başvurunuz reddedildi' })).toBeInTheDocument();
    expect(screen.getByText('Kurumsal kimlik doğrulanamadı.')).toBeInTheDocument();
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Düzeltip yeniden başvur' }));
    await user.click(screen.getByRole('button', { name: 'Yeniden başvur' }));
    await waitFor(() => expect(api.callsTo('POST', '/academician/apply')).toHaveLength(1));
  });

  it('REVOKED: yeniden başvuru düğmesi yok, gerekçe var', async () => {
    setAcadTokens();
    mockApi().get('/academician/me', { ...APPROVED_ME, status: 'REVOKED', rejectReason: 'Görev değişikliği.' }).install();
    renderAcademician('/akademisyen/beklemede');
    expect(await screen.findByRole('heading', { name: 'Akademisyen yetkiniz kaldırıldı' })).toBeInTheDocument();
    expect(screen.getByText('Görev değişikliği.')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /başvur/i })).toBeNull();
  });

  it('PENDING kullanıcı korumalı sayfayı açarsa beklemede sayfasına yönlendirilir', async () => {
    setAcadTokens();
    mockApi().get('/academician/me', { ...APPROVED_ME, status: 'PENDING', approvalMode: null }).install();
    renderAcademician('/akademisyen/dersler');
    expect(await screen.findByRole('heading', { name: 'Başvurunuz inceleniyor' })).toBeInTheDocument();
  });

  it('API 403 ACADEMICIAN_NOT_APPROVED dönerse (yetki sonradan kalktı) beklemede sayfasına yönlendirilir', async () => {
    setAcadTokens();
    let revoked = false;
    const api = mockApi()
      .get('/academician/me', () => (revoked ? { ...APPROVED_ME, status: 'REVOKED', rejectReason: 'Yetki kaldırıldı.' } : APPROVED_ME))
      .get('/academician/courses', () => {
        revoked = true;
        return err(403, 'ACADEMICIAN_NOT_APPROVED');
      });
    api.install();
    renderAcademician('/akademisyen/dersler');
    expect(await screen.findByRole('heading', { name: 'Akademisyen yetkiniz kaldırıldı' })).toBeInTheDocument();
  });
});
