import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import * as adminPolls from '../../api/adminPolls';
import type { PollDetail } from '../../api/adminPolls';
import { headerOf, jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import PollsAdminPage from './PollsAdminPage';
import {
  EMPTY_POLL_FORM,
  formFromDetail,
  isStructureLocked,
  toCreateBody,
  toUpdateBody,
  validatePollForm,
} from './polls/pollsLogic';

const row = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  title: `anket-${id}`,
  type: 'SINGLE',
  scope: 'GLOBAL',
  communityId: null,
  status: 'OPEN',
  state: 'OPEN',
  anonymous: false,
  totalVotes: 4,
  opensAt: '2026-02-01T10:00:00Z',
  closesAt: null,
  createdAt: '2026-02-01T10:00:00Z',
  createdBy: 7,
  ...over,
});

const detail = (id: number, over: Record<string, unknown> = {}): PollDetail =>
  ({
    id,
    title: `anket-${id}`,
    description: 'aciklama',
    type: 'SINGLE',
    scope: 'GLOBAL',
    communityId: null,
    communityName: null,
    menuDate: null,
    menuItems: null,
    options: [
      { id: 11, text: 'Evet', position: 1 },
      { id: 12, text: 'Hayir', position: 2 },
    ],
    maxChoices: 1,
    anonymous: true,
    allowChangeVote: true,
    showResults: 'ALWAYS',
    notify: false,
    opensAt: '2026-02-01T10:00:00Z',
    closesAt: null,
    audience: null,
    status: 'OPEN',
    state: 'OPEN',
    createdAt: '2026-02-01T10:00:00Z',
    closedAt: null,
    createdBy: { id: 7, displayName: 'Yonetici' },
    canManage: true,
    resultsVisible: true,
    results: [
      { optionId: 11, count: 3, percent: 75, score: null },
      { optionId: 12, count: 1, percent: 25, score: null },
    ],
    totalVotes: 4,
    turnout: { voted: 4, eligible: 10, percent: 40 },
    average: null,
    ratingCount: null,
    ...over,
  }) as PollDetail;

const stats = {
  total: 9,
  open: 3,
  closed: 4,
  draft: 1,
  cancelled: 1,
  totalVotes: 120,
  byScope: { GLOBAL: 6, COMMUNITY: 2, MENU: 1 },
  avgTurnoutPercent: 42.5,
};

interface Call {
  method: string;
  url: string;
  headers: Record<string, string>;
  body?: unknown;
}

function setup(opts: { rows?: unknown[]; total?: number } = {}) {
  const calls: Call[] = [];
  mockFetch((url, init) => {
    const method = init.method ?? 'GET';
    calls.push({
      method,
      url,
      headers: (init.headers ?? {}) as Record<string, string>,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
    });
    if (url.includes('/admin/polls/stats')) return jsonResponse(200, stats);
    if (url.endsWith('/export.csv')) return new Response('optionId,text,count\r\n', { status: 200, headers: { 'Content-Type': 'text/csv' } });
    if (url.endsWith('/admin/polls/bulk')) return jsonResponse(200, { done: 2, skipped: 0 });
    if (method === 'DELETE') return new Response(null, { status: 204 });
    if (/\/admin\/polls\/1\/close$/.test(url)) return jsonResponse(200, detail(1, { status: 'CLOSED', state: 'CLOSED' }));
    if (/\/admin\/polls\/1$/.test(url)) return jsonResponse(200, detail(1));
    if (method === 'POST' && /\/api\/polls$/.test(url)) return jsonResponse(201, detail(50));
    if (method === 'PATCH' && /\/api\/polls\/1$/.test(url)) return jsonResponse(200, detail(1, { title: 'yeni' }));
    if (url.includes('/admin/polls')) {
      const page = new URL(url, 'http://x').searchParams.get('page') ?? '0';
      return jsonResponse(200, {
        items: page === '1' ? [row(21)] : (opts.rows ?? [row(1, { anonymous: true }), row(2, { state: 'CLOSED', status: 'CLOSED' })]),
        page: Number(page),
        size: 20,
        total: opts.total ?? 2,
      });
    }
    return jsonResponse(404, { code: 'X', message: 'x' });
  });
  return calls;
}

describe('adminPolls.ts sozlesmesi (backend poll paketiyle birebir)', () => {
  let calls: Call[];
  beforeEach(() => {
    calls = [];
    mockFetch((url, init) => {
      calls.push({ method: init.method ?? 'GET', url, headers: (init.headers ?? {}) as Record<string, string>, body: init.body ? JSON.parse(String(init.body)) : undefined });
      return jsonResponse(200, { items: [], page: 0, size: 20, total: 0, done: 1, skipped: 0 });
    });
  });
  afterEach(() => vi.unstubAllGlobals());

  it('liste sayfa tabanlidir ve suzgecleri GLOBAL/COMMUNITY/MENU + DB durumuyla gonderir (imec yok)', async () => {
    await adminPolls.listPolls({ status: 'OPEN', scope: 'MENU', q: ' kahve ' }, 2, 20);
    const u = new URL(calls[0].url, 'http://x');
    expect(u.pathname).toBe('/api/admin/polls');
    expect(Object.fromEntries(u.searchParams)).toEqual({ page: '2', size: '20', status: 'OPEN', scope: 'MENU', q: 'kahve' });
    expect(u.searchParams.has('cursor')).toBe(false);
  });

  it('bos suzgeci sorguya yazmaz', async () => {
    await adminPolls.listPolls({ status: '', scope: '', q: '  ' });
    expect(new URL(calls[0].url, 'http://x').search).toBe('?page=0&size=20');
  });

  it('istatistik, ayrinti, kapat, iptal, sil ve toplu islem dogru yol/yontemle gider; sebep basliga yazilir', async () => {
    await adminPolls.pollStats();
    await adminPolls.getPoll(5);
    await adminPolls.closePoll(5, { reason: 'sure doldu', idempotencyKey: 'k1' });
    await adminPolls.cancelPoll(5, { reason: 'yanlis soru' });
    await adminPolls.deletePoll(5, { reason: 'test anketi' });
    await adminPolls.bulkPolls([1, 2], 'CLOSE', { reason: 'toplu kapatma' });
    expect(calls.map((c) => `${c.method} ${c.url}`)).toEqual([
      'GET /api/admin/polls/stats',
      'GET /api/admin/polls/5',
      'POST /api/admin/polls/5/close',
      'POST /api/admin/polls/5/cancel',
      'DELETE /api/admin/polls/5',
      'POST /api/admin/polls/bulk',
    ]);
    expect(calls[2].headers['X-Admin-Reason']).toBe('sure%20doldu');
    expect(calls[2].headers['Idempotency-Key']).toBe('k1');
    expect(calls[5].body).toEqual({ ids: [1, 2], action: 'CLOSE' });
  });

  it('olusturma POST /api/polls, duzenleme PATCH /api/polls/{id} (yonetim ucu yok)', async () => {
    const body = toCreateBody({ ...EMPTY_POLL_FORM, title: 'x', options: ['a', 'b'] });
    await adminPolls.createPoll(body);
    await adminPolls.updatePoll(9, { title: 'y' });
    expect(calls[0]).toMatchObject({ method: 'POST', url: '/api/polls' });
    expect(calls[1]).toMatchObject({ method: 'PATCH', url: '/api/polls/9', body: { title: 'y' } });
  });

  it('CSV indirme /admin/polls/{id}/export.csv adresindendir', async () => {
    await adminPolls.exportPollCsv(3);
    expect(calls[0]).toMatchObject({ method: 'GET', url: '/api/admin/polls/3/export.csv' });
  });
});

describe('pollsLogic', () => {
  it('gecersiz formu yakalar (kurallar backend PollService ile ayni)', () => {
    const ok = { ...EMPTY_POLL_FORM, title: 'x', options: ['a', 'b'] };
    expect(validatePollForm(EMPTY_POLL_FORM)).toBe('title');
    expect(validatePollForm({ ...EMPTY_POLL_FORM, title: 'x' })).toBe('optionEmpty');
    expect(validatePollForm({ ...ok, options: ['a', 'A'] })).toBe('optionDup');
    expect(validatePollForm({ ...ok, options: Array(13).fill('a') })).toBe('options');
    expect(validatePollForm({ ...ok, options: ['a', 'b'.repeat(101)] })).toBe('optionLong');
    expect(validatePollForm({ ...ok, title: 'y'.repeat(151) })).toBe('title');
    expect(validatePollForm({ ...ok, type: 'MULTI', maxChoices: '3' })).toBe('maxChoices');
    expect(validatePollForm({ ...ok, type: 'MULTI', maxChoices: '2' })).toBeNull();
    expect(validatePollForm({ ...ok, opensAt: '2030-02-02T10:00', closesAt: '2030-02-01T10:00' })).toBe('period');
    expect(validatePollForm({ ...ok, closesAt: '2020-01-01T10:00' }, new Date('2026-01-01'))).toBe('closesPast');
    expect(validatePollForm({ ...ok, grade: '123456789' })).toBe('audience');
    expect(validatePollForm(ok)).toBeNull();
  });

  it('puanlama anketinde secenek gonderilmez (sunucu 1-5 uretir); kapsam GLOBAL', () => {
    const b = toCreateBody({ ...EMPTY_POLL_FORM, title: ' q ', type: 'RATING' });
    expect(b.options).toEqual([]);
    expect(b.title).toBe('q');
    expect(b.scope).toBe('GLOBAL');
    expect(b.audience).toBeNull();
    expect(b.maxChoices).toBeNull();
  });

  it('hedef kitle dolu ise audience gonderilir', () => {
    const b = toCreateBody({ ...EMPTY_POLL_FORM, title: 'x', options: ['a', 'b'], faculty: ' Muhendislik ', grade: '2' });
    expect(b.audience).toEqual({ faculty: 'Muhendislik', department: null, grade: '2' });
  });

  it('guncelleme yalniz degisen alanlari gonderir; kapanis temizlenince bos metin', () => {
    const d = detail(1, { closesAt: '2030-02-01T10:00:00Z' });
    const init = formFromDetail(d);
    expect(toUpdateBody(init, init)).toEqual({});
    expect(toUpdateBody(init, { ...init, title: 'yeni' })).toEqual({ title: 'yeni' });
    expect(toUpdateBody(init, { ...init, closesAt: '' })).toEqual({ closesAt: '' });
    expect(toUpdateBody(init, { ...init, options: ['Evet', 'Belki'] }).options).toEqual(['Evet', 'Belki']);
  });

  it('taslagi yayinlamak draft=false gonderir', () => {
    const init = formFromDetail(detail(1, { status: 'DRAFT', state: 'DRAFT' }));
    expect(init.draft).toBe(true);
    expect(toUpdateBody(init, { ...init, draft: false })).toEqual({ draft: false });
  });

  it('oy alinmis acik anketin yapisi kilitlidir', () => {
    expect(isStructureLocked(detail(1))).toBe(true);
    expect(isStructureLocked(detail(1, { status: 'DRAFT', state: 'DRAFT' }))).toBe(false);
    expect(isStructureLocked(detail(1, { turnout: { voted: 0, eligible: 5, percent: 0 }, totalVotes: 0 }))).toBe(false);
  });
});

describe('PollsAdminPage', () => {
  beforeEach(() => vi.stubGlobal('scrollTo', () => undefined));
  afterEach(() => vi.unstubAllGlobals());

  it('listeler, istatistik kartlarini ve sayfalamayi gosterir; sayfa degisince page=1 ister', async () => {
    const calls = setup({ total: 25 });
    renderWithProviders(<PollsAdminPage />);
    expect(await screen.findByText('anket-1')).toBeInTheDocument();
    expect(await screen.findByTestId('poll-stats')).toHaveTextContent('Toplam anket');
    await waitFor(() => expect(screen.getByTestId('poll-stats')).toHaveTextContent('120'));
    await userEvent.click(screen.getByRole('button', { name: 'Sonraki sayfa' }));
    expect(await screen.findByText('anket-21')).toBeInTheDocument();
    expect(calls.some((c) => c.url.includes('/admin/polls?') && c.url.includes('page=1'))).toBe(true);
  });

  it('durum ve kapsam suzgeci sorguya girer, arama gecikmeli gonderilir ve sayfa basa doner', async () => {
    const calls = setup();
    renderWithProviders(<PollsAdminPage />);
    await screen.findByText('anket-1');
    await userEvent.selectOptions(screen.getByLabelText('Durum'), 'OPEN');
    await userEvent.selectOptions(screen.getByLabelText('Kapsam'), 'COMMUNITY');
    await waitFor(() => expect(calls.some((c) => c.url.includes('status=OPEN') && c.url.includes('scope=COMMUNITY'))).toBe(true));
    await userEvent.type(screen.getByLabelText('Başlıkta ara'), 'kahve');
    await waitFor(() => expect(calls.some((c) => c.url.includes('q=kahve'))).toBe(true), { timeout: 3000 });
    // eski sozlesme alanlari yok
    expect(calls.some((c) => c.url.includes('cursor=') || c.url.includes('scope=GENERAL'))).toBe(false);
  });

  it('menu puanlamalari dugmesi kapsami MENU yapar', async () => {
    const calls = setup();
    renderWithProviders(<PollsAdminPage />);
    await screen.findByText('anket-1');
    await userEvent.click(screen.getByRole('button', { name: 'Menü puanlamaları' }));
    await waitFor(() => expect(calls.some((c) => c.url.includes('scope=MENU'))).toBe(true));
  });

  it('listeleme hatasinda hata durumu cikar', async () => {
    mockFetch((url) => (url.includes('stats') ? jsonResponse(200, stats) : jsonResponse(500, { code: 'X', message: 'x' })));
    renderWithProviders(<PollsAdminPage />);
    expect(await screen.findByRole('button', { name: /Tekrar dene/ })).toBeInTheDocument();
  });

  it('gizli ankette sonuc gorunumunde kimlik notu cikar, kimlik alani yoktur', async () => {
    setup();
    renderWithProviders(<PollsAdminPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'anket-1' }));
    const dlg = await screen.findByTestId('poll-detail');
    expect(within(dlg).getByText(/kimin ne seçtiği gösterilmez/)).toBeInTheDocument();
    expect(within(dlg).getByRole('img', { name: /^Evet:/ })).toBeInTheDocument();
    expect(within(dlg).getByTestId('poll-results')).toHaveTextContent('Katılım');
    expect(dlg.textContent).not.toMatch(/userId|voterId/);
  });

  it('silme: sebep + SIL yazmadan onaylanmaz; onayda sebep basligiyla DELETE gider', async () => {
    const calls = setup();
    renderWithProviders(<PollsAdminPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'anket-1' }));
    await screen.findByTestId('poll-detail');
    await userEvent.click(screen.getAllByRole('button', { name: 'Sil' })[0]);
    const dialog = await screen.findByRole('alertdialog');
    const confirm = within(dialog).getByRole('button', { name: 'Sil' });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'deneme anketi kaldirildi');
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByLabelText('Onay metni'), 'sil');
    expect(confirm).toBeEnabled();
    await userEvent.click(confirm);
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE' && c.url === '/api/admin/polls/1')).toBe(true));
    const del = calls.find((c) => c.method === 'DELETE')!;
    expect(decodeURIComponent(del.headers['X-Admin-Reason'])).toBe('deneme anketi kaldirildi');
    expect(del.headers['Idempotency-Key']).toBeTruthy();
  });

  it('kapatma sebep ister ve POST /close gonderir', async () => {
    const calls = setup();
    renderWithProviders(<PollsAdminPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'anket-1' }));
    await screen.findByTestId('poll-detail');
    await userEvent.click(screen.getByRole('button', { name: 'Oylamayı kapat' }));
    const dialog = await screen.findByRole('dialog', { name: 'Anketi kapat' });
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'sure doldu erken kapatma');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Oylamayı kapat' }));
    await waitFor(() => expect(calls.some((c) => c.method === 'POST' && c.url === '/api/admin/polls/1/close')).toBe(true));
  });

  it('toplu islem: secim cubugu, sebep, POST /bulk govdesi ve sonuc bildirimi', async () => {
    const calls = setup();
    renderWithProviders(<PollsAdminPage />);
    await screen.findByText('anket-1');
    const boxes = screen.getAllByRole('checkbox', { name: 'Satırı seç' });
    await userEvent.click(boxes[0]);
    await userEvent.click(boxes[1]);
    expect(await screen.findByText('2 satır seçili')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Seçilenleri kapat' }));
    const dialog = await screen.findByRole('dialog', { name: 'Seçili anketleri kapat' });
    expect(within(dialog).getByText(/2 anket etkilenecek/)).toBeInTheDocument();
    await userEvent.type(within(dialog).getByLabelText(/^Sebep/), 'donem sonu toplu kapatma');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Oylamayı kapat' }));
    await waitFor(() => expect(calls.some((c) => c.url === '/api/admin/polls/bulk')).toBe(true));
    const b = calls.find((c) => c.url === '/api/admin/polls/bulk')!;
    expect(b.body).toEqual({ ids: [1, 2], action: 'CLOSE' });
    expect(decodeURIComponent(b.headers['X-Admin-Reason'])).toBe('donem sonu toplu kapatma');
    expect(await screen.findByText('2 anket işlendi, 0 anket atlandı.')).toBeInTheDocument();
  });

  it('CSV dugmesi export.csv ucunu cagirir', async () => {
    const calls = setup();
    vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: () => 'blob:x', revokeObjectURL: () => undefined }));
    renderWithProviders(<PollsAdminPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'anket-1' }));
    await screen.findByTestId('poll-detail');
    await userEvent.click(screen.getByRole('button', { name: 'CSV dışa aktar' }));
    await waitFor(() => expect(calls.some((c) => c.url === '/api/admin/polls/1/export.csv')).toBe(true));
  });

  it('bos baslikla kaydetmeyi engeller', async () => {
    const calls = setup();
    renderWithProviders(<PollsAdminPage />);
    await userEvent.click(await screen.findByTestId('poll-new'));
    await userEvent.click(screen.getByTestId('poll-save'));
    expect(await screen.findByText(/Başlık zorunludur/)).toBeInTheDocument();
    expect(calls.some((c) => c.method === 'POST')).toBe(false);
  });

  it('olusturma POST /api/polls govdesini gonderir (GLOBAL, taslak degil)', async () => {
    const calls = setup();
    renderWithProviders(<PollsAdminPage />);
    await userEvent.click(await screen.findByTestId('poll-new'));
    const form = await screen.findByRole('dialog');
    await userEvent.type(within(form).getByLabelText(/^Başlık/), 'Kampus kafe');
    await userEvent.type(within(form).getByLabelText('Seçenek 1'), 'Evet');
    await userEvent.type(within(form).getByLabelText('Seçenek 2'), 'Hayır');
    await userEvent.click(screen.getByTestId('poll-save'));
    await waitFor(() => expect(calls.some((c) => c.method === 'POST' && c.url === '/api/polls')).toBe(true));
    const c = calls.find((x) => x.method === 'POST' && x.url === '/api/polls')!;
    expect(c.body).toMatchObject({ title: 'Kampus kafe', scope: 'GLOBAL', type: 'SINGLE', options: ['Evet', 'Hayır'], draft: false });
    expect(headerOf({ headers: c.headers }, 'Authorization')).toBeUndefined();
  });

  it('duzenleme PATCH /api/polls/{id} ile yalniz degisen alani gonderir; oy alinmis ankette yapi kilitlidir', async () => {
    const calls = setup();
    renderWithProviders(<PollsAdminPage />);
    await userEvent.click(await screen.findByRole('button', { name: 'anket-1' }));
    await screen.findByTestId('poll-detail');
    await userEvent.click(screen.getByRole('button', { name: 'Düzenle' }));
    expect(await screen.findByText(/oy kullanılmış/)).toBeInTheDocument();
    expect(screen.getByLabelText('Anket türü')).toBeDisabled();
    const title = within(screen.getByRole('dialog')).getByLabelText(/^Başlık/);
    await userEvent.clear(title);
    await userEvent.type(title, 'yeni baslik');
    await userEvent.click(screen.getByTestId('poll-save'));
    await waitFor(() => expect(calls.some((c) => c.method === 'PATCH')).toBe(true));
    const p = calls.find((c) => c.method === 'PATCH')!;
    expect(p.url).toBe('/api/polls/1');
    expect(p.body).toEqual({ title: 'yeni baslik' });
  });
});
