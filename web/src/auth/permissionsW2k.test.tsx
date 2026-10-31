/**
 * W2-K / T-156: izin yüklenirken sayfa çizilmez (403 gürültüsü yok), yetkisiz bölümler gizlenir, 403 anlaşılır anlatılır.
 */
import { screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { RbacMe } from '../api/rbac';
import { AuditTrail } from '../components/admin/guard/AuditTrail';
import { ReportContextCard } from '../pages/admin/chat/ReportContext';
import { UserDeepTabs } from '../pages/admin/users/UserDeepTabs';
import type { AdminUserDetail } from '../api/types';
import { jsonResponse, mockFetch } from '../test/fetchMock';
import { renderWithProviders } from '../test/utils';
import { RequirePerm } from './permissions';

afterEach(() => vi.unstubAllGlobals());

const me = (profile: RbacMe['profile'], permissions: string[]): RbacMe => ({
  userId: 9,
  email: 'x@bingol.edu.tr',
  displayName: 'X',
  profile,
  pinned: false,
  permissions,
});
const SUPPORT = me('SUPPORT', ['dashboard.read', 'users.read', 'support.read', 'support.write', 'comms.single']);
const VIEWER = me('VIEWER', ['dashboard.read', 'users.read', 'moderation.read', 'audit.read']);

/** rbac/me yanıtını elle serbest bırakılabilir bir söz ile geciktirir. */
function serveDeferred(profile: RbacMe) {
  let release!: () => void;
  const gate = new Promise<void>((r) => (release = r));
  const other: string[] = [];
  const fn = mockFetch(async (url) => {
    if (url.endsWith('/admin/rbac/me')) {
      await gate;
      return jsonResponse(200, profile);
    }
    other.push(url);
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return { fn, release, other };
}

function serve(profile: RbacMe, extra?: (url: string) => Response | undefined) {
  return mockFetch((url) => {
    if (url.endsWith('/admin/rbac/me')) return jsonResponse(200, profile);
    return extra?.(url) ?? jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
}

describe('RequirePerm yüklenirken (A3-06)', () => {
  it('izin bilgisi gelene dek çocuğu çizmez (sayfa istek atmaz), gelince çizer', async () => {
    const { release } = serveDeferred(SUPPORT);
    let rendered = 0;
    function Child() {
      rendered += 1;
      return <p>SAYFA</p>;
    }
    renderWithProviders(
      <RequirePerm perm="support.read">
        <Child />
      </RequirePerm>,
    );
    expect(screen.getByTestId('perm-loading')).toBeInTheDocument();
    expect(rendered).toBe(0);
    release();
    expect(await screen.findByText('SAYFA')).toBeInTheDocument();
    expect(screen.queryByTestId('perm-loading')).toBeNull();
  });

  it('yetkisiz profilde çocuk HİÇ çizilmez (izin yüklenirken de, sonra da)', async () => {
    const { release } = serveDeferred(SUPPORT);
    let rendered = 0;
    function Child() {
      rendered += 1;
      return <p>SİSTEM</p>;
    }
    renderWithProviders(
      <RequirePerm perm="system.read">
        <Child />
      </RequirePerm>,
    );
    release();
    expect(await screen.findByTestId('no-permission')).toBeInTheDocument();
    expect(rendered).toBe(0);
  });

  it('izin ucu 404 verirse (alınamadı) bekletmeden arayüzü serbest bırakır', async () => {
    mockFetch(() => jsonResponse(404, { code: 'NOT_FOUND', message: 'x' }));
    renderWithProviders(
      <RequirePerm perm="support.read">
        <p>SERBEST</p>
      </RequirePerm>,
    );
    expect(await screen.findByText('SERBEST')).toBeInTheDocument();
  });

  it('perm verilmezse beklemez', () => {
    mockFetch(() => jsonResponse(404, {}));
    renderWithProviders(
      <RequirePerm perm={undefined}>
        <p>AÇIK</p>
      </RequirePerm>,
    );
    expect(screen.getByText('AÇIK')).toBeInTheDocument();
  });
});

describe('AuditTrail izni (A3-04)', () => {
  it('audit.read yoksa bölüm gösterilmez ve /admin/audit çağrılmaz', async () => {
    const fn = serve(SUPPORT);
    renderWithProviders(<AuditTrail targetType="USER" targetId={5} />);
    await waitFor(() => expect(fn.mock.calls.some(([u]) => String(u).endsWith('/admin/rbac/me'))).toBe(true));
    await waitFor(() => expect(screen.queryByLabelText('Denetim kaydı')).toBeNull());
    expect(fn.mock.calls.some(([u]) => String(u).includes('/admin/audit'))).toBe(false);
  });

  it('audit.read varsa listeyi yükler; 403 gelirse "bağlantı" değil yetki mesajı gösterir', async () => {
    serve(VIEWER, (url) =>
      url.includes('/admin/audit')
        ? jsonResponse(403, { code: 'ADMIN_PERMISSION_DENIED', message: 'x' })
        : undefined,
    );
    renderWithProviders(<AuditTrail targetType="USER" targetId={5} />);
    expect(await screen.findByText(/yetkiniz yok/i)).toBeInTheDocument();
    expect(screen.queryByText(/Bağlantınızı kontrol/)).toBeNull();
  });
});

const USER: AdminUserDetail = {
  id: 7,
  email: 'demo.007@bingol.edu.tr',
  displayName: 'Demo Yedi',
  faculty: null,
  department: null,
  classYear: null,
  language: 'tr',
  role: 'USER',
  status: 'ACTIVE',
  emailVerified: true,
  createdAt: '2026-10-01T10:00:00Z',
  lastSeenAt: null,
  avatarUrl: null,
  bio: null,
  suspendedReason: null,
  deletedAt: null,
  deviceCount: 0,
  platforms: [],
  counts: { feedback: 0, tickets: 0, reportsAgainst: 0, reportsFiled: 0, conversations: 0, communities: 0, eventsCreated: 0, bookmarks: 0 },
  consents: [],
  recentActivity: [],
};

describe('Kullanıcı derin sekmeleri izne göre (A3-04)', () => {
  it('users.pii/users.export yoksa oturum, cihaz ve dışa aktarma sekmeleri gizlenir', async () => {
    serve(SUPPORT);
    renderWithProviders(<UserDeepTabs user={USER} />);
    await waitFor(() => expect(screen.queryByRole('tab', { name: 'Oturumlar' })).toBeNull());
    expect(screen.getByRole('tab', { name: 'Profil müdahalesi' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Bildirimler' })).toBeInTheDocument();
    expect(screen.queryByRole('tab', { name: 'Cihazlar' })).toBeNull();
    expect(screen.queryByRole('tab', { name: /Veri dışa aktarma/ })).toBeNull();
  });

  it('tam izinli profilde tüm sekmeler görünür', async () => {
    serve(me('FULL', ['users.read', 'users.pii', 'users.write', 'users.export', 'audit.read']));
    renderWithProviders(<UserDeepTabs user={USER} />);
    expect(await screen.findByRole('tab', { name: 'Oturumlar' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Cihazlar' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: /Veri dışa aktarma/ })).toBeInTheDocument();
  });
});

describe('Şikâyet bağlamı izne göre (A3-05)', () => {
  it('chat.read yoksa ayrıntı ucu hiç çağrılmaz, bilgi notu görünür', async () => {
    const fn = serve(VIEWER);
    renderWithProviders(<ReportContextCard reportId={3} targetType="MESSAGE" />);
    expect(await screen.findByTestId('report-ctx-hidden')).toBeInTheDocument();
    expect(fn.mock.calls.some(([u]) => /\/admin\/reports\/3(\?|$)/.test(String(u)))).toBe(false);
  });
});
