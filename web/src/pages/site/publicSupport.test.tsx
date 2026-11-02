import { fireEvent, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { dictionaries } from '../../i18n/all';
import { isoDate } from '../../lib/date';
import {
  FORM_TOKEN_MAX_AGE_MS,
  formTokenStale,
  msUntilFillAllowed,
  validatePublicForm,
} from '../../api/publicSupport';
import { resetCookieChoice } from '../../lib/cookieConsent';
import { AppRoutes } from '../../routes';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { daysOfMonth, parseDay, weekDates } from './menuLogic';

const info = {
  appName: 'BÜ Kampüs',
  website: null,
  contactEmail: 'info@bingol.edu.tr',
  supportEmail: null,
  phone: null,
  address: null,
  social: { instagram: null, twitter: null, youtube: null },
  banner: null,
  maintenance: { enabled: false, message: null },
  languages: ['tr', 'en', 'ar'],
};

function renderAt(route: string, lang: 'tr' | 'en' | 'ar' = 'tr') {
  return renderWithProviders(
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>,
    { route, lang },
  );
}

beforeEach(() => resetCookieChoice());
afterEach(() => vi.unstubAllGlobals());

describe('yemek listesi ayrıştırma', () => {
  it('öğün başlıklarını, kaloriyi ve alerjenleri ayırır', () => {
    const d = parseDay(['Kahvaltı', 'Peynir (120 kcal)', 'Öğle yemeği:', 'Mercimek çorbası', 'Pilav 300 kcal', 'Alerjen: gluten, süt', 'Toplam kalori: 1450']);
    expect(d.sections.map((s) => s.key)).toEqual(['breakfast', 'lunch']);
    expect(d.sections[0].dishes[0]).toEqual({ text: 'Peynir', kcal: 120 });
    expect(d.sections[1].dishes[1]).toEqual({ text: 'Pilav', kcal: 300 });
    expect(d.allergens).toEqual(['gluten', 'süt']);
    expect(d.totalKcal).toBe(1450);
    expect(d.dishCount).toBe(3);
  });

  it('başlıksız listeyi tek "menu" bölümünde toplar, boş satırları atar', () => {
    const d = parseDay(['Çorba', '  ', 'Pilav']);
    expect(d.sections).toHaveLength(1);
    expect(d.sections[0].key).toBe('menu');
    expect(d.dishCount).toBe(2);
    expect(d.totalKcal).toBeNull();
  });

  it('hafta Pazartesi başlar ve ay sınırını aşabilir; ay günleri doğru sayıda', () => {
    expect(weekDates('2026-10-28')[0]).toBe('2026-10-26');
    expect(weekDates('2026-10-28')[6]).toBe('2026-11-01');
    expect(daysOfMonth('2026-02')).toHaveLength(28);
  });
});

describe('yemek sayfası', () => {
  it('"Kaynak:" satırı artık gösterilmez ve çeviri anahtarı yoktur', async () => {
    mockFetch((url) => {
      if (url.includes('/status')) return jsonResponse(200, {});
      if (url.includes('/menu')) return jsonResponse(200, [{ date: isoDate(new Date()), items: ['Mercimek çorbası'] }]);
      return jsonResponse(200, info);
    });
    renderAt('/menu');
    expect(await screen.findByText('Mercimek çorbası')).toBeInTheDocument();
    expect(screen.queryByText(/sks\.bingol\.edu\.tr/)).toBeNull();
    for (const lang of ['tr', 'en', 'ar'] as const)
      expect(Object.keys(dictionaries[lang])).not.toContain('pg.menu.source');
  });

  it('boş ay için boş durumu gösterir', async () => {
    mockFetch((url) => {
      if (url.includes('/status')) return jsonResponse(200, {});
      if (url.includes('/menu')) return jsonResponse(200, []);
      return jsonResponse(200, info);
    });
    renderAt('/menu');
    fireEvent.click(await screen.findByRole('button', { name: 'Aylık' }));
    expect(await screen.findByText('Bu ay için menü yayımlanmadı')).toBeInTheDocument();
  });
});

describe('herkese açık destek formu', () => {
  it('istemci doğrulaması eksik/geçersiz alanları yakalar', () => {
    expect(validatePublicForm({ name: '', email: 'x', message: 'kısa' })).toEqual({
      name: 'required',
      email: 'invalid',
      message: 'tooShort',
    });
    expect(validatePublicForm({ name: 'Ali', email: 'ali@example.com', message: 'Yeterince uzun bir mesaj' })).toEqual({});
  });

  it('geçersiz formu göndermez; geçerli form kod adımına, doğru kod durum bağlantısına götürür', async () => {
    const calls: { url: string; body: Record<string, unknown> }[] = [];
    let tokens = 0;
    mockFetch((url, init) => {
      if (url.endsWith('/public/support/form-token')) {
        tokens += 1;
        return jsonResponse(200, { formToken: `v1.tok-${tokens}`, minFillSeconds: 0 });
      }
      if (url.includes('/public/support/')) {
        calls.push({ url, body: JSON.parse(String(init.body)) as Record<string, unknown> });
        if (url.endsWith('/tickets')) return jsonResponse(202, { status: 'CODE_SENT', expiresInMinutes: 10 });
        if (url.endsWith('/verify')) return jsonResponse(200, { ticketId: 42, trackToken: 'tok-abc' });
      }
      return jsonResponse(200, info);
    });
    renderAt('/contact');
    const submit = await screen.findByRole('button', { name: 'Doğrulama kodu gönder' });
    fireEvent.click(submit);
    expect(await screen.findByText('Adınızı yazın.')).toBeInTheDocument();
    expect(calls).toHaveLength(0);

    fireEvent.change(screen.getByLabelText(/Ad soyad/), { target: { value: 'Ali Veli' } });
    fireEvent.change(screen.getByLabelText(/E-posta/), { target: { value: 'ali@example.com' } });
    fireEvent.change(screen.getByLabelText(/Mesajınız/), { target: { value: 'Uygulama açılmıyor, yardım eder misiniz?' } });
    fireEvent.click(screen.getByRole('button', { name: 'Doğrulama kodu gönder' }));

    expect(await screen.findByText('E-postanızı doğrulayın')).toBeInTheDocument();
    expect(calls[0].body).toMatchObject({ name: 'Ali Veli', email: 'ali@example.com', category: 'TECHNICAL', website: '' });
    expect(typeof calls[0].body.elapsedMs).toBe('number');
    // T-062: form açılırken alınan imzalı jeton gönderimde formToken olarak gider
    expect(calls[0].body.formToken).toBe('v1.tok-1');

    fireEvent.change(screen.getByLabelText(/Doğrulama kodu/), { target: { value: '12' } });
    fireEvent.click(screen.getByRole('button', { name: 'Doğrula ve gönder' }));
    expect(await screen.findByText('Kod 6 haneli olmalı.')).toBeInTheDocument();
    expect(calls).toHaveLength(1);

    fireEvent.change(screen.getByLabelText(/Doğrulama kodu/), { target: { value: '123456' } });
    fireEvent.click(screen.getByRole('button', { name: 'Doğrula ve gönder' }));
    const link = await screen.findByRole('link', { name: 'Talebimi görüntüle' });
    expect(link).toHaveAttribute('href', '/tr/support/track?token=tok-abc');
    expect(calls[1].body).toEqual({ email: 'ali@example.com', code: '123456' });
  });

  it('sunucu hatası (hız sınırı) kullanıcıya gösterilir', async () => {
    mockFetch((url) => {
      if (url.includes('/public/support/tickets')) return jsonResponse(429, { code: 'RATE_LIMITED', message: 'Çok fazla deneme.' });
      return jsonResponse(200, info);
    });
    renderAt('/contact');
    fireEvent.change(await screen.findByLabelText(/Ad soyad/), { target: { value: 'Ali' } });
    fireEvent.change(screen.getByLabelText(/E-posta/), { target: { value: 'ali@example.com' } });
    fireEvent.change(screen.getByLabelText(/Mesajınız/), { target: { value: 'Yeterince uzun bir mesaj yazıyorum' } });
    fireEvent.click(screen.getByRole('button', { name: 'Doğrulama kodu gönder' }));
    expect(await screen.findByRole('alert')).toBeInTheDocument();
  });
});

describe('kod yeniden gönderme beklemesi (3 dk)', () => {
  function fill() {
    fireEvent.change(screen.getByLabelText(/Ad soyad/), { target: { value: 'Ali' } });
    fireEvent.change(screen.getByLabelText(/E-posta/), { target: { value: 'ali@example.com' } });
    fireEvent.change(screen.getByLabelText(/Mesajınız/), { target: { value: 'Yeterince uzun bir mesaj yazıyorum' } });
    fireEvent.click(screen.getByRole('button', { name: 'Doğrulama kodu gönder' }));
  }

  it('kod adımında "Yeniden gönder (3:00)" kapalıdır; sunucu süresi varsa ondan başlar', async () => {
    mockFetch((url) => {
      if (url.endsWith('/public/support/form-token')) return jsonResponse(200, { formToken: 'v1.t', minFillSeconds: 0 });
      if (url.endsWith('/public/support/tickets')) return jsonResponse(202, { status: 'CODE_SENT', expiresInMinutes: 10, resendAfterSeconds: 120 });
      return jsonResponse(200, info);
    });
    renderAt('/contact');
    fireEvent.change(await screen.findByLabelText(/Ad soyad/), { target: { value: 'Ali' } });
    fill();
    expect(await screen.findByText('E-postanızı doğrulayın')).toBeInTheDocument();
    const btn = screen.getByRole('button', { name: /Kodu yeniden gönder/ });
    expect(btn).toBeDisabled();
    expect(btn).toHaveTextContent('Yeniden gönder (2:00)');
  });

  it('sunucu 429 RESEND_COOLDOWN dönerse hata yerine kod adımı açılır ve sayaç Retry-After ile sürer', async () => {
    mockFetch((url) => {
      if (url.endsWith('/public/support/form-token')) return jsonResponse(200, { formToken: 'v1.t', minFillSeconds: 0 });
      if (url.endsWith('/public/support/tickets'))
        return jsonResponse(429, { code: 'RESEND_COOLDOWN', message: 'bekleyin', retryAfterSeconds: 95 }); // başlıksız: gövdeden okunur
      return jsonResponse(200, info);
    });
    renderAt('/contact');
    fireEvent.change(await screen.findByLabelText(/Ad soyad/), { target: { value: 'Ali' } });
    fill();
    expect(await screen.findByText('E-postanızı doğrulayın')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Kodu yeniden gönder/ })).toHaveTextContent('Yeniden gönder (1:35)');
  });
});

describe('form jetonu (T-062)', () => {
  it('jeton yoksa ya da 100 dk üstündeyse yenilenir; hızlı gönderim için kalan bekleme hesaplanır', () => {
    const now = 1_000_000_000;
    expect(formTokenStale(null, now)).toBe(true);
    expect(formTokenStale(now - 1000, now)).toBe(false);
    expect(formTokenStale(now - FORM_TOKEN_MAX_AGE_MS, now)).toBe(true);
    expect(FORM_TOKEN_MAX_AGE_MS).toBeLessThan(2 * 60 * 60 * 1000);
    expect(msUntilFillAllowed(now, 3, now)).toBe(3250);
    expect(msUntilFillAllowed(now - 1000, 3, now)).toBe(2250);
    expect(msUntilFillAllowed(now - 10_000, 3, now)).toBe(0);
    expect(msUntilFillAllowed(now, 0, now)).toBe(250);
  });

  it('form açılırken GET form-token çağrılır ve jeton gönderime eklenir (jeton olmadan gönderilmez)', async () => {
    const seen: string[] = [];
    let posted: Record<string, unknown> | null = null;
    mockFetch((url, init) => {
      seen.push(url);
      if (url.endsWith('/public/support/form-token')) return jsonResponse(200, { formToken: 'v1.abc.def.sig', minFillSeconds: 0 });
      if (url.endsWith('/public/support/tickets')) {
        posted = JSON.parse(String(init.body)) as Record<string, unknown>;
        return jsonResponse(202, { status: 'CODE_SENT', expiresInMinutes: 10 });
      }
      return jsonResponse(200, info);
    });
    renderAt('/contact');
    await waitFor(() => expect(seen.some((u) => u.endsWith('/public/support/form-token'))).toBe(true));
    fireEvent.change(await screen.findByLabelText(/Ad soyad/), { target: { value: 'Ali' } });
    fireEvent.change(screen.getByLabelText(/E-posta/), { target: { value: 'ali@example.com' } });
    fireEvent.change(screen.getByLabelText(/Mesajınız/), { target: { value: 'Yeterince uzun bir mesaj yazıyorum' } });
    fireEvent.click(screen.getByRole('button', { name: 'Doğrulama kodu gönder' }));
    expect(await screen.findByText('E-postanızı doğrulayın')).toBeInTheDocument();
    expect(posted).toMatchObject({ formToken: 'v1.abc.def.sig' });
  });

  it('açılıştaki jeton isteği başarısızsa gönderimde yeniden denenir; yine olmazsa gönderim yapılmaz ve hata gösterilir', async () => {
    let ticketPosts = 0;
    let tokenCalls = 0;
    mockFetch((url) => {
      if (url.endsWith('/public/support/form-token')) {
        tokenCalls += 1;
        return jsonResponse(500, { code: 'SERVER_ERROR', message: 'x' });
      }
      if (url.endsWith('/public/support/tickets')) {
        ticketPosts += 1;
        return jsonResponse(202, { status: 'CODE_SENT', expiresInMinutes: 10 });
      }
      return jsonResponse(200, info);
    });
    renderAt('/contact');
    fireEvent.change(await screen.findByLabelText(/Ad soyad/), { target: { value: 'Ali' } });
    fireEvent.change(screen.getByLabelText(/E-posta/), { target: { value: 'ali@example.com' } });
    fireEvent.change(screen.getByLabelText(/Mesajınız/), { target: { value: 'Yeterince uzun bir mesaj yazıyorum' } });
    await waitFor(() => expect(tokenCalls).toBeGreaterThanOrEqual(1));
    const before = tokenCalls;
    fireEvent.click(screen.getByRole('button', { name: 'Doğrulama kodu gönder' }));
    expect(await screen.findByRole('alert')).toBeInTheDocument();
    expect(tokenCalls).toBeGreaterThan(before);
    expect(ticketPosts).toBe(0);
  });

  it('kod adımından geri dönüp yeniden gönderince YENİ jeton alınır (jeton başına en çok 3 gönderim)', async () => {
    const posts: Record<string, unknown>[] = [];
    let n = 0;
    mockFetch((url, init) => {
      if (url.endsWith('/public/support/form-token')) {
        n += 1;
        return jsonResponse(200, { formToken: `v1.t${n}`, minFillSeconds: 0 });
      }
      if (url.endsWith('/public/support/tickets')) {
        posts.push(JSON.parse(String(init.body)) as Record<string, unknown>);
        return jsonResponse(202, { status: 'CODE_SENT', expiresInMinutes: 10 });
      }
      return jsonResponse(200, info);
    });
    renderAt('/contact');
    fireEvent.change(await screen.findByLabelText(/Ad soyad/), { target: { value: 'Ali' } });
    fireEvent.change(screen.getByLabelText(/E-posta/), { target: { value: 'ali@example.com' } });
    fireEvent.change(screen.getByLabelText(/Mesajınız/), { target: { value: 'Yeterince uzun bir mesaj yazıyorum' } });
    fireEvent.click(screen.getByRole('button', { name: 'Doğrulama kodu gönder' }));
    await screen.findByText('E-postanızı doğrulayın');
    fireEvent.click(screen.getByRole('button', { name: 'Bilgileri düzenle' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Doğrulama kodu gönder' }));
    await waitFor(() => expect(posts).toHaveLength(2));
    expect(posts[0].formToken).toBe('v1.t1');
    expect(posts[1].formToken).not.toBe('v1.t1');
  });
});

describe('talep durum sayfası', () => {
  it('anahtar yoksa uyarır; varsa konuşmayı gösterir ve yeni mesaj gönderir', async () => {
    renderAtNoToken();
    expect(await screen.findByText(/Bağlantı eksik veya geçersiz/)).toBeInTheDocument();
  });

  it('konuşmayı gösterir, yeni mesajı gönderir', async () => {
    let posted: Record<string, unknown> | null = null;
    const detail = (extra: unknown[] = []) => ({
      ticket: { id: 42, category: 'TECHNICAL', subject: 'Uygulama açılmıyor', status: 'ANSWERED', createdAt: '2026-10-25T10:00:00Z', updatedAt: '2026-10-25T10:00:00Z', publicTicket: true },
      messages: [
        { id: 1, fromStaff: false, text: 'Sorunum var', createdAt: '2026-10-25T10:00:00Z' },
        { id: 2, fromStaff: true, text: 'Güncelleyin lütfen', createdAt: '2026-10-25T11:00:00Z' },
        ...extra,
      ],
    });
    mockFetch((url, init) => {
      if (url.endsWith('/public/support/track')) return jsonResponse(200, detail());
      if (url.endsWith('/public/support/track/messages')) {
        posted = JSON.parse(String(init.body)) as Record<string, unknown>;
        return jsonResponse(200, detail([{ id: 3, fromStaff: false, text: 'Teşekkürler', createdAt: '2026-10-25T12:00:00Z' }]));
      }
      return jsonResponse(200, info);
    });
    renderAt('/tr/support/track?token=tok-abc');
    expect(await screen.findByText('Güncelleyin lütfen')).toBeInTheDocument();
    expect(screen.getByText('Yanıtlandı')).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Yeni mesaj'), { target: { value: 'Teşekkürler' } });
    fireEvent.click(screen.getByRole('button', { name: 'Gönder' }));
    await waitFor(() => expect(screen.getAllByText('Teşekkürler').length).toBeGreaterThan(0));
    expect(posted).toEqual({ token: 'tok-abc', text: 'Teşekkürler' });
  });

  it('geçersiz anahtar için bulunamadı gösterir', async () => {
    mockFetch((url) =>
      url.includes('/public/support/track') ? jsonResponse(404, { code: 'TICKET_NOT_FOUND', message: 'x' }) : jsonResponse(200, info),
    );
    renderAt('/support/track?token=bad');
    expect(await screen.findByText('Talep bulunamadı')).toBeInTheDocument();
  });
});

function renderAtNoToken() {
  mockFetch(() => jsonResponse(200, info));
  return renderAt('/support/track');
}
