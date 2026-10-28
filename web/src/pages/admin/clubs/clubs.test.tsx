import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import ClubsManagePage from '../ClubsManagePage';
import ContentReviewPage from '../ContentReviewPage';
import {
  canChangeRole,
  canRemoveMember,
  csvFilename,
  diffToUpdate,
  excerpt,
  formFrom,
  isDirty,
  nameError,
} from './clubsLogic';

// ---- örnek veri ----
const club = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  name: `Kulup ${id}`,
  slug: `kulup-${id}`,
  category: 'Spor',
  status: 'ACTIVE',
  visibility: 'PUBLIC',
  joinPolicy: 'OPEN',
  ownerId: 7,
  ownerName: 'Sahip Kisi',
  ownerEmail: 'sahip@bingol.edu.tr',
  coverUrl: null,
  logoUrl: null,
  memberCount: 12,
  pendingCount: 0,
  openReportCount: 0,
  eventCount: 2,
  createdAt: '2026-09-01T10:00:00Z',
  updatedAt: '2026-09-02T10:00:00Z',
  ...over,
});
const detail = (id: number, over: Record<string, unknown> = {}, clubOver: Record<string, unknown> = {}) => ({
  club: club(id, clubOver),
  description: 'Aciklama metni',
  reviewNote: null,
  staff: [{ userId: 7, displayName: 'Sahip Kisi', email: 'sahip@bingol.edu.tr', role: 'OWNER' }],
  bannedCount: 0,
  statusHistory: [],
  openReports: [],
  recentAudit: [],
  capabilities: { canEdit: true, canClose: true, canReopen: false, canDelete: true, canTransfer: true, canApprove: false },
  ...over,
});
const member = (userId: number, role: string, over: Record<string, unknown> = {}) => ({
  userId,
  displayName: `Uye ${userId}`,
  email: `uye${userId}@bingol.edu.tr`,
  avatarUrl: null,
  role,
  status: 'ACTIVE',
  accountStatus: 'ACTIVE',
  joinedAt: '2026-09-03T10:00:00Z',
  customPermissions: false,
  ...over,
});
const page = <T,>(items: T[], over: Record<string, unknown> = {}) => ({
  items,
  page: 0,
  size: 20,
  total: items.length,
  totalPages: 1,
  ...over,
});
const post = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  communityId: 5,
  communityName: 'Kulup 5',
  kind: 'POST',
  state: 'VISIBLE',
  author: { id: 9, displayName: 'Yazar Kisi', email: 'yazar@bingol.edu.tr', avatarUrl: null },
  text: `icerik-${id}`,
  imageUrl: null,
  pinned: false,
  openReportCount: 0,
  hiddenReason: null,
  hiddenBy: null,
  hiddenAt: null,
  editedAt: null,
  createdAt: '2026-10-01T10:00:00Z',
  ...over,
});

interface Call {
  method: string;
  url: string;
  body?: unknown;
  headers: Record<string, string>;
}

function setup(opts: { detailOver?: Record<string, unknown>; clubOver?: Record<string, unknown> } = {}) {
  const calls: Call[] = [];
  const f = mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({
      method,
      url,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
      headers: (init.headers ?? {}) as Record<string, string>,
    });
    if (url.startsWith('/api/admin/communities/export.csv')) {
      return new Response(new Blob(['id,ad\r\n1,x']), { status: 200, headers: { 'Content-Type': 'text/csv' } });
    }
    if (url.startsWith('/api/admin/community-categories')) {
      return jsonResponse(200, {
        items: [
          { id: 1, key: 'Spor', nameTr: 'Spor', nameEn: 'Sports', nameAr: 'x', icon: null, sortOrder: 1, active: true, usageCount: 1, createdAt: '', updatedAt: '' },
          { id: 2, key: 'Muzik', nameTr: 'Müzik', nameEn: 'Music', nameAr: 'x', icon: null, sortOrder: 2, active: true, usageCount: 0, createdAt: '', updatedAt: '' },
        ],
        activeCount: 2,
        maxActive: 20,
      });
    }
    if (/\/admin\/communities\/5\/members\/9\/role/.test(url)) return jsonResponse(200, { communityId: 5, userId: 9, result: 'MODERATOR' });
    if (/\/admin\/communities\/5\/members\/9/.test(url) && method === 'DELETE') return jsonResponse(200, { communityId: 5, userId: 9, result: 'REMOVED' });
    if (/\/admin\/communities\/5\/members/.test(url)) {
      return jsonResponse(200, page([member(7, 'OWNER'), member(9, 'MEMBER'), member(11, 'ADMIN')], { total: 3 }));
    }
    if (/\/admin\/communities\/5\/join-requests\/9\/(approve|reject)/.test(url)) return jsonResponse(200, { communityId: 5, userId: 9, result: 'OK' });
    if (/\/admin\/communities\/5\/join-requests/.test(url)) return jsonResponse(200, page([member(9, 'MEMBER', { status: 'PENDING' })]));
    if (/\/admin\/communities\/5\/invites/.test(url)) return jsonResponse(200, []);
    if (/\/admin\/communities\/5\/club-audit/.test(url)) return jsonResponse(200, { items: [], nextCursor: null });
    if (/\/admin\/communities\/5\/close/.test(url)) return jsonResponse(200, { id: 5, status: 'HIDDEN', irreversible: false, notified: 12 });
    if (/\/admin\/communities\/5\/transfer-ownership/.test(url)) return jsonResponse(200, { id: 5, status: 'ACTIVE', irreversible: true, notified: 2 });
    if (/\/admin\/communities\/5$/.test(url) && method === 'DELETE') return jsonResponse(200, { id: 5, status: 'DELETED', irreversible: true, notified: 12 });
    if (/\/admin\/communities\/5$/.test(url) && method === 'PATCH') return jsonResponse(200, detail(5, opts.detailOver, opts.clubOver));
    if (/\/admin\/communities\/5$/.test(url)) return jsonResponse(200, detail(5, opts.detailOver, opts.clubOver));
    if (/\/admin\/communities\?/.test(url) && url.includes('page=')) {
      return jsonResponse(
        200,
        page([club(5, { pendingCount: 2, openReportCount: 3 }), club(6, { status: 'HIDDEN', ownerName: null })], {
          total: 45,
          totalPages: 3,
        }),
      );
    }
    if (/\/admin\/communities\?/.test(url)) return jsonResponse(200, { items: [], nextCursor: null });
    if (/\/admin\/audit/.test(url)) return jsonResponse(200, { items: [] });
    // içerik
    if (/\/admin\/community-posts\/1\/hide/.test(url)) return jsonResponse(200, post(1, { state: 'HIDDEN' }));
    if (/\/admin\/community-posts\/2\/unhide/.test(url)) return jsonResponse(200, post(2));
    if (/\/admin\/community-posts\/1$/.test(url) && method === 'PATCH') return jsonResponse(200, post(1, { text: 'yeni metin' }));
    if (/\/admin\/community-posts\/3$/.test(url) && method === 'DELETE') return jsonResponse(200, { id: 3, state: 'DELETED', irreversible: true });
    if (/\/admin\/community-posts\/1$/.test(url)) {
      return jsonResponse(200, { post: post(1), reports: [{ id: 4, reason: 'SPAM', note: 'reklam', status: 'OPEN', createdAt: '2026-10-02T10:00:00Z' }] });
    }
    if (/\/admin\/community-posts/.test(url)) {
      return jsonResponse(
        200,
        page([
          post(1, { openReportCount: 2 }),
          post(2, { state: 'HIDDEN', hiddenReason: 'spam suphesi', hiddenAt: '2026-10-03T10:00:00Z' }),
          post(3, { kind: 'ANNOUNCEMENT', communityId: 6, communityName: 'Kulup 6' }),
        ]),
      );
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return { calls, f };
}

const writes = (calls: Call[]) => calls.filter((c) => c.method !== 'GET');
const reasonOf = (c: Call) => decodeURIComponent(c.headers['X-Admin-Reason'] ?? '');

beforeEach(() => {
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: () => 'blob:test', revokeObjectURL: () => {} }));
});
afterEach(() => vi.unstubAllGlobals());

// ---- saf mantık ----
describe('clubsLogic', () => {
  const base = { name: 'Satranc', description: 'a', category: 'Spor', joinPolicy: 'OPEN', visibility: 'PUBLIC' } as const;

  it('diffToUpdate yalniz degisen alanlari gonderir; bosluklar yok sayilir', () => {
    expect(diffToUpdate(base, { ...base })).toEqual({});
    expect(diffToUpdate(base, { ...base, name: ' Satranc ' })).toEqual({});
    expect(diffToUpdate(base, { ...base, name: 'Yeni Ad', visibility: 'PRIVATE' })).toEqual({ name: 'Yeni Ad', visibility: 'PRIVATE' });
    expect(diffToUpdate(base, { ...base, description: '' })).toEqual({ description: '' });
    expect(isDirty(base, { ...base, category: 'Muzik' })).toBe(true);
    expect(isDirty(base, { ...base, description: ' a ' })).toBe(false);
  });
  it('formFrom detaydan formu uretir', () => {
    expect(formFrom(detail(5) as never)).toEqual({ name: 'Kulup 5', description: 'Aciklama metni', category: 'Spor', joinPolicy: 'OPEN', visibility: 'PUBLIC' });
  });
  it('nameError sunucu ile ayni sinirlar', () => {
    expect(nameError('ab')).toBe('short');
    expect(nameError('  a  ')).toBe('short');
    expect(nameError('abc')).toBeNull();
    expect(nameError('x'.repeat(81))).toBe('long');
  });
  it('sahip rolu degistirilemez ve cikarilamaz; bekleyen uyenin rolu degismez', () => {
    expect(canChangeRole({ role: 'OWNER', status: 'ACTIVE' })).toBe(false);
    expect(canChangeRole({ role: 'MEMBER', status: 'PENDING' })).toBe(false);
    expect(canChangeRole({ role: 'MODERATOR', status: 'ACTIVE' })).toBe(true);
    expect(canRemoveMember({ role: 'OWNER' })).toBe(false);
    expect(canRemoveMember({ role: 'ADMIN' })).toBe(true);
  });
  it('excerpt ve csvFilename', () => {
    expect(excerpt('a\n  b')).toBe('a b');
    expect(excerpt('x'.repeat(300), 10)).toBe(`${'x'.repeat(10)}…`);
    expect(csvFilename(new Date(2026, 9, 5))).toBe('kulupler-2026-10-05.csv');
  });
});

// ---- liste ----
describe('ClubsManagePage: liste', () => {
  it('kulupleri sayfali listeler, durum suzgeci ve arama istege yansir, sayfa degisir', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    expect(await screen.findByText('Kulup 5')).toBeInTheDocument();
    expect(screen.getByText('Kulup 6')).toBeInTheDocument();
    expect(screen.getByText('45 kulüp')).toBeInTheDocument();
    expect(screen.getByText('2 bekliyor')).toBeInTheDocument();
    const first = calls.find((c) => c.url.startsWith('/api/admin/communities?'))!;
    expect(first.url).toContain('page=0');
    expect(first.url).toContain('sort=createdAt');
    expect(first.url).not.toContain('status=');

    const user = userEvent.setup();
    await user.selectOptions(screen.getByLabelText('Durum'), 'HIDDEN');
    await waitFor(() => expect(calls.some((c) => c.url.includes('status=HIDDEN'))).toBe(true));
    await user.type(screen.getByLabelText('Ara'), 'satranc');
    await waitFor(() => expect(calls.some((c) => c.url.includes('q=satranc'))).toBe(true));
    await user.click(screen.getByLabelText('Yalnız açık şikâyeti olanlar'));
    await waitFor(() => expect(calls.some((c) => c.url.includes('minReports=1'))).toBe(true));

    await user.click(screen.getByRole('button', { name: 'Sonraki sayfa' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('page=1'))).toBe(true));
  });

  it('siralama basligi sort/dir gonderir', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    await screen.findByText('Kulup 5');
    await userEvent.setup().click(screen.getByRole('button', { name: /Üye/ }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('sort=memberCount'))).toBe(true));
  });

  it('CSV indir export.csv ucunu ayni suzgeclerle cagirir ve dosyayi indirir', async () => {
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    await screen.findByText('Kulup 5');
    const user = userEvent.setup();
    await user.selectOptions(screen.getByLabelText('Durum'), 'ACTIVE');
    await user.click(screen.getByRole('button', { name: 'CSV indir' }));
    await waitFor(() => expect(calls.some((c) => c.url.startsWith('/api/admin/communities/export.csv'))).toBe(true));
    expect(calls.find((c) => c.url.startsWith('/api/admin/communities/export.csv'))!.url).toContain('status=ACTIVE');
    await waitFor(() => expect(click).toHaveBeenCalled());
    click.mockRestore();
  });

  it('onay kuyrugu sekmesi eski imecli ucu cagirir', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    await screen.findByText('Kulup 5');
    await userEvent.setup().click(screen.getByRole('tab', { name: 'Onay kuyruğu' }));
    await waitFor(() => expect(calls.some((c) => /communities\?status=PENDING_REVIEW/.test(c.url) && !c.url.includes('page='))).toBe(true));
  });

  it('?club= parametresi cekmeceyi dogrudan acar', async () => {
    setup();
    renderWithProviders(<ClubsManagePage />, { route: '/admin/communities?club=5' });
    expect(await screen.findByRole('tab', { name: 'Tehlikeli bölge' })).toBeInTheDocument();
  });
});

// ---- cekmece ----
async function openDrawer(user: ReturnType<typeof userEvent.setup>) {
  await user.click(await screen.findByText('Kulup 5'));
  await screen.findByRole('tab', { name: 'Üyeler' });
}

describe('ClubDrawer: genel', () => {
  it('formu duzenleyince yalniz degisen alan PATCH ile gider; kirliyken kaydet acilir', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    const user = userEvent.setup();
    await openDrawer(user);
    const save = await screen.findByRole('button', { name: 'Kaydet' });
    expect(save).toBeDisabled();
    const name = screen.getByLabelText('Kulüp adı');
    await user.clear(name);
    await user.type(name, 'Yeni Satranc');
    expect(save).toBeEnabled();
    await user.click(save);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    const w = writes(calls)[0];
    expect(w.method).toBe('PATCH');
    expect(w.url).toBe('/api/admin/communities/5');
    expect(w.body).toEqual({ name: 'Yeni Satranc' });
    expect(w.headers['Idempotency-Key']).toBeTruthy();
  });

  it('kisa ad hata gosterir ve kaydi kapatir; kaydedilmemis degisiklikle sekme degisimi onay ister', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    const user = userEvent.setup();
    await openDrawer(user);
    const name = await screen.findByLabelText('Kulüp adı');
    await user.clear(name);
    await user.type(name, 'ab');
    expect(screen.getByText('Ad en az 3 karakter olmalı.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Kaydet' })).toBeDisabled();

    await user.click(screen.getByRole('tab', { name: 'Üyeler' }));
    // kaydedilmemis degisiklik uyarisi: sekme hala "Genel"
    expect(await screen.findByText(/Kaydedilmemiş/)).toBeInTheDocument();
    expect(screen.queryByTestId('member-list')).not.toBeInTheDocument();
    expect(writes(calls)).toHaveLength(0);
  });
});

describe('ClubDrawer: uyeler', () => {
  it('rol degistirme: sebep zorunlu, PATCH rol + X-Admin-Reason + Idempotency-Key ile gider', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    const user = userEvent.setup();
    await openDrawer(user);
    await user.click(screen.getByRole('tab', { name: 'Üyeler' }));
    const rows = await screen.findAllByTestId('member-row');
    expect(rows).toHaveLength(3);

    // sahip satirinda rol/cikarma yok, uyari var
    expect(within(rows[0]).queryByRole('button', { name: 'Kulüpten çıkar' })).toBeNull();
    expect(within(rows[0]).getByText(/Sahip burada değiştirilemez/)).toBeInTheDocument();

    await user.selectOptions(within(rows[1]).getByLabelText('Uye 9 için yeni rol'), 'MODERATOR');
    await user.click(within(rows[1]).getByRole('button', { name: 'Rolü değiştir' }));
    const dialog = await screen.findByRole('dialog', { name: 'Üye rolü değiştirilsin mi?' });
    expect(dialog).toHaveTextContent('Uye 9');
    const confirm = within(dialog).getByRole('button', { name: 'Rolü değiştir' });
    expect(confirm).toBeDisabled();
    await user.click(confirm);
    expect(writes(calls)).toHaveLength(0);

    await user.type(within(dialog).getByRole('textbox'), 'Etkinlik sorumlusu atandı');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    const w = writes(calls)[0];
    expect(w.method).toBe('PATCH');
    expect(w.url).toBe('/api/admin/communities/5/members/9/role');
    expect(w.body).toEqual({ role: 'MODERATOR' });
    expect(reasonOf(w)).toBe('Etkinlik sorumlusu atandı');
    expect(w.headers['Idempotency-Key']).toBeTruthy();
  });

  it('cikarma: sebep + yasakla secenegi ?ban=true gonderir; cift tiklama tek istek uretir', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    const user = userEvent.setup();
    await openDrawer(user);
    await user.click(screen.getByRole('tab', { name: 'Üyeler' }));
    const rows = await screen.findAllByTestId('member-row');
    await user.click(within(rows[1]).getByRole('button', { name: 'Kulüpten çıkar' }));
    const dialog = await screen.findByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Kulüpten çıkar' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'Kurallara tekrar tekrar aykırı');
    await user.click(within(dialog).getByRole('checkbox', { name: /Yasakla/ }));
    await user.dblClick(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    await new Promise((r) => setTimeout(r, 50));
    expect(writes(calls)).toHaveLength(1);
    expect(writes(calls)[0].method).toBe('DELETE');
    expect(writes(calls)[0].url).toBe('/api/admin/communities/5/members/9?ban=true');
    expect(reasonOf(writes(calls)[0])).toBe('Kurallara tekrar tekrar aykırı');
  });
});

describe('ClubDrawer: basvurular', () => {
  it('bekleyen istek onaylanir; reddetme onay ister', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    const user = userEvent.setup();
    await openDrawer(user);
    await user.click(screen.getByRole('tab', { name: 'Başvurular' }));
    const row = await screen.findByTestId('request-row');
    await user.click(within(row).getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].url).toBe('/api/admin/communities/5/join-requests/9/approve');

    await user.click(within(row).getByRole('button', { name: 'Reddet' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(writes(calls)).toHaveLength(1);
    await user.click(within(dialog).getByRole('button', { name: 'Reddet' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(2));
    expect(writes(calls)[1].url).toBe('/api/admin/communities/5/join-requests/9/reject');
  });
});

describe('ClubDrawer: tehlikeli bolge', () => {
  it('silme: sebep + kulup adini yazma olmadan onay kapali; sonra DELETE sebep basligiyla gider', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    const user = userEvent.setup();
    await openDrawer(user);
    await user.click(screen.getByRole('tab', { name: 'Tehlikeli bölge' }));
    await user.click(await screen.findByRole('button', { name: 'Kulübü sil' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('geri alınamaz');
    const confirm = within(dialog).getByRole('button', { name: 'Kulübü sil' });
    const [reasonBox, nameBox] = within(dialog).getAllByRole('textbox');
    expect(confirm).toBeDisabled();
    await user.type(reasonBox, 'Tekrarlayan kural ihlalleri');
    expect(confirm).toBeDisabled(); // ad henüz yazılmadı
    await user.type(nameBox, 'Yanlis Kulup');
    expect(confirm).toBeDisabled();
    await user.clear(nameBox);
    await user.type(nameBox, 'Kulup 5');
    expect(confirm).toBeEnabled();
    await user.dblClick(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    await new Promise((r) => setTimeout(r, 50));
    expect(writes(calls)).toHaveLength(1);
    const w = writes(calls)[0];
    expect(w.method).toBe('DELETE');
    expect(w.url).toBe('/api/admin/communities/5');
    expect(reasonOf(w)).toBe('Tekrarlayan kural ihlalleri');
    expect(w.headers['Idempotency-Key']).toBeTruthy();
  });

  it('kapatma: sebep zorunlu, POST close sebep basligiyla gider', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    const user = userEvent.setup();
    await openDrawer(user);
    await user.click(screen.getByRole('tab', { name: 'Tehlikeli bölge' }));
    await user.click(await screen.findByRole('button', { name: 'Kulübü kapat' }));
    const dialog = await screen.findByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Kulübü kapat' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'Şikâyetler incelenene kadar');
    await user.click(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].method).toBe('POST');
    expect(writes(calls)[0].url).toBe('/api/admin/communities/5/close');
    expect(reasonOf(writes(calls)[0])).toBe('Şikâyetler incelenene kadar');
  });

  it('devir: uye secilmeden dugme kapali; ad + sebep sonrasi POST govdesi hedef ve keepAsAdmin tasir', async () => {
    const { calls } = setup();
    renderWithProviders(<ClubsManagePage />);
    const user = userEvent.setup();
    await openDrawer(user);
    await user.click(screen.getByRole('tab', { name: 'Tehlikeli bölge' }));
    const open = await screen.findByRole('button', { name: 'Sahipliği devret' });
    expect(open).toBeDisabled();
    const select = screen.getByLabelText('Yeni sahip');
    await waitFor(() => expect(within(select).getAllByRole('option').length).toBeGreaterThan(1));
    // sahip (7) listede yok; yonetici (11) ve uye (9) var
    expect(within(select).queryByText(/Uye 7/)).toBeNull();
    await user.selectOptions(select, '11');
    expect(open).toBeEnabled();
    await user.click(screen.getByLabelText('Eski sahip kulüpte yönetici olarak kalsın'));
    await user.click(open);
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent('geri alınamaz');
    const [reasonBox, nameBox] = within(dialog).getAllByRole('textbox');
    await user.type(reasonBox, 'Sahibe ulaşılamıyor');
    await user.type(nameBox, 'kulup 5');
    await user.click(within(dialog).getByRole('button', { name: 'Sahipliği devret' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    const w = writes(calls)[0];
    expect(w.url).toBe('/api/admin/communities/5/transfer-ownership');
    expect(w.body).toEqual({ targetUserId: 11, keepAsAdmin: false });
    expect(reasonOf(w)).toBe('Sahibe ulaşılamıyor');
  });

  it('silinmis kulupte eylem bolgeleri gosterilmez', async () => {
    setup({
      detailOver: { capabilities: { canEdit: false, canClose: false, canReopen: false, canDelete: false, canTransfer: false, canApprove: false } },
      clubOver: { status: 'DELETED' },
    });
    renderWithProviders(<ClubsManagePage />, { route: '/admin/communities?club=5' });
    await userEvent.setup().click(await screen.findByRole('tab', { name: 'Tehlikeli bölge' }));
    expect(await screen.findByText('Bu kulüp için kullanılabilir yönetici işlemi yok.')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Kulübü sil' })).toBeNull();
  });
});

// ---- icerik moderasyonu ----
describe('ContentReviewPage', () => {
  it('birlesik listeyi gosterir; durum/tur suzgeci istege yansir', async () => {
    const { calls } = setup();
    renderWithProviders(<ContentReviewPage />);
    const rows = await screen.findAllByTestId('content-row');
    expect(rows).toHaveLength(3);
    expect(within(rows[0]).getByText('2 açık şikâyet')).toBeInTheDocument();
    expect(within(rows[1]).getByText(/spam suphesi/)).toBeInTheDocument();
    expect(within(rows[2]).getByText('Duyuru')).toBeInTheDocument();

    const user = userEvent.setup();
    await user.selectOptions(screen.getByLabelText('Durum'), 'HIDDEN');
    await waitFor(() => expect(calls.some((c) => c.url.includes('status=HIDDEN'))).toBe(true));
    await user.selectOptions(screen.getByLabelText('Tür'), 'ANNOUNCEMENT');
    await waitFor(() => expect(calls.some((c) => c.url.includes('kind=ANNOUNCEMENT'))).toBe(true));
    await user.type(screen.getByLabelText('En az açık şikâyet'), '2');
    await waitFor(() => expect(calls.some((c) => c.url.includes('minReports=2'))).toBe(true));
    await user.selectOptions(screen.getByLabelText('Sıralama'), 'reports');
    await waitFor(() => expect(calls.some((c) => c.url.includes('sort=reports'))).toBe(true));
  });

  it('gizleme sebep istege baglidir ve POST hide gider; geri al unhide cagirir', async () => {
    const { calls } = setup();
    renderWithProviders(<ContentReviewPage />);
    const rows = await screen.findAllByTestId('content-row');
    const user = userEvent.setup();
    await user.click(within(rows[0]).getByRole('button', { name: 'Gizle' }));
    const dialog = await screen.findByRole('dialog', { name: /gizlensin mi/ });
    expect(dialog).toHaveTextContent('geri alınabilir');
    await user.type(within(dialog).getByRole('textbox'), 'spam suphesi');
    await user.click(within(dialog).getByRole('button', { name: 'Gizle' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].method).toBe('POST');
    expect(writes(calls)[0].url).toBe('/api/admin/community-posts/1/hide');
    expect(reasonOf(writes(calls)[0])).toBe('spam suphesi');

    await user.click(within(rows[1]).getByRole('button', { name: 'Geri al' }));
    const d2 = await screen.findByRole('dialog', { name: /yeniden gösterilsin/ });
    await user.click(within(d2).getByRole('button', { name: 'Geri al' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(2));
    expect(writes(calls)[1].url).toBe('/api/admin/community-posts/2/unhide');
  });

  it('silme: sebep zorunlu + geri alinamaz uyarisi; DELETE sebep basligiyla gider', async () => {
    const { calls } = setup();
    renderWithProviders(<ContentReviewPage />);
    const rows = await screen.findAllByTestId('content-row');
    const user = userEvent.setup();
    await user.click(within(rows[2]).getByRole('button', { name: 'Sil' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(dialog).toHaveTextContent(/geri alınamaz/i);
    const confirm = within(dialog).getByRole('button', { name: 'Sil' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByRole('textbox'), 'Kulüp kurallarına aykırı duyuru');
    await user.click(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].method).toBe('DELETE');
    expect(writes(calls)[0].url).toBe('/api/admin/community-posts/3');
    expect(reasonOf(writes(calls)[0])).toBe('Kulüp kurallarına aykırı duyuru');
  });

  it('metin duzenleme: bos/degismemis kayit kapali; PATCH yeni metni gonderir', async () => {
    const { calls } = setup();
    renderWithProviders(<ContentReviewPage />);
    const rows = await screen.findAllByTestId('content-row');
    const user = userEvent.setup();
    await user.click(within(rows[0]).getByRole('button', { name: 'Düzenle' }));
    const dialog = await screen.findByRole('dialog', { name: 'Metni düzenle' });
    const save = within(dialog).getByRole('button', { name: 'Kaydet' });
    const box = within(dialog).getByRole('textbox');
    expect(save).toBeDisabled(); // değişmedi
    await user.clear(box);
    expect(save).toBeDisabled(); // boş
    await user.type(box, 'yeni metin');
    expect(save).toBeEnabled();
    await user.click(save);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0].method).toBe('PATCH');
    expect(writes(calls)[0].url).toBe('/api/admin/community-posts/1');
    expect(writes(calls)[0].body).toEqual({ text: 'yeni metin' });
  });

  it('sikayet ayrintisi acilir ve acik sikayetler listelenir', async () => {
    setup();
    renderWithProviders(<ContentReviewPage />);
    const rows = await screen.findAllByTestId('content-row');
    const user = userEvent.setup();
    await user.click(within(rows[0]).getByRole('button', { name: 'Şikâyetler' }));
    expect(await screen.findByText('reklam')).toBeInTheDocument();
  });
});
