// Forum yönetimi: kategoriler, şikâyet kuyruğu, konular, işlem kayıtları. Yükleme/boş/hata/dolu, süzgeç, gerekçeli eylem,
// anonim yazar, izin yoksa eylem yok. Backend uçları MSW yerine fetch taklidiyle (mevcut admin sayfa testleri gibi) simüle edilir.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../../test/fetchMock';
import { renderWithProviders } from '../../../test/utils';
import ForumActionsPage from './ForumActionsPage';
import ForumCategoriesPage from './ForumCategoriesPage';
import ForumReportsPage, { reportActions } from './ForumReportsPage';
import ForumTopicsPage, { topicActions } from './ForumTopicsPage';

vi.setConfig({ testTimeout: 20000 });

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

interface Call {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: unknown;
}

const FULL = ['forum.read', 'forum.moderate', 'forum.categories', 'admin.full'];
const VIEWER = ['forum.read'];

type Route = (c: Call) => Response | undefined;

function setup(routes: Route[], perms: string[] = FULL) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const call: Call = {
      url,
      method: init.method ?? 'GET',
      headers: (init.headers ?? {}) as Record<string, string>,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
    };
    if (url === '/api/admin/rbac/me') return jsonResponse(200, { profile: 'FULL', permissions: perms, twoPerson: false });
    calls.push(call);
    for (const r of routes) {
      const res = r(call);
      if (res) return res;
    }
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}
const writes = (calls: Call[]) => calls.filter((c) => c.method !== 'GET');
const get = (path: string, body: unknown): Route => (c) =>
  c.method === 'GET' && c.url.split('?')[0] === path ? jsonResponse(200, body) : undefined;
const post = (re: RegExp, body: unknown = {}): Route => (c) => (c.method === 'POST' && re.test(c.url) ? jsonResponse(200, body) : undefined);
/** Yıkıcı eylemler (kaldır) alertdialog, diğerleri dialog açar. */
async function topDialog(role: 'dialog' | 'alertdialog' = 'dialog') {
  const all = await screen.findAllByRole(role);
  return all[all.length - 1]!;
}

// ---------------------------------------------------------------- kategoriler
const cat = (over: Record<string, unknown> = {}) => ({
  id: 1,
  slug: 'gundem',
  nameTr: 'Gündem',
  nameEn: 'News',
  nameAr: '',
  sortOrder: 1,
  active: true,
  topicCount: 12,
  ...over,
});

describe('kategoriler', () => {
  const list = () => [cat(), cat({ id: 2, slug: 'yurtlar', nameTr: 'Yurtlar', nameEn: 'Dorms', sortOrder: 2, active: false, topicCount: 0 })];

  it('adı, slug, çeviri durumu, konu sayısı ve arşivli rozetini listeler', async () => {
    setup([get('/api/admin/forum/categories', list())]);
    renderWithProviders(<ForumCategoriesPage />);
    const rows = await screen.findAllByTestId('forum-cat-row');
    expect(rows).toHaveLength(2);
    expect(within(rows[0]!).getByText('Gündem')).toBeInTheDocument();
    expect(within(rows[0]!).getByText('12 konu')).toBeInTheDocument();
    expect(within(rows[0]!).getByText('Aktif')).toBeInTheDocument();
    expect(within(rows[0]!).getByText('gundem')).toBeInTheDocument();
    expect(within(rows[0]!).getByText(/çeviri yok/)).toBeInTheDocument();
    expect(within(rows[1]!).getByText('Arşivli')).toBeInTheDocument();
  });

  it('{items:[...]} ve names:{tr,en,ar} biçimini de kabul eder', async () => {
    setup([get('/api/admin/forum/categories', { items: [{ id: 5, slug: 'x', names: { tr: 'Dersler', en: 'Courses', ar: 'مواد' }, sortOrder: 1, active: true, topicCount: 3 }] })]);
    renderWithProviders(<ForumCategoriesPage />);
    expect(await screen.findByText('Dersler')).toBeInTheDocument();
    expect(screen.getByText('مواد')).toBeInTheDocument();
  });

  it('boş durum ve hata durumu', async () => {
    setup([get('/api/admin/forum/categories', [])]);
    const first = renderWithProviders(<ForumCategoriesPage />);
    expect(await screen.findByText('Henüz kategori yok')).toBeInTheDocument();
    first.unmount();
    vi.unstubAllGlobals();
    setup([(c) => (c.method === 'GET' ? jsonResponse(500, { code: 'INTERNAL', message: 'x' }) : undefined)]);
    renderWithProviders(<ForumCategoriesPage />);
    expect(await screen.findByRole('button', { name: /Tekrar dene/ })).toBeInTheDocument();
  });

  it('yeni kategori üç dilli ad ile oluşturulur; Türkçe ad zorunlu', async () => {
    const calls = setup([get('/api/admin/forum/categories', list()), post(/\/forum\/categories$/)]);
    renderWithProviders(<ForumCategoriesPage />);
    const user = userEvent.setup();
    await screen.findAllByTestId('forum-cat-row');
    await user.click(screen.getByRole('button', { name: 'Yeni kategori' }));
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    expect(await screen.findByText('Türkçe ad zorunlu')).toBeInTheDocument();
    expect(writes(calls)).toHaveLength(0);
    await user.type(screen.getByLabelText(/Ad \(Türkçe\)/), 'Burslar');
    await user.type(screen.getByLabelText(/Ad \(İngilizce\)/), 'Scholarships');
    await user.type(screen.getByLabelText(/Ad \(Arapça\)/), 'منح');
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    const w = writes(calls)[0]!;
    expect(w.method).toBe('POST');
    expect(w.url).toBe('/api/admin/forum/categories');
    expect(w.body).toMatchObject({ nameTr: 'Burslar', nameEn: 'Scholarships', nameAr: 'منح', active: true });
  });

  it('boş İngilizce/Arapça ad gönderilmez (sunucu Türkçe ada düşer, güncellemede mevcut kalır)', async () => {
    const calls = setup([get('/api/admin/forum/categories', list()), post(/\/forum\/categories$/)]);
    renderWithProviders(<ForumCategoriesPage />);
    const user = userEvent.setup();
    await screen.findAllByTestId('forum-cat-row');
    await user.click(screen.getByRole('button', { name: 'Yeni kategori' }));
    await user.type(screen.getByLabelText(/Ad \(Türkçe\)/), 'Burslar');
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    const body = writes(calls)[0]!.body as Record<string, unknown>;
    expect(body.nameTr).toBe('Burslar');
    expect('nameEn' in body).toBe(false);
    expect('nameAr' in body).toBe(false);
  });

  it('geçersiz slug kaydı engeller', async () => {
    const calls = setup([get('/api/admin/forum/categories', list())]);
    renderWithProviders(<ForumCategoriesPage />);
    const user = userEvent.setup();
    await screen.findAllByTestId('forum-cat-row');
    await user.click(screen.getByRole('button', { name: 'Yeni kategori' }));
    await user.type(screen.getByLabelText(/Ad \(Türkçe\)/), 'Burslar');
    await user.type(screen.getByLabelText(/Kısa ad/), 'Büyük Harf');
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    expect(await screen.findByText(/Küçük harf, rakam ve tire kullanın/)).toBeInTheDocument();
    expect(writes(calls)).toHaveLength(0);
  });

  it('düzenleme PATCH ile gider ve slug kilitlidir', async () => {
    const calls = setup([get('/api/admin/forum/categories', list()), (c) => (c.method === 'PATCH' ? jsonResponse(200, cat()) : undefined)]);
    renderWithProviders(<ForumCategoriesPage />);
    const user = userEvent.setup();
    const rows = await screen.findAllByTestId('forum-cat-row');
    await user.click(within(rows[0]!).getByRole('button', { name: 'Düzenle' }));
    expect(screen.getByLabelText(/Kısa ad/)).toBeDisabled();
    const name = screen.getByLabelText(/Ad \(Türkçe\)/);
    await user.clear(name);
    await user.type(name, 'Gündem 2');
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0]!.url).toBe('/api/admin/forum/categories/1');
    expect(writes(calls)[0]!.body).toMatchObject({ nameTr: 'Gündem 2' });
  });

  it('aşağı taşıma sıra ucuna tam kimlik listesini yollar; ilk yukarı, son aşağı pasif', async () => {
    const calls = setup([get('/api/admin/forum/categories', list()), post(/\/categories\/reorder$/)]);
    renderWithProviders(<ForumCategoriesPage />);
    const user = userEvent.setup();
    await screen.findAllByTestId('forum-cat-row');
    expect(screen.getByRole('button', { name: 'Gündem kategorisini yukarı taşı' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Yurtlar kategorisini aşağı taşı' })).toBeDisabled();
    await user.click(screen.getByRole('button', { name: 'Gündem kategorisini aşağı taşı' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0]!.url).toBe('/api/admin/forum/categories/reorder');
    expect(writes(calls)[0]!.body).toEqual({ ids: [2, 1] });
  });

  it('arşivleme onay penceresi ister ve DELETE gönderir; arşivliyi geri çıkarır', async () => {
    const calls = setup([
      get('/api/admin/forum/categories', list()),
      (c) => (c.method === 'DELETE' ? new Response(null, { status: 204 }) : undefined),
      (c) => (c.method === 'PATCH' ? jsonResponse(200, cat({ id: 2 })) : undefined),
    ]);
    renderWithProviders(<ForumCategoriesPage />);
    const user = userEvent.setup();
    const rows = await screen.findAllByTestId('forum-cat-row');
    await user.click(within(rows[0]!).getByRole('button', { name: 'Arşivle' }));
    const dialog = await screen.findByRole('dialog');
    expect(dialog).toHaveTextContent('konular yerinde kalır');
    expect(writes(calls)).toHaveLength(0);
    await user.click(within(dialog).getByRole('button', { name: 'Arşivle' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0]).toMatchObject({ method: 'DELETE', url: '/api/admin/forum/categories/1' });
    await user.click(within(rows[1]!).getByRole('button', { name: 'Arşivden çıkar' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(2));
    expect(writes(calls)[1]).toMatchObject({ method: 'PATCH', url: '/api/admin/forum/categories/2', body: { active: true } });
  });

  it('forum.categories izni yoksa ekleme/düzenleme/sıralama düğmesi yok, liste okunur', async () => {
    setup([get('/api/admin/forum/categories', list())], VIEWER);
    renderWithProviders(<ForumCategoriesPage />);
    await screen.findAllByTestId('forum-cat-row');
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Yeni kategori' })).not.toBeInTheDocument());
    expect(screen.queryByRole('button', { name: 'Düzenle' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /taşı/ })).not.toBeInTheDocument();
    expect(screen.getByText(/yalnız okuyabilir/)).toBeInTheDocument();
  });
});

// ---------------------------------------------------------------- şikâyet kuyruğu
const topicReport = (over: Record<string, unknown> = {}) => ({
  id: 31,
  targetType: 'FORUM_TOPIC',
  targetId: 9,
  topicId: 9,
  status: 'OPEN',
  reasons: ['SPAM', 'PERSONAL_INFO'],
  note: 'Telefon numarası var',
  reportCount: 3,
  createdAt: '2026-11-05T09:00:00Z',
  preview: { title: 'Ucuz kitap satılık', body: 'Beni ara 0555 000 00 00', authorName: 'Ali Veli', anonymous: false, status: 'ACTIVE', pinned: false, locked: false },
  ...over,
});
const commentReport = () =>
  topicReport({
    id: 32,
    targetType: 'FORUM_COMMENT',
    targetId: 77,
    topicId: 9,
    reasons: ['HARASSMENT'],
    note: null,
    reportCount: 1,
    preview: { title: null, body: 'Aptalsın sen', authorName: 'GIZLI AD', anonymous: true, status: 'ACTIVE' },
  });
const reportsPage = (items: unknown[], nextCursor: string | null = null) => ({ items, nextCursor });

describe('şikâyet kuyruğu', () => {
  it('konu ve yorum şikâyetini önizleme, neden ve sayaçla gösterir; anonim yazar adı sızmaz', async () => {
    setup([get('/api/admin/forum/reports', reportsPage([topicReport(), commentReport()]))]);
    renderWithProviders(<ForumReportsPage />);
    const rows = await screen.findAllByTestId('forum-report-row');
    expect(rows).toHaveLength(2);
    const t = within(rows[0]!);
    expect(t.getByText('Ucuz kitap satılık')).toBeInTheDocument();
    expect(t.getByText(/0555 000 00 00/)).toBeInTheDocument();
    expect(t.getByText('Ali Veli')).toBeInTheDocument();
    expect(t.getByText('3 şikâyet')).toBeInTheDocument();
    expect(t.getByText('Spam')).toBeInTheDocument();
    expect(t.getByText('Kişisel bilgi')).toBeInTheDocument();
    expect(t.getByText(/Şikâyet notu: Telefon numarası var/)).toBeInTheDocument();
    const c = within(rows[1]!);
    expect(c.getByText('Yorum')).toBeInTheDocument();
    expect(c.getAllByText('Anonim').length).toBeGreaterThan(0);
    expect(screen.queryByText('GIZLI AD')).not.toBeInTheDocument();
  });

  it('varsayılan olarak açık şikâyetleri ister; süzgeç tür ve nedeni sorguya yazar', async () => {
    const calls = setup([get('/api/admin/forum/reports', reportsPage([topicReport()]))]);
    renderWithProviders(<ForumReportsPage />);
    const user = userEvent.setup();
    await screen.findByTestId('forum-report-row');
    expect(calls.some((c) => c.url.includes('status=OPEN'))).toBe(true);
    await user.selectOptions(screen.getByLabelText('Tür'), 'FORUM_COMMENT');
    await user.selectOptions(screen.getByLabelText('Neden'), 'HARASSMENT');
    await waitFor(() => expect(calls.some((c) => c.url.includes('type=FORUM_COMMENT') && c.url.includes('reason=HARASSMENT'))).toBe(true));
    await user.selectOptions(screen.getByLabelText('Durum'), '');
    await waitFor(() => expect(calls.some((c) => !c.url.includes('status=') && c.url.includes('type=FORUM_COMMENT'))).toBe(true));
  });

  it('boş, süzgeçli boş ve hata durumları', async () => {
    setup([get('/api/admin/forum/reports', reportsPage([]))]);
    const first = renderWithProviders(<ForumReportsPage />);
    expect(await screen.findByText('Bekleyen şikâyet yok')).toBeInTheDocument();
    await userEvent.setup().selectOptions(screen.getByLabelText('Tür'), 'FORUM_TOPIC');
    expect(await screen.findByText('Bu süzgece uyan şikâyet yok')).toBeInTheDocument();
    first.unmount();
    vi.unstubAllGlobals();
    setup([(c) => (c.method === 'GET' ? jsonResponse(500, { code: 'INTERNAL', message: 'x' }) : undefined)]);
    renderWithProviders(<ForumReportsPage />);
    expect(await screen.findByRole('button', { name: /Tekrar dene/ })).toBeInTheDocument();
  });

  it('"daha fazla" sonraki imleçle ikinci sayfayı çeker', async () => {
    const calls = setup([
      (c) => {
        if (c.method !== 'GET' || !c.url.startsWith('/api/admin/forum/reports')) return undefined;
        return c.url.includes('cursor=abc')
          ? jsonResponse(200, reportsPage([commentReport()]))
          : jsonResponse(200, reportsPage([topicReport()], 'abc'));
      },
    ]);
    renderWithProviders(<ForumReportsPage />);
    const user = userEvent.setup();
    await screen.findByTestId('forum-report-row');
    await user.click(await screen.findByRole('button', { name: /Daha fazla/ }));
    await waitFor(() => expect(screen.getAllByTestId('forum-report-row')).toHaveLength(2));
    expect(calls.some((c) => c.url.includes('cursor=abc'))).toBe(true);
  });

  it('konu içeriğini kaldırmak gerekçe ister; gerekçe başlıkta ve gövdede gider', async () => {
    const calls = setup([get('/api/admin/forum/reports', reportsPage([topicReport()])), post(/\/topics\/9\/moderate$/)]);
    renderWithProviders(<ForumReportsPage />);
    const user = userEvent.setup();
    const row = await screen.findByTestId('forum-report-row');
    await user.click(await within(row).findByRole('button', { name: 'İçeriği kaldır' }));
    const dialog = await topDialog('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'İçeriği kaldır' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByLabelText(/Gerekçe/), 'kişisel bilgi paylaşımı');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    const w = writes(calls)[0]!;
    expect(w.url).toBe('/api/admin/forum/topics/9/moderate');
    expect(w.body).toMatchObject({ action: 'REMOVE', reason: 'kişisel bilgi paylaşımı' });
    expect(decodeURIComponent(w.headers['X-Admin-Reason']!)).toBe('kişisel bilgi paylaşımı');
    expect(w.headers['Idempotency-Key']).toBeTruthy();
  });

  it('yorum kaldırma yorum ucuna gider; yoksay şikâyet çözme ucuna gider', async () => {
    const calls = setup([
      get('/api/admin/forum/reports', reportsPage([commentReport()])),
      post(/\/comments\/77\/moderate$/),
      post(/\/reports\/32\/resolve$/),
    ]);
    renderWithProviders(<ForumReportsPage />);
    const user = userEvent.setup();
    const row = await screen.findByTestId('forum-report-row');
    // yorumda sabitle/kilitle yok
    expect(within(row).queryByRole('button', { name: 'Sabitle' })).not.toBeInTheDocument();
    await user.click(await within(row).findByRole('button', { name: 'İçeriği kaldır' }));
    let dialog = await topDialog('alertdialog');
    await user.type(within(dialog).getByLabelText(/Gerekçe/), 'hakaret içeriyor');
    await user.click(within(dialog).getByRole('button', { name: 'İçeriği kaldır' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0]!.url).toBe('/api/admin/forum/comments/77/moderate');
    expect(writes(calls)[0]!.body).toMatchObject({ action: 'REMOVE' });

    await user.click(await within(row).findByRole('button', { name: 'Yoksay / çözüldü' }));
    dialog = await topDialog();
    await user.type(within(dialog).getByLabelText(/Gerekçe/), 'kural ihlali yok');
    await user.click(within(dialog).getByRole('button', { name: 'Yoksay / çözüldü' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(2));
    expect(writes(calls)[1]!.url).toBe('/api/admin/forum/reports/32/resolve');
    expect(decodeURIComponent(writes(calls)[1]!.headers['X-Admin-Reason']!)).toBe('kural ihlali yok');
  });

  it('kısa gerekçe (5 karakterden az) onayı açmaz', async () => {
    const calls = setup([get('/api/admin/forum/reports', reportsPage([topicReport()]))]);
    renderWithProviders(<ForumReportsPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Sabitle' }));
    const dialog = await topDialog();
    await user.type(within(dialog).getByLabelText(/Gerekçe/), 'ab');
    expect(within(dialog).getByRole('button', { name: 'Sabitle' })).toBeDisabled();
    expect(writes(calls)).toHaveLength(0);
  });

  it('kaldırılmış içerikte "Geri al" sunulur', async () => {
    setup([get('/api/admin/forum/reports', reportsPage([topicReport({ preview: { ...topicReport().preview, status: 'REMOVED' } })]))]);
    renderWithProviders(<ForumReportsPage />);
    const row = await screen.findByTestId('forum-report-row');
    expect(await within(row).findByRole('button', { name: 'Geri al' })).toBeInTheDocument();
    expect(within(row).queryByRole('button', { name: 'İçeriği kaldır' })).not.toBeInTheDocument();
    expect(within(row).getByText('Kaldırıldı')).toBeInTheDocument();
  });

  it('forum.moderate izni yoksa eylem düğmesi yok (salt okunur)', async () => {
    setup([get('/api/admin/forum/reports', reportsPage([topicReport()]))], VIEWER);
    renderWithProviders(<ForumReportsPage />);
    const row = await screen.findByTestId('forum-report-row');
    await waitFor(() => expect(screen.getByText(/yalnız okuyabilir/)).toBeInTheDocument());
    expect(within(row).queryByRole('button', { name: 'İçeriği kaldır' })).not.toBeInTheDocument();
    expect(within(row).queryByRole('button', { name: 'Yoksay / çözüldü' })).not.toBeInTheDocument();
  });

  it('eylem kümeleri duruma göre seçilir', () => {
    const base = { targetType: 'FORUM_TOPIC' as const, status: 'OPEN' as const };
    const pv = { title: 't', body: 'b', authorName: null, anonymous: false, contentStatus: 'ACTIVE' as const, pinned: false, locked: false };
    expect(reportActions({ ...base, preview: pv })).toEqual(['REMOVE', 'PIN', 'LOCK', 'DISMISS']);
    expect(reportActions({ ...base, preview: { ...pv, pinned: true, locked: true } })).toEqual(['REMOVE', 'UNPIN', 'UNLOCK', 'DISMISS']);
    expect(reportActions({ ...base, preview: { ...pv, contentStatus: 'REMOVED' } })).toEqual(['RESTORE', 'DISMISS']);
    expect(reportActions({ targetType: 'FORUM_COMMENT', status: 'RESOLVED', preview: pv })).toEqual(['REMOVE']);
    // sahibi silmiş / kaydı yok: kaldır-geri al yok, yalnız açık şikâyet yoksayılır
    expect(reportActions({ ...base, preview: { ...pv, contentStatus: 'DELETED' } })).toEqual(['DISMISS']);
    expect(reportActions({ targetType: 'FORUM_COMMENT', status: 'RESOLVED', preview: { ...pv, contentStatus: 'MISSING' } })).toEqual([]);
  });
});

// ---------------------------------------------------------------- konular
const topic = (over: Record<string, unknown> = {}) => ({
  id: 9,
  title: 'Yemekhane menüsü hakkında',
  bodyPreview: 'Bu hafta yemekler nasıldı?',
  category: { id: 1, name: 'Yemekhane', slug: 'yemekhane' },
  author: { userId: 4, displayName: 'Ayşe Yılmaz', anonymous: false },
  anonymous: false,
  status: 'ACTIVE',
  pinned: false,
  locked: false,
  commentCount: 8,
  likeCount: 21,
  openReportCount: 0,
  createdAt: '2026-11-04T10:00:00Z',
  ...over,
});
const topicsPage = (items: unknown[], over: Record<string, unknown> = {}) => ({ items, page: 0, totalPages: 1, totalItems: items.length, ...over });
const catsRoute = get('/api/admin/forum/categories', [cat({ id: 1, nameTr: 'Yemekhane', slug: 'yemekhane' }), cat({ id: 2, nameTr: 'Dersler', slug: 'dersler' })]);

describe('konular', () => {
  it('konuyu kategori, yazar, sayaç ve rozetlerle listeler; anonim yazar "Anonim"', async () => {
    setup([
      catsRoute,
      get('/api/admin/forum/topics', topicsPage([topic({ pinned: true, openReportCount: 2 }), topic({ id: 10, title: 'Gizli konu', anonymous: true, author: { displayName: 'Anonim #3', anonymous: true } })])),
    ]);
    renderWithProviders(<ForumTopicsPage />);
    const rows = await screen.findAllByTestId('forum-topic-row');
    expect(rows).toHaveLength(2);
    const a = within(rows[0]!);
    expect(a.getByText('Yemekhane menüsü hakkında')).toBeInTheDocument();
    expect(a.getByText('Ayşe Yılmaz')).toBeInTheDocument();
    expect(a.getByText('8 yorum')).toBeInTheDocument();
    expect(a.getByText('21 beğeni')).toBeInTheDocument();
    expect(a.getByText('Sabit')).toBeInTheDocument();
    expect(a.getByText('2 şikâyet')).toBeInTheDocument();
    const b = within(rows[1]!);
    expect(b.getAllByText('Anonim').length).toBeGreaterThan(0);
    expect(screen.queryByText('Anonim #3')).not.toBeInTheDocument();
  });

  it('arama (bekletmeli), durum ve kategori süzgeci ile sayfa sorguya yazılır', async () => {
    const calls = setup([catsRoute, get('/api/admin/forum/topics', topicsPage([topic()], { totalPages: 3, totalItems: 50 }))]);
    renderWithProviders(<ForumTopicsPage />);
    const user = userEvent.setup();
    await screen.findByTestId('forum-topic-row');
    await user.type(screen.getByLabelText('Ara'), 'menü');
    await waitFor(() => expect(calls.some((c) => c.url.includes('q=men'))).toBe(true));
    await user.selectOptions(screen.getByLabelText('Durum'), 'REMOVED');
    await waitFor(() => expect(calls.some((c) => c.url.includes('status=REMOVED'))).toBe(true));
    await user.selectOptions(await screen.findByLabelText('Kategori'), '2');
    await waitFor(() => expect(calls.some((c) => c.url.includes('categoryId=2'))).toBe(true));
    await user.click(screen.getByRole('button', { name: 'Sonraki sayfa' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('page=1'))).toBe(true));
  });

  it('boş, süzgeçli boş ve hata durumları; kategori okunamazsa süzgeç gizlenir ama liste çalışır', async () => {
    setup([(c) => (c.url.startsWith('/api/admin/forum/categories') ? jsonResponse(403, { code: 'ADMIN_PERMISSION_DENIED', message: 'x' }) : undefined), get('/api/admin/forum/topics', topicsPage([]))]);
    const first = renderWithProviders(<ForumTopicsPage />);
    expect(await screen.findByText('Henüz konu yok')).toBeInTheDocument();
    expect(screen.queryByLabelText('Kategori')).not.toBeInTheDocument();
    await userEvent.setup().selectOptions(screen.getByLabelText('Durum'), 'ACTIVE');
    expect(await screen.findByText('Bu süzgece uyan konu yok')).toBeInTheDocument();
    first.unmount();
    vi.unstubAllGlobals();
    setup([catsRoute, (c) => (c.url.startsWith('/api/admin/forum/topics') ? jsonResponse(500, { code: 'INTERNAL', message: 'x' }) : undefined)]);
    renderWithProviders(<ForumTopicsPage />);
    expect(await screen.findByRole('button', { name: /Tekrar dene/ })).toBeInTheDocument();
  });

  it('ayrıntı paneli gövdeyi ve sayaçları gösterir', async () => {
    setup([catsRoute, get('/api/admin/forum/topics', topicsPage([topic({ status: 'REMOVED', removedReason: 'spam içerik' })]))]);
    renderWithProviders(<ForumTopicsPage />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Ayrıntı' }));
    const drawer = await screen.findByRole('dialog');
    expect(within(drawer).getByRole('heading', { name: 'Konu ayrıntısı' })).toBeInTheDocument();
    expect(within(drawer).getByText('Bu hafta yemekler nasıldı?')).toBeInTheDocument();
    expect(within(drawer).getByText(/Kaldırma gerekçesi: spam içerik/)).toBeInTheDocument();
    expect(within(drawer).getByText('Beğeni')).toBeInTheDocument();
  });

  it('kilitleme gerekçeyle gider; kaldırılmış konuda yalnız "Geri al" var', async () => {
    const calls = setup([catsRoute, get('/api/admin/forum/topics', topicsPage([topic(), topic({ id: 10, status: 'REMOVED' })])), post(/\/topics\/9\/moderate$/)]);
    renderWithProviders(<ForumTopicsPage />);
    const user = userEvent.setup();
    const rows = await screen.findAllByTestId('forum-topic-row');
    expect(await within(rows[1]!).findByRole('button', { name: 'Geri al' })).toBeInTheDocument();
    expect(within(rows[1]!).queryByRole('button', { name: 'Yorumlara kapat' })).not.toBeInTheDocument();
    await user.click(within(rows[0]!).getByRole('button', { name: 'Yorumlara kapat' }));
    const dialog = await topDialog();
    await user.type(within(dialog).getByLabelText(/Gerekçe/), 'tartışma kontrolden çıktı');
    await user.click(within(dialog).getByRole('button', { name: 'Yorumlara kapat' }));
    await waitFor(() => expect(writes(calls)).toHaveLength(1));
    expect(writes(calls)[0]!.url).toBe('/api/admin/forum/topics/9/moderate');
    expect(writes(calls)[0]!.body).toMatchObject({ action: 'LOCK', reason: 'tartışma kontrolden çıktı' });
  });

  it('izin yoksa moderatör eylemi yok ama ayrıntı açılır', async () => {
    setup([catsRoute, get('/api/admin/forum/topics', topicsPage([topic()]))], VIEWER);
    renderWithProviders(<ForumTopicsPage />);
    await screen.findByTestId('forum-topic-row');
    await waitFor(() => expect(screen.getByText(/yalnız okuyabilir/)).toBeInTheDocument());
    expect(screen.queryByRole('button', { name: 'Sabitle' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'İçeriği kaldır' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Ayrıntı' })).toBeInTheDocument();
  });

  it('eylem kümesi duruma göre', () => {
    expect(topicActions({ status: 'ACTIVE', pinned: false, locked: false })).toEqual(['PIN', 'LOCK', 'REMOVE']);
    expect(topicActions({ status: 'ACTIVE', pinned: true, locked: true })).toEqual(['UNPIN', 'UNLOCK', 'REMOVE']);
    expect(topicActions({ status: 'REMOVED', pinned: true, locked: false })).toEqual(['RESTORE']);
    expect(topicActions({ status: 'DELETED', pinned: false, locked: false })).toEqual([]);
  });
});

// ---------------------------------------------------------------- işlem kayıtları
const act = (over: Record<string, unknown> = {}) => ({
  id: 1,
  actorName: 'Moderatör Mert',
  actorId: 12,
  targetType: 'FORUM_TOPIC',
  targetId: 9,
  action: 'REMOVE',
  reason: 'spam içerik',
  createdAt: '2026-11-05T08:30:00Z',
  ...over,
});

describe('işlem kayıtları', () => {
  it('aktör, eylem, hedef, gerekçe ve tarihi tabloda gösterir', async () => {
    setup([get('/api/admin/forum/actions', { items: [act(), act({ id: 2, action: 'PIN', targetType: 'FORUM_COMMENT', targetId: 5, reason: 'duyuru', actorName: null })], nextCursor: null })]);
    renderWithProviders(<ForumActionsPage />);
    await screen.findByText('Moderatör Mert'); // yükleme iskeleti de bir tablodur: veri gelene kadar bekle
    const table = within(screen.getByRole('table'));
    expect(table.getByText('Moderatör Mert')).toBeInTheDocument();
    expect(table.getByText('İçeriği kaldır')).toBeInTheDocument();
    expect(table.getByText('spam içerik')).toBeInTheDocument();
    expect(table.getByText('Konu')).toBeInTheDocument();
    expect(table.getByText('#12')).toBeInTheDocument(); // adı yoksa kimlik
    expect(table.getByText('Sabitle')).toBeInTheDocument();
  });

  it('süzgeç eylem ve hedef türünü sorguya yazar; daha fazla sonraki imleci kullanır', async () => {
    const calls = setup([
      (c) => {
        if (c.method !== 'GET' || !c.url.startsWith('/api/admin/forum/actions')) return undefined;
        return c.url.includes('cursor=7')
          ? jsonResponse(200, { items: [act({ id: 3, reason: 'ikinci sayfa kaydı' })], nextCursor: null })
          : jsonResponse(200, { items: [act()], nextCursor: 7 });
      },
    ]);
    renderWithProviders(<ForumActionsPage />);
    const user = userEvent.setup();
    await screen.findByRole('table');
    await user.selectOptions(screen.getByLabelText('Eylem'), 'LOCK');
    await user.selectOptions(screen.getByLabelText('Hedef türü'), 'FORUM_COMMENT');
    await waitFor(() => expect(calls.some((c) => c.url.includes('action=LOCK') && c.url.includes('targetType=FORUM_COMMENT'))).toBe(true));
    await user.click(await screen.findByRole('button', { name: /Daha fazla/ }));
    expect(await screen.findByText('ikinci sayfa kaydı')).toBeInTheDocument();
    expect(calls.some((c) => c.url.includes('cursor=7'))).toBe(true);
  });

  it('boş ve hata durumu', async () => {
    setup([get('/api/admin/forum/actions', { items: [], nextCursor: null })]);
    const first = renderWithProviders(<ForumActionsPage />);
    expect(await screen.findByText('Henüz işlem kaydı yok')).toBeInTheDocument();
    first.unmount();
    vi.unstubAllGlobals();
    setup([(c) => (c.method === 'GET' ? jsonResponse(500, { code: 'INTERNAL', message: 'x' }) : undefined)]);
    renderWithProviders(<ForumActionsPage />);
    expect(await screen.findByRole('button', { name: /Tekrar dene/ })).toBeInTheDocument();
  });

  it('salt okunur: hiçbir yazma düğmesi yok', async () => {
    setup([get('/api/admin/forum/actions', { items: [act()], nextCursor: null })], VIEWER);
    renderWithProviders(<ForumActionsPage />);
    await screen.findByRole('table');
    expect(screen.queryByRole('button', { name: /kaldır|Geri al|Sabitle/ })).not.toBeInTheDocument();
  });
});
