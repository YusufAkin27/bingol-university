import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { dictionaries } from '../../i18n/all';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import AppealsPage from './AppealsPage';
import BlocklistPage from './BlocklistPage';
import ClubAuditPage from './ClubAuditPage';
import CryptoPage from './CryptoPage';
import EventApplicationsPage from './EventApplicationsPage';
import ReportsPage from './ReportsPage';
import SettingsPage from './SettingsPage';
import SuspendRecommendationsPage from './SuspendRecommendationsPage';

const STATUS = {
  activeKeyId: 'k2',
  keyIds: ['k1', 'k2'],
  devKey: false,
  adminDecryptEnabled: true,
  dekCountsByMasterKey: { k1: 3, k2: 10 },
};

describe('Şifreleme durumu sayfası', () => {
  function setup(statusOverride: Partial<typeof STATUS> = {}) {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/admin/crypto/status')) return jsonResponse(200, { ...STATUS, ...statusOverride });
      if (url.includes('/admin/users')) {
        return jsonResponse(200, {
          items: [{ id: 5, email: 'a@bingol.edu.tr', displayName: 'Ayşe Demir' }],
          page: 0,
          totalPages: 1,
          totalItems: 1,
        });
      }
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    return calls;
  }

  it('anahtar durumunu gösterir; eski uyarı kutusu ve çözme formu yoktur', async () => {
    setup();
    renderWithProviders(<CryptoPage />, { route: '/admin/crypto' });
    expect((await screen.findAllByText('k2', { selector: 'code' })).length).toBe(2);
    expect(await screen.findByText('Yeniden sarma gerekli')).toBeInTheDocument();
    expect(screen.queryByTestId('decrypt-warning')).toBeNull();
    expect(screen.queryByRole('button', { name: 'Mesajları çöz' })).toBeNull();
    expect(screen.queryByRole('textbox', { name: /Gerekçe/ })).toBeNull();
  });

  it('kullanıcı arayıp sohbet görüntüleyiciye bağlantı verir', async () => {
    setup();
    renderWithProviders(<CryptoPage />);
    await screen.findByText('Yeniden sarma gerekli');
    await userEvent.type(screen.getByRole('textbox', { name: /Kullanıcı ara/ }), 'ayşe');
    const link = await screen.findByRole('link', { name: 'Mesajları aç' });
    expect(link.getAttribute('href')).toMatch(/\/users\/5\/messages$/);
  });

  it('sunucuda kapalıysa uyarır ve bağlantı vermez', async () => {
    setup({ adminDecryptEnabled: false });
    renderWithProviders(<CryptoPage />);
    expect(await screen.findByText(/sunucu ayarıyla kapatılmış/)).toBeInTheDocument();
    await userEvent.type(screen.getByRole('textbox', { name: /Kullanıcı ara/ }), 'ayşe');
    await screen.findByText('Ayşe Demir');
    expect(screen.queryByRole('link', { name: 'Mesajları aç' })).toBeNull();
  });
});

describe('Rapor kuyruğu güncellemeleri', () => {
  const mk = (id: number, over: Record<string, unknown> = {}) => ({
    id,
    reporterId: 1,
    targetType: 'MESSAGE_IMAGE',
    targetId: 500 + id,
    reason: 'OTHER',
    note: `not-${id}`,
    status: 'OPEN',
    resolution: null,
    createdAt: '2026-01-01T10:00:00Z',
    priority: 130,
    reasonCode: null,
    preview: { kind: 'TEXT', url: null, thumbnailUrl: null, mime: null, text: `önizleme-${id}` },
    hidden: true,
    hiddenBy: 'AUTO',
    openReporters: 3,
    ...over,
  });

  it('öncelik sırasıyla ister, rozetleri gösterir ve toplu kararı gönderir', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/reason-templates')) {
        return jsonResponse(200, [{ code: 'SPAM', text: 'Spam içerik', texts: { tr: 'Spam içerik', en: 'Spam', ar: 'x' } }]);
      }
      if (url.includes('/bulk-resolve')) {
        return jsonResponse(200, [
          { id: 1, ok: true, error: null },
          { id: 2, ok: false, error: 'ALREADY_RESOLVED' },
        ]);
      }
      if (url.includes('/admin/reports')) return jsonResponse(200, { items: [mk(1), mk(2)], nextCursor: null });
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderWithProviders(<ReportsPage />, { route: '/admin/reports' });

    await screen.findAllByText('önizleme-1');
    const first = calls.find((c) => c.url.includes('/admin/reports?'));
    expect(first?.url).toContain('order=priority');
    expect(first?.url).toContain('status=OPEN');
    expect(screen.getAllByText('Öncelik 130').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Otomatik gizlendi').length).toBeGreaterThan(0);
    expect(screen.getAllByText('3 raporlayan').length).toBeGreaterThan(0);

    await userEvent.click(screen.getByRole('checkbox', { name: 'Rapor 1 seç' }));
    await userEvent.click(screen.getByRole('checkbox', { name: 'Rapor 2 seç' }));
    const bar = screen.getByRole('region', { name: 'Toplu karar' });
    expect(within(bar).getByText('2 rapor seçildi')).toBeInTheDocument();
    await userEvent.click(within(bar).getByRole('button', { name: 'Seçilenlere uygula' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Reddet' }));

    await waitFor(() => {
      const post = calls.find((c) => c.url.includes('/bulk-resolve'));
      expect(JSON.parse(String(post?.init.body))).toEqual({ ids: [1, 2], action: 'DISMISS' });
    });
    expect(await screen.findByText(/Başarısız olanlar: #2/)).toBeInTheDocument();
  });

  it('hedef türü süzgeci istek parametresine yansır', async () => {
    const urls: string[] = [];
    mockFetch((url) => {
      urls.push(url);
      if (url.includes('/admin/reports')) return jsonResponse(200, { items: [], nextCursor: null });
      return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
    });
    renderWithProviders(<ReportsPage />);
    await screen.findByText('Bekleyen rapor yok');
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Hedef türü' }), 'USER_AVATAR');
    await waitFor(() => expect(urls.some((u) => u.includes('targetType=USER_AVATAR'))).toBe(true));
  });
});

describe('İtirazlar ve askı önerileri', () => {
  it('itirazı kabul eder (not ile)', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/decide')) return jsonResponse(204);
      return jsonResponse(200, {
        items: [
          {
            id: 9,
            userId: 4,
            targetType: 'USER_AVATAR',
            targetId: 4,
            message: 'Fotoğrafım uygun',
            status: 'OPEN',
            adminNote: null,
            createdAt: '2026-01-01T10:00:00Z',
            decidedAt: null,
          },
        ],
        nextCursor: null,
      });
    });
    renderWithProviders(<AppealsPage />);
    expect(await screen.findByText('Fotoğrafım uygun')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Kabul et' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText(/^Not/), 'inceledim');
    // W1-B (T-013): karar işlem gerekçesi ister (>= 5 karakter); not kullanıcıya giden ayrı alandır
    const confirm = within(dialog).getByRole('button', { name: 'Kabul et' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByLabelText(/^İşlem gerekçesi/), 'İnceleme tamam');
    await userEvent.click(confirm);
    await waitFor(() => {
      const post = calls.find((c) => c.init.method === 'POST');
      expect(post?.url).toContain('/admin/moderation/appeals/9/decide');
      expect(JSON.parse(String(post?.init.body))).toEqual({ accept: true, note: 'inceledim' });
      expect(decodeURIComponent((post?.init.headers as Record<string, string>)['X-Admin-Reason'])).toBe('İnceleme tamam');
    });
  });

  it('askı önerisini kabul etmeden önce onay ister', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/accept')) return jsonResponse(204);
      return jsonResponse(200, {
        items: [{ id: 3, userId: 8, strikeCount: 3, status: 'OPEN', createdAt: '2026-01-01T10:00:00Z' }],
        nextCursor: null,
      });
    });
    renderWithProviders(<SuspendRecommendationsPage />);
    expect(await screen.findByText('3 ihlal')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Askıya al' }));
    expect(calls.some((c) => c.init.method === 'POST')).toBe(false);
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Askıya al' }));
    await waitFor(() =>
      expect(calls.some((c) => c.init.method === 'POST' && c.url.includes('/suspend-recommendations/3/accept'))).toBe(true),
    );
  });
});

describe('Yasaklı görsel özetleri', () => {
  it('geçersiz özeti göndermez, geçerli özeti küçük harfe çevirip ekler', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (init.method === 'POST') return jsonResponse(201, { sha256: 'a'.repeat(64), note: null, createdBy: 1, createdAt: '2026-01-01T10:00:00Z' });
      return jsonResponse(200, { items: [], nextCursor: null });
    });
    renderWithProviders(<BlocklistPage />);
    await screen.findByText('Liste boş');
    const input = screen.getByRole('textbox', { name: /SHA-256 özeti/ });
    await userEvent.type(input, 'zzz');
    await userEvent.click(screen.getByRole('button', { name: 'Listeye ekle' }));
    expect(await screen.findByText('Özet 64 onaltılık karakterden oluşmalıdır.')).toBeInTheDocument();
    expect(calls.some((c) => c.init.method === 'POST')).toBe(false);

    await userEvent.clear(input);
    await userEvent.type(input, 'A'.repeat(64));
    await userEvent.click(screen.getByRole('button', { name: 'Listeye ekle' }));
    await waitFor(() => {
      const post = calls.find((c) => c.init.method === 'POST');
      expect(JSON.parse(String(post?.init.body))).toEqual({ sha256: 'a'.repeat(64) });
    });
  });
});

describe('Etkinlik başvuru özeti ve kulüp denetimi', () => {
  it('etkinlik özetini kimlikle ister ve sayıları gösterir', async () => {
    const urls: string[] = [];
    mockFetch((url) => {
      urls.push(url);
      return jsonResponse(200, {
        eventId: 7,
        mode: 'APPROVAL',
        capacity: 30,
        goingCount: 12,
        pending: 4,
        accepted: 12,
        waitlisted: 2,
        rejected: 1,
        cancelled: 0,
      });
    });
    renderWithProviders(<EventApplicationsPage />, { route: '/admin/events/applications?eventId=7' });
    expect(await screen.findByText('Etkinlik #7 özeti')).toBeInTheDocument();
    expect(urls[0]).toContain('/events/7/applications/summary');
    expect(screen.getByText('Bekleme listesinde')).toBeInTheDocument();
    expect(screen.getByText(/Başvuru ve onay/)).toBeInTheDocument();
  });

  it('kimlik girilmeden istek atmaz', () => {
    const fn = mockFetch(() => jsonResponse(200, {}));
    renderWithProviders(<EventApplicationsPage />);
    expect(screen.getByText('Bir etkinlik kimliği girin')).toBeInTheDocument();
    expect(fn).not.toHaveBeenCalled();
  });

  it('kulüp denetim kayıtlarını çevrilmiş işlem adıyla listeler', async () => {
    mockFetch(() =>
      jsonResponse(200, {
        items: [
          {
            id: 1,
            action: 'PERMISSIONS_SET',
            actorId: 2,
            actorName: 'Ayşe',
            targetUserId: 3,
            targetName: 'Mehmet',
            detail: 'grants=APPROVE_MEMBERS',
            createdAt: '2026-01-01T10:00:00Z',
          },
        ],
        nextCursor: null,
      }),
    );
    renderWithProviders(<ClubAuditPage />, { route: '/admin/communities/audit?communityId=5' });
    expect(await screen.findByText('Yetkiler değiştirildi')).toBeInTheDocument();
    expect(screen.getByText('İşlemi yapan: Ayşe')).toBeInTheDocument();
    expect(screen.getByText('Hedef: Mehmet')).toBeInTheDocument();
  });
});

describe('Ayarlar: etkinlikler grubu', () => {
  it('onay anahtarını kaydeder, geçersiz sınırı engeller', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (init.method === 'PUT') return jsonResponse(204);
      return jsonResponse(200, {
        events_require_approval: 'false',
        event_max_open_per_user: '5',
        event_daily_create_limit: '5',
        maintenance_mode: 'false',
      });
    });
    renderWithProviders(<SettingsPage />);
    await userEvent.click(await screen.findByRole('tab', { name: /Etkinlikler/ }));
    await userEvent.click(await screen.findByRole('switch'));
    await userEvent.click(screen.getByTestId('save-events_require_approval'));
    await userEvent.type(await screen.findByLabelText(/^Sebep/), 'Onay akışı açıldı');
    await userEvent.click(screen.getByRole('button', { name: 'Değişikliği kaydet' }));
    await waitFor(() => {
      const put = calls.find((c) => c.init.method === 'PUT');
      expect(put?.url).toContain('/admin/settings/events_require_approval');
      expect(JSON.parse(String(put?.init.body))).toEqual({ value: 'true' });
    });

    const limit = screen.getByRole('textbox', { name: /Kullanıcı başına en çok açık etkinlik/ });
    await userEvent.clear(limit);
    await userEvent.type(limit, '5000');
    expect(await screen.findByText(/0 ile 1000 arasında/)).toBeInTheDocument();
    expect(screen.getByTestId('save-event_max_open_per_user')).toBeDisabled();
  });
});

describe('Çeviriler: şifreleme ifadesi', () => {
  it('hiçbir dilde "uçtan uca" / "end-to-end" ifadesi geçmez', () => {
    const banned = [/uçtan uca/i, /end[- ]to[- ]end/i, /من طرف إلى طرف/];
    for (const lang of ['tr', 'en', 'ar'] as const) {
      for (const [key, value] of Object.entries(dictionaries[lang])) {
        for (const re of banned) expect(value, `${lang}:${key}`).not.toMatch(re);
      }
    }
  });
});
