import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../../auth/AuthProvider';
import { setTokens } from '../../auth/tokens';
import { dictionaries } from '../../i18n/all';
import { AppRoutes } from '../../routes';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import AccessBansPage from './AccessBansPage';
import { UserDevices } from './accessbans/UserDevices';

afterEach(() => vi.unstubAllGlobals());

// Sunucu BanView şekli
const ban = (over: Record<string, unknown>) => ({
  id: 1,
  kind: 'IP',
  value: '203.0.113.7',
  valueShort: '203.0.113.7',
  note: 'spam dalgası',
  reasonCode: 'SPAM',
  createdBy: 1,
  createdAt: '2026-10-01T10:00:00Z',
  expiresAt: null,
  active: true,
  effective: true,
  hitCount: 5,
  lastHitAt: '2026-10-02T10:00:00Z',
  ...over,
});

const BANS = [
  ban({}),
  ban({ id: 2, kind: 'DEVICE', value: 'abcdefghijklmnopqrstuvwxyz0123456789', valueShort: 'abcdefgh…6789', note: null, hitCount: 0, lastHitAt: null }),
  ban({ id: 3, kind: 'CIDR', value: '10.0.0.0/8', valueShort: '10.0.0.0/8', active: false }),
];

interface Call {
  url: string;
  init: RequestInit;
}

function setup(extra: (url: string, init: RequestInit) => Response | undefined = () => undefined) {
  const calls: Call[] = [];
  const fn = mockFetch((url, init) => {
    calls.push({ url, init });
    const o = extra(url, init);
    if (o) return o;
    if (url.includes('/admin/access-bans/stats'))
      return jsonResponse(200, { activeBans: { IP: 4, CIDR: 2, DEVICE: 7, USER: 1 }, anonymizerRanges: 5, anonymizersEnforced: true, blockedAttemptsLast24h: 33, topBans: [] });
    if (url.includes('/access-bans/anonymizers')) {
      if (init.method === 'POST') return jsonResponse(201, { added: 3, duplicates: 0, rejected: [] });
      return jsonResponse(200, { enforced: true, total: 1200, bySource: { 'tor-exit': 1200 }, items: [], nextCursor: null });
    }
    if (url.includes('/access-bans/1/attempts'))
      return jsonResponse(200, { items: [{ id: 1, kind: 'IP', at: '2026-10-02T10:00:00Z', ip: '203.0.113.7', path: '/api/auth/login' }], nextCursor: null });
    if (url.includes('/access-bans/bulk'))
      return jsonResponse(201, { created: 2, alreadyBanned: 1, closedSessions: 0, rejected: [{ line: 4, value: '999.1.1.1', error: 'BAN_INVALID_VALUE' }] });
    if (url.includes('/admin/access-bans') && (init.method ?? 'GET') === 'GET')
      return jsonResponse(200, { items: BANS, nextCursor: null });
    if (url.includes('/admin/access-bans') && init.method === 'POST') return jsonResponse(201, BANS[0]);
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return { calls, fn };
}

/** W1-B (T-013): engel işlemleri gerekçe ister; kutu doldurulmadan "Engelle" düğmesi kapalıdır. */
async function typeWhy(scope: HTMLElement | typeof screen = screen, text = 'Test gerekçesi') {
  const q = scope === screen ? screen : within(scope as HTMLElement);
  await userEvent.type(q.getByLabelText(/^İşlem gerekçesi/), text);
}

describe('Erişim engelleri sayfası', () => {
  it('istatistik kartlarını ve engel tablosunu gösterir', async () => {
    setup();
    renderWithProviders(<AccessBansPage />);
    expect(await screen.findByText('203.0.113.7')).toBeInTheDocument();
    expect(await screen.findByText('33')).toBeInTheDocument();
    expect(screen.getByText('Aktif cihaz engeli')).toBeInTheDocument();
    // cihaz kimliği kısaltılır
    expect(screen.getByText('abcdefgh…6789')).toBeInTheDocument();
    expect(screen.getAllByText('spam dalgası').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Pasif').length).toBeGreaterThan(0);
  });

  it('tür süzgeci sorguya yansır', async () => {
    const { calls } = setup();
    renderWithProviders(<AccessBansPage />);
    await screen.findByText('203.0.113.7');
    await userEvent.selectOptions(screen.getByLabelText('Tür'), 'DEVICE');
    await waitFor(() => expect(calls.some((c) => c.url.includes('/admin/access-bans?') && c.url.includes('kind=DEVICE'))).toBe(true));
  });

  it('boş durum gösterir', async () => {
    setup((url, init) =>
      url.includes('/admin/access-bans?') && (init.method ?? 'GET') === 'GET'
        ? jsonResponse(200, { items: [], nextCursor: null })
        : undefined,
    );
    renderWithProviders(<AccessBansPage />);
    expect(await screen.findByText('Engel yok')).toBeInTheDocument();
  });

  it('hata durumunda yeniden dene sunar', async () => {
    setup((url) => (url.includes('/admin/access-bans?') ? jsonResponse(500, { code: 'X', message: 'x' }) : undefined));
    renderWithProviders(<AccessBansPage />);
    expect(await screen.findByRole('button', { name: dictionaries.tr['common.retry'] })).toBeInTheDocument();
  });

  it('pasife alma PATCH gönderir', async () => {
    const { calls } = setup((_url, init) =>
      init.method === 'PATCH' ? jsonResponse(200, ban({ active: false })) : undefined,
    );
    renderWithProviders(<AccessBansPage />);
    await screen.findByText('203.0.113.7');
    await userEvent.click(screen.getAllByRole('button', { name: 'Pasife al' })[0]);
    await waitFor(() => {
      const c = calls.find((x) => x.init.method === 'PATCH');
      expect(c?.url).toMatch(/access-bans\/1$/);
      expect(JSON.parse(String(c?.init.body))).toEqual({ active: false });
    });
  });

  it('kaldırma onaydan sonra DELETE gönderir', async () => {
    const { calls } = setup((_url, init) => (init.method === 'DELETE' ? jsonResponse(204) : undefined));
    renderWithProviders(<AccessBansPage />);
    await screen.findByText('203.0.113.7');
    await userEvent.click(screen.getAllByRole('button', { name: 'Kaldır' })[0]);
    const dlg = await screen.findByRole('dialog');
    expect(calls.some((c) => c.init.method === 'DELETE')).toBe(false);
    await userEvent.click(within(dlg).getByRole('button', { name: 'Kaldır' }));
    await waitFor(() => expect(calls.some((c) => c.init.method === 'DELETE' && /access-bans\/1$/.test(c.url))).toBe(true));
  });

  it('denemeler yan paneli listeyi gösterir', async () => {
    setup();
    renderWithProviders(<AccessBansPage />);
    await screen.findByText('203.0.113.7');
    await userEvent.click(screen.getAllByRole('button', { name: 'Denemeler' })[0]);
    const dlg = await screen.findByRole('dialog');
    expect(await within(dlg).findByText('/api/auth/login')).toBeInTheDocument();
  });

  describe('engel ekleme diyaloğu', () => {
    async function open() {
      const s = setup();
      renderWithProviders(<AccessBansPage />);
      await screen.findByText('203.0.113.7');
      await userEvent.click(screen.getByRole('button', { name: 'Engel ekle' }));
      return { ...s, dlg: await screen.findByRole('dialog') };
    }

    it('geçersiz IP gönderilmez, hata gösterilir', async () => {
      const { dlg, calls } = await open();
      await userEvent.type(within(dlg).getByLabelText(/Değer/), '999.1.1.1');
      await typeWhy(dlg);
      await userEvent.click(within(dlg).getByRole('button', { name: 'Engelle' }));
      expect(await within(dlg).findByText('Geçerli bir IPv4 veya IPv6 adresi girin.')).toBeInTheDocument();
      expect(calls.some((c) => c.init.method === 'POST')).toBe(false);
    });

    it('CIDR türünde yalın IP reddedilir, geçerli CIDR gönderilir', async () => {
      const { dlg, calls } = await open();
      await userEvent.selectOptions(within(dlg).getByLabelText('Engel türü'), 'CIDR');
      await userEvent.type(within(dlg).getByLabelText(/Değer/), '1.2.3.4');
      await typeWhy(dlg);
      await userEvent.click(within(dlg).getByRole('button', { name: 'Engelle' }));
      expect(await within(dlg).findByText(/Geçerli bir CIDR/)).toBeInTheDocument();
      await userEvent.clear(within(dlg).getByLabelText(/Değer/));
      await userEvent.type(within(dlg).getByLabelText(/Değer/), '10.1.0.0/16');
      await userEvent.click(within(dlg).getByRole('button', { name: 'Engelle' }));
      await waitFor(() => {
        const c = calls.find((x) => x.init.method === 'POST');
        expect(JSON.parse(String(c?.init.body))).toMatchObject({ kind: 'CIDR', value: '10.1.0.0/16', reasonCode: 'ABUSE', expiresAt: null });
      });
    });

    it('cihaz kimliği 8 karakterden kısa olamaz', async () => {
      const { dlg } = await open();
      await userEvent.selectOptions(within(dlg).getByLabelText('Engel türü'), 'DEVICE');
      await userEvent.type(within(dlg).getByLabelText(/Değer/), 'kisa');
      await typeWhy(dlg);
      await userEvent.click(within(dlg).getByRole('button', { name: 'Engelle' }));
      expect(await within(dlg).findByText(/8–128 karakter/, { selector: 'p[role="alert"]' })).toBeInTheDocument();
    });

    it('kullanıcı türünde arama ve seçim; IP kutusu uyarı gösterir', async () => {
      const { dlg, calls } = await open();
      await userEvent.selectOptions(within(dlg).getByLabelText('Engel türü'), 'USER');
      expect(within(dlg).queryByLabelText(/^Değer/)).toBeNull();
      await userEvent.type(within(dlg).getByLabelText('Kullanıcı ara'), 'ayşe');
      // /admin/users isteği 404 döner (setup'ta tanımsız) -> yeniden tanımlamak yerine yalnız kutuları sınarız
      await userEvent.click(within(dlg).getByLabelText('Son 30 gündeki IP adreslerini de engelle'));
      expect(within(dlg).getByRole('note')).toHaveTextContent('Paylaşılan ağlarda');
      await typeWhy(dlg);
      await userEvent.click(within(dlg).getByRole('button', { name: 'Engelle' }));
      expect(await within(dlg).findByText('Bir kullanıcı seçin.')).toBeInTheDocument();
      expect(calls.some((c) => c.init.method === 'POST')).toBe(false);
    });

    it('BAN_SELF_LOCKOUT onay ister ve force=true ile yeniden dener', async () => {
      let n = 0;
      const { calls } = setup((url, init) => {
        if (url.endsWith('/admin/access-bans') && init.method === 'POST') {
          n += 1;
          return n === 1
            ? jsonResponse(409, { code: 'BAN_SELF_LOCKOUT', message: 'x' })
            : jsonResponse(201, BANS[0]);
        }
        return undefined;
      });
      renderWithProviders(<AccessBansPage />);
      await screen.findByText('203.0.113.7');
      await userEvent.click(screen.getByRole('button', { name: 'Engel ekle' }));
      const dlg = await screen.findByRole('dialog');
      await userEvent.type(within(dlg).getByLabelText(/Değer/), '198.51.100.9');
      await typeWhy(dlg);
      await userEvent.click(within(dlg).getByRole('button', { name: 'Engelle' }));
      const confirm = await screen.findByRole('dialog', { name: 'Bu sizin IP adresiniz' });
      await userEvent.click(within(confirm).getByRole('button', { name: 'Yine de engelle' }));
      await waitFor(() => {
        const posts = calls.filter((c) => c.init.method === 'POST' && c.url.endsWith('/admin/access-bans'));
        expect(posts).toHaveLength(2);
        expect(JSON.parse(String(posts[0].init.body)).force).toBeUndefined();
        expect(JSON.parse(String(posts[1].init.body)).force).toBe(true);
        // yeniden denemede de aynı gerekçe başlığı gider
        for (const p of posts) {
          expect(decodeURIComponent((p.init.headers as Record<string, string>)['X-Admin-Reason'])).toBe('Test gerekçesi');
        }
      });
    });

    it('gerekçe (>= 5 karakter) yazılmadan Engelle düğmesi kapalıdır ve istek gitmez', async () => {
      const { dlg, calls } = await open();
      await userEvent.type(within(dlg).getByLabelText(/Değer/), '198.51.100.9');
      const btn = within(dlg).getByRole('button', { name: 'Engelle' });
      expect(btn).toBeDisabled();
      await typeWhy(dlg, 'abcd');
      expect(btn).toBeDisabled();
      await typeWhy(dlg, 'e');
      expect(btn).toBeEnabled();
      expect(calls.some((c) => c.init.method === 'POST')).toBe(false);
    });
  });

  it('toplu ekleme: satır sayacı ve sonuç raporu', async () => {
    const { calls } = setup();
    renderWithProviders(<AccessBansPage />);
    await screen.findByText('203.0.113.7');
    await userEvent.click(screen.getByRole('tab', { name: 'Toplu IP/CIDR ekle' }));
    const area = screen.getByLabelText('IP/CIDR listesi');
    await userEvent.click(area);
    await userEvent.paste('1.1.1.1\n# yorum\n10.0.0.0/8\n999.1.1.1');
    expect(screen.getByText(/3 satır/)).toHaveTextContent('1 satır geçersiz görünüyor.');
    expect(screen.getByRole('button', { name: 'Listeyi ekle' })).toBeDisabled(); // gerekçe yok
    await typeWhy();
    await userEvent.click(screen.getByRole('button', { name: 'Listeyi ekle' }));
    expect(await screen.findByText('Eklenen: 2', { exact: false })).toBeInTheDocument();
    expect(screen.getByText('Atlanan: 1', { exact: false })).toBeInTheDocument();
    expect(screen.getByText('999.1.1.1', { selector: 'code' })).toBeInTheDocument();
    const post = calls.find((c) => c.url.includes('/bulk'));
    expect(JSON.parse(String(post?.init.body)).text).toBe('1.1.1.1\n10.0.0.0/8\n999.1.1.1');
  });

  it('VPN/Tor sekmesi: bilgi, ayar durumu, liste ve kaynak zorunluluğu', { timeout: 20000 }, async () => {
    const { calls } = setup();
    renderWithProviders(<AccessBansPage />);
    await userEvent.click(await screen.findByRole('tab', { name: 'VPN/Tor listeleri' }));
    expect(screen.getByText(/VPN'i tam engellemek mümkün değildir/)).toBeInTheDocument();
    expect(await screen.findByText('tor-exit')).toBeInTheDocument();
    expect(screen.getByText('Açık')).toBeInTheDocument();
    await userEvent.click(screen.getByLabelText('CIDR listesi (satır satır)'));
    await userEvent.paste('192.0.2.0/24');
    await userEvent.click(screen.getByRole('button', { name: 'Yükle' }));
    expect(await screen.findByText('Kaynak etiketi gerekli.')).toBeInTheDocument();
    expect(calls.some((c) => c.init.method === 'POST')).toBe(false);
    await userEvent.type(screen.getByLabelText(/Kaynak etiketi/), 'tor-2026');
    await userEvent.click(screen.getByRole('button', { name: 'Yükle' }));
    await waitFor(() => {
      const c = calls.find((x) => x.init.method === 'POST');
      expect(JSON.parse(String(c?.init.body))).toEqual({ text: '192.0.2.0/24', source: 'tor-2026' });
    });
  });
});

describe('Kullanıcı cihazları bölümü', () => {
  const DEVICES_LIST = [
    {
      deviceHash: 'a1b2c3d4' + 'f'.repeat(56),
      deviceShort: 'a1b2c3d4',
      platform: 'ANDROID',
      appVersion: '1.4.0',
      firstSeenAt: '2026-09-01T10:00:00Z',
      lastSeenAt: '2026-10-20T10:00:00Z',
      ips: [{ ip: '198.51.100.20', family: 4, firstSeenAt: '2026-09-01T10:00:00Z', lastSeenAt: '2026-10-20T10:00:00Z', seenCount: 3, blocked: false }],
      blocked: false,
      sharedWithUsers: [{ id: 42, displayName: 'Zeynep Kaya' }],
    },
    {
      deviceHash: 'ffeeddcc' + '0'.repeat(56),
      deviceShort: 'ffeeddcc',
      platform: 'IOS',
      appVersion: '1.3.0',
      firstSeenAt: '2026-08-01T10:00:00Z',
      lastSeenAt: '2026-08-02T10:00:00Z',
      ips: [],
      blocked: true,
      sharedWithUsers: [],
    },
  ];
  const DEVICES = { userId: 7, devices: DEVICES_LIST, unidentifiedIps: [{ ip: '192.0.2.99', family: 4, firstSeenAt: '2026-10-01T10:00:00Z', lastSeenAt: '2026-10-02T10:00:00Z', seenCount: 1, blocked: false }] };

  it('cihazları, engelli rozetini ve paylaşım uyarısını gösterir', async () => {
    mockFetch((url) => (url.includes('/users/7/devices') ? jsonResponse(200, DEVICES) : jsonResponse(404, { code: 'N', message: 'x' })));
    renderWithProviders(<UserDevices userId={7} />);
    expect(await screen.findByText('a1b2c3d4')).toBeInTheDocument();
    expect(screen.getByText('198.51.100.20')).toBeInTheDocument();
    expect(screen.getByText('192.0.2.99')).toBeInTheDocument();
    expect(screen.getByText('Engelli')).toBeInTheDocument();
    expect(screen.getByText(/Bu cihazı başka hesaplar da kullanıyor: 1 hesap/)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Zeynep Kaya' }).getAttribute('href')).toBe('/admin/users/42');
    // yalnız engelli olmayan cihaz için "Cihazı engelle" düğmesi
    expect(screen.getAllByRole('button', { name: 'Cihazı engelle' })).toHaveLength(1);
  });

  it('kullanıcıyı + cihazlarını engelle: block-access gövdesi', async () => {
    const calls: Call[] = [];
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (url.includes('/block-access')) return jsonResponse(204);
      return jsonResponse(200, DEVICES);
    });
    renderWithProviders(<UserDevices userId={7} />);
    await screen.findByText('a1b2c3d4');
    await userEvent.click(screen.getByRole('button', { name: 'Kullanıcıyı + cihazlarını engelle' }));
    const dlg = await screen.findByRole('dialog');
    await userEvent.click(within(dlg).getByLabelText('Son IP adreslerini de engelle'));
    await typeWhy(dlg);
    await userEvent.click(within(dlg).getByRole('button', { name: 'Engelle' }));
    await waitFor(() => {
      const c = calls.find((x) => x.url.includes('/block-access'));
      expect(decodeURIComponent((c?.init.headers as Record<string, string>)['X-Admin-Reason'])).toBe('Test gerekçesi');
      expect(c?.url).toMatch(/\/admin\/users\/7\/block-access$/);
      expect(JSON.parse(String(c?.init.body))).toEqual({ devices: true, ips: true, userBan: true, reasonCode: 'ABUSE' });
    });
  });

  it('IP engelle: self-lockout onayı sonrası force ile tekrar', async () => {
    const calls: Call[] = [];
    let n = 0;
    mockFetch((url, init) => {
      calls.push({ url, init });
      if (init.method === 'POST') {
        n += 1;
        return n === 1 ? jsonResponse(409, { code: 'BAN_SELF_LOCKOUT', message: 'x' }) : jsonResponse(201, {});
      }
      return jsonResponse(200, DEVICES);
    });
    renderWithProviders(<UserDevices userId={7} />);
    await screen.findByText('198.51.100.20');
    await userEvent.click(screen.getAllByRole('button', { name: "IP'yi engelle" })[0]);
    const dlg = await screen.findByRole('dialog');
    await typeWhy(dlg);
    await userEvent.click(within(dlg).getByRole('button', { name: 'Engelle' }));
    const confirm = await screen.findByRole('dialog', { name: 'Bu sizin IP adresiniz' });
    await userEvent.click(within(confirm).getByRole('button', { name: 'Yine de engelle' }));
    await waitFor(() => {
      const posts = calls.filter((c) => c.init.method === 'POST');
      expect(posts).toHaveLength(2);
      expect(JSON.parse(String(posts[1].init.body))).toMatchObject({ kind: 'IP', value: '198.51.100.20', force: true });
    });
  });
});

describe('sayfa erişimi', () => {
  const adminMe = { id: 1, email: 'a@bingol.edu.tr', displayName: 'Yönetici', role: 'ADMIN' };

  it('ADMIN olmayan kullanıcı sayfayı göremez', async () => {
    setTokens('a', 'r');
    mockFetch((url) => (url.endsWith('/admin/me') ? jsonResponse(200, { ...adminMe, role: 'USER' }) : jsonResponse(404, { code: 'N', message: 'x' })));
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/admin/security/access-bans' },
    );
    expect(await screen.findByRole('alert')).toHaveTextContent('Bu alana erişim yetkiniz yok');
    expect(screen.queryByText('Engel ekle')).toBeNull();
  });

  it('ADMIN için sayfa açılır ve menüde bağlantı vardır', async () => {
    setTokens('a', 'r');
    setup((url) => (url.endsWith('/admin/me') ? jsonResponse(200, adminMe) : undefined));
    renderWithProviders(
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>,
      { route: '/admin/security/access-bans' },
    );
    expect(await screen.findByRole('heading', { level: 1, name: 'Erişim engelleri' })).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: 'Erişim engelleri' }).length).toBeGreaterThan(0);
  });
});
