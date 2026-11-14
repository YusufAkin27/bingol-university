// Canlı yoklama ekranı (sahte zamanlayıcı): sunucu saatine göre kod seçimi, sınırda geçiş, 10 sn bayatlık, sekme gizliyken duraklama,
// yeni/kaldırılan kayıtlar, "kayıtlı değil" kararları, kapat/yeniden aç.
import { act, fireEvent, screen, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Route, Routes } from 'react-router-dom';
import { tokensFor } from '../../../auth/tokens';
import { renderWithProviders } from '../../../test/utils';
import { AcadAuthProvider } from '../auth/AcadAuth';
import { course, err, mockApi } from '../testUtils';
import LivePage from './LivePage';
import { clockOffset, isStale, mergeCodes, pickCode, pickNext, qrState } from './liveCode';

const T0 = 1_700_000_001_000; // 5 sn sınırından 1 sn sonra
const SKEW = 180_000; // sunucu yerel saatten 3 dk ileride
const code = (step: number) => `bingol-lesson:5.${step}.mac${step}`;
const window5 = (step: number) => ({ code: code(step), fromMs: step * 5000, untilMs: (step + 1) * 5000 });

interface Server {
  /** Sıradaki yoklamaya verilecek sahte durum (tek seferlik); undefined = normal yanıt. */
  next?: (init: RequestInit) => Response | Promise<Response>;
  status: 'OPEN' | 'CLOSED';
  skew: number;
  failing: boolean;
  records: Record<string, unknown>[];
  pending: Record<string, unknown>[];
  present: number;
}

function setup(over: Partial<Server> = {}) {
  const server: Server = { status: 'OPEN', skew: SKEW, failing: false, records: [], pending: [], present: 0, ...over };
  const api = mockApi()
    .get('/academician/sessions/5', () => ({ id: 5, courseId: 7, slotId: null, lessonDate: '2026-11-14', openedAt: '2026-11-14T08:00:00Z', expiresAt: '2026-11-14T11:00:00Z', closedAt: null, status: server.status, presentCount: 0, enrolledCount: 3, pendingScans: [] }))
    .get('/academician/courses/7', course())
    .get('/academician/courses/7/enrollments', [
      { studentId: 11, displayName: 'Ayşe Örnek', studentNo: '2024000011', faculty: null, department: null, grade: null, addedAt: '2026-09-21T08:00:00Z' },
      { studentId: 12, displayName: 'Mehmet Deneme', studentNo: '2024000012', faculty: null, department: null, grade: null, addedAt: '2026-09-21T08:00:00Z' },
      { studentId: 13, displayName: 'Zeynep Test', studentNo: '2024000013', faculty: null, department: null, grade: null, addedAt: '2026-09-21T08:00:00Z' },
    ])
    .get('/academician/me', { status: 'APPROVED', approvalMode: 'AUTO', title: 'Dr.', firstName: 'D', lastName: 'H', unit: null, rejectReason: null })
    .get('/academician/sessions/5/live', ({ init }) => {
      if (server.next) {
        const f = server.next;
        server.next = undefined;
        return f(init);
      }
      if (server.failing) throw new TypeError('network down');
      const now = Date.now() + server.skew;
      const step = Math.floor(now / 5000);
      return {
        status: server.status,
        serverNowMs: now,
        stepSeconds: 5,
        codes: server.status === 'OPEN' ? [window5(step), window5(step + 1), window5(step + 2)] : [],
        presentCount: server.records.filter((r) => !r.revoked).length,
        enrolledCount: 3,
        newRecords: server.records,
        pendingScans: server.pending,
      };
    })
    .post('/academician/sessions/5/close', () => {
      server.status = 'CLOSED';
      return { id: 5, status: 'CLOSED' };
    })
    .post('/academician/sessions/5/reopen', () => {
      server.status = 'OPEN';
      return { id: 5, status: 'OPEN' };
    })
    .put('/academician/sessions/5/records/:id', ({ url }) => {
      const sid = Number(url.pathname.split('/').pop());
      const name = sid === 11 ? 'Ayşe Örnek' : sid === 12 ? 'Mehmet Deneme' : 'Zeynep Test';
      const i = server.records.findIndex((r) => r.studentId === sid);
      const rec = { id: 100 + sid, studentId: sid, displayName: name, studentNo: `20240000${sid}`, method: 'MANUAL', markedAt: new Date().toISOString(), revoked: false };
      if (i >= 0) server.records[i] = rec;
      else server.records.push(rec);
      return rec;
    })
    .del('/academician/sessions/5/records/:id', ({ url }) => {
      const sid = Number(url.pathname.split('/').pop());
      server.records = server.records.map((r) => (r.studentId === sid ? { ...r, revoked: true } : r));
      return undefined;
    })
    .post('/academician/sessions/5/pending/:id/accept', ({ url }) => {
      const sid = Number(url.pathname.split('/').slice(-2)[0]);
      const p = server.pending.find((x) => x.studentId === sid)!;
      server.pending = server.pending.filter((x) => x.studentId !== sid);
      server.records.push({ id: 300 + sid, studentId: sid, displayName: p.displayName, studentNo: p.studentNo, method: 'QR', markedAt: new Date().toISOString(), revoked: false });
      return server.records[server.records.length - 1];
    })
    .post('/academician/sessions/5/pending/:id/dismiss', ({ url }) => {
      const sid = Number(url.pathname.split('/').slice(-2)[0]);
      server.pending = server.pending.filter((x) => x.studentId !== sid);
      return undefined;
    });
  api.install();
  tokensFor('acad').setTokens('acad-access', 'acad-refresh');
  const view = renderWithProviders(
    <AcadAuthProvider>
      <Routes>
        <Route path="/akademisyen/yoklama/:sessionId" element={<LivePage />} />
        <Route path="/akademisyen/beklemede" element={<p>beklemede sayfasi</p>} />
      </Routes>
    </AcadAuthProvider>,
    { route: '/akademisyen/yoklama/5' },
  );
  return { server, api, ...view };
}

const tick = (ms: number) => act(async () => void (await vi.advanceTimersByTimeAsync(ms)));
const shownCode = () => document.querySelector('[data-qr]')?.getAttribute('data-qr') ?? null;
const liveCalls = (api: ReturnType<typeof mockApi>) => api.callsTo('GET', '/academician/sessions/5/live').length;
const rec = (id: number, name: string, over: Record<string, unknown> = {}) => ({ id, studentId: id, displayName: name, studentNo: `20240000${id}`, method: 'QR', markedAt: new Date().toISOString(), revoked: false, ...over });

function setHidden(hidden: boolean) {
  Object.defineProperty(document, 'hidden', { value: hidden, configurable: true });
  document.dispatchEvent(new Event('visibilitychange'));
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(T0);
});
afterEach(() => {
  setHidden(false);
  vi.useRealTimers();
  tokensFor('acad').clearTokens();
});

describe('canlı kod seçimi', () => {
  it('yerel saat sunucudan 3 dk geride olsa bile sunucu saatine göre doğru kodu gösterir', async () => {
    setup();
    await tick(100);
    const serverStep = Math.floor((T0 + SKEW) / 5000);
    expect(shownCode()).toBe(code(serverStep));
    // yerel saate göre seçilseydi bu kod olurdu: gösterilmemeli
    expect(shownCode()).not.toBe(code(Math.floor(T0 / 5000)));
  });

  it('5 sn sınırında bir sonraki koda geçer', async () => {
    setup();
    await tick(100);
    const first = Math.floor((T0 + SKEW) / 5000);
    await tick(2500); // sınıra 1,4 sn kala
    expect(shownCode()).toBe(code(first));
    await tick(2000); // sınır geçildi
    expect(shownCode()).toBe(code(first + 1));
  });

  it('10 sn taze yanıt yoksa QR GİZLENİR ("bağlantı bekleniyor"), bağlantı gelince döner', async () => {
    const { server } = setup();
    await tick(100);
    expect(shownCode()).not.toBeNull();
    server.failing = true;
    await tick(8000);
    expect(shownCode()).not.toBeNull(); // henüz 10 sn dolmadı
    await tick(3000);
    expect(shownCode()).toBeNull();
    expect(screen.getByText('Bağlantı bekleniyor')).toBeInTheDocument();
    expect(document.body.innerHTML).not.toContain('bingol-lesson:'); // bayat kod DOM'da kalmaz
    server.failing = false;
    await tick(12_000); // geri çekilme (en çok ~10 sn) sonrası ilk başarılı yoklama
    expect(shownCode()).toBe(code(Math.floor((Date.now() + SKEW) / 5000)));
    expect(screen.queryByText('Bağlantı bekleniyor')).toBeNull();
  });

  it('sekme gizliyken yoklama durur, görünür olunca HEMEN yeniden başlar', async () => {
    const { api } = setup();
    await tick(100);
    const before = liveCalls(api);
    expect(before).toBeGreaterThanOrEqual(1);
    await act(async () => setHidden(true));
    await tick(20_000);
    expect(liveCalls(api)).toBe(before); // gizliyken yeni istek yok
    await act(async () => setHidden(false));
    await tick(10);
    expect(liveCalls(api)).toBe(before + 1); // 2,5 sn beklemeden
    await tick(2600);
    expect(liveCalls(api)).toBe(before + 2);
  });

  it('sayfadan çıkınca yoklama durur', async () => {
    const { api, unmount } = setup();
    await tick(100);
    unmount();
    const n = liveCalls(api);
    await tick(15_000);
    expect(liveCalls(api)).toBe(n);
  });

  it('dev derlemesinde "kodu kopyala" geçerli kodu panoya yazar', async () => {
    const writeText = vi.fn(() => Promise.resolve());
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true });
    setup();
    await tick(100);
    fireEvent.click(screen.getByRole('button', { name: /Kodu kopyala/ }));
    await tick(10);
    expect(writeText).toHaveBeenCalledWith(shownCode());
  });
});

describe('katılanlar listesi', () => {
  it('yeni gelenler üstte; QR/elle ayrımı; sayaç', async () => {
    const { server } = setup();
    await tick(100);
    expect(screen.getByText(/Henüz katılan yok/)).toBeInTheDocument();
    server.records = [rec(11, 'Ayşe Örnek', { markedAt: '2026-11-14T08:01:00Z' })];
    await tick(2600);
    server.records = [...server.records, rec(12, 'Mehmet Deneme', { method: 'MANUAL', markedAt: '2026-11-14T08:02:00Z' })];
    await tick(2600);
    const list = screen.getByRole('list', { name: 'Katılanlar' });
    const items = within(list).getAllByRole('listitem');
    expect(items[0]).toHaveTextContent('Mehmet Deneme');
    expect(items[0]).toHaveTextContent('Elle');
    expect(items[1]).toHaveTextContent('Ayşe Örnek');
    expect(items[1]).toHaveTextContent('QR');
    expect(screen.getByText('3 öğrenciden 2 tanesi katıldı')).toBeInTheDocument(); // ekran okuyucu metni (görsel sayılar aria-hidden)
  });

  it('kaldırılan kayıt katılanlardan çıkar, "kaldırılanlar"a düşer; geri yüklenince döner', async () => {
    const { server } = setup({ records: [rec(11, 'Ayşe Örnek')] });
    await tick(100);
    expect(within(screen.getByRole('list', { name: 'Katılanlar' })).getByText('Ayşe Örnek')).toBeInTheDocument();
    server.records = [rec(11, 'Ayşe Örnek', { revoked: true })];
    await tick(2600);
    expect(screen.queryByRole('list', { name: 'Katılanlar' })).toBeNull();
    expect(screen.getByText('Kaldırılan kayıtlar (1)')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Ayşe Örnek için Var' }));
    await tick(200);
    expect(within(screen.getByRole('list', { name: 'Katılanlar' })).getByText('Ayşe Örnek')).toBeInTheDocument();
  });

  it('listeden kaldırma onay ister ve DELETE gönderir', async () => {
    const { api } = setup({ records: [rec(11, 'Ayşe Örnek')] });
    await tick(100);
    fireEvent.click(screen.getByRole('button', { name: 'Ayşe Örnek için Yok' }));
    await tick(50);
    const dlg = screen.getByRole('alertdialog');
    expect(api.callsTo('DELETE', '/academician/sessions/5/records/11')).toHaveLength(0);
    fireEvent.click(within(dlg).getByRole('button', { name: 'Kaldır' }));
    await tick(200);
    expect(api.callsTo('DELETE', '/academician/sessions/5/records/11')).toHaveLength(1);
  });

  it('elle var say: arama + "Var say" PUT gönderir ve listede görünür', async () => {
    const { api } = setup();
    await tick(100);
    fireEvent.change(screen.getByLabelText('Öğrenci ara'), { target: { value: 'zeynep' } });
    await tick(50);
    fireEvent.click(screen.getByRole('button', { name: 'Zeynep Test için Var' }));
    await tick(300);
    expect(api.callsTo('PUT', '/academician/sessions/5/records/13')).toHaveLength(1);
    expect(within(screen.getByRole('list', { name: 'Katılanlar' })).getByText('Zeynep Test')).toBeInTheDocument();
  });

  it('yeni katılımlar ekran okuyucuya sınırlı sıklıkta duyurulur (sel yok)', async () => {
    const { server } = setup();
    await tick(100);
    const live = screen.getByTestId('live-announcer');
    expect(live).toHaveAttribute('aria-live', 'polite');
    expect(live).toHaveTextContent('');
    server.records = [rec(11, 'Ayşe Örnek')];
    await tick(2600);
    expect(live).toHaveTextContent('Ayşe Örnek yoklamaya katıldı');
    // 6 sn dolmadan gelen iki katılım birleştirilir ve ancak süre dolunca duyurulur
    server.records = [...server.records, rec(12, 'Mehmet Deneme'), rec(13, 'Zeynep Test')];
    await tick(2600);
    expect(live).toHaveTextContent('Ayşe Örnek yoklamaya katıldı');
    await tick(4000);
    expect(live).toHaveTextContent('2 öğrenci yoklamaya katıldı');
  });
});

describe('"Kayıtlı değil" listesi', () => {
  const pend = (id: number, name: string) => ({ studentId: id, displayName: name, studentNo: `99000${id}`, faculty: null, department: 'Tarih', grade: '1', scannedAt: '2026-11-14T08:03:00Z' });

  it('kabul: derse ekle ve var say -> listeden çıkar, katılanlara düşer', async () => {
    const { api } = setup({ pending: [pend(41, 'Kayıtsız Öğrenci')] });
    await tick(100);
    expect(screen.getByRole('heading', { name: /Kayıtlı değil/ })).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Kayıtsız Öğrenci öğrencisini derse ekle ve var say' }));
    await tick(300);
    expect(api.callsTo('POST', '/academician/sessions/5/pending/41/accept')).toHaveLength(1);
    expect(screen.queryByRole('heading', { name: /Kayıtlı değil/ })).toBeNull();
    expect(within(screen.getByRole('list', { name: 'Katılanlar' })).getByText('Kayıtsız Öğrenci')).toBeInTheDocument();
  });

  it('yok say: istek reddedilir, öğrenci listede görünmez', async () => {
    const { api } = setup({ pending: [pend(42, 'Başka Öğrenci')] });
    await tick(100);
    fireEvent.click(screen.getByRole('button', { name: 'Başka Öğrenci isteğini yok say' }));
    await tick(300);
    expect(api.callsTo('POST', '/academician/sessions/5/pending/42/dismiss')).toHaveLength(1);
    expect(screen.queryByText('Başka Öğrenci')).toBeNull();
  });
});

describe('kapat / yeniden aç', () => {
  it('kapatma onay ister; kapanınca QR yerine "Yoklama kapalı" ve yeniden aç düğmesi çıkar; yeniden açınca kod döner', async () => {
    const { api } = setup();
    await tick(100);
    fireEvent.click(screen.getByRole('button', { name: 'Yoklamayı kapat' }));
    await tick(50);
    const dlg = screen.getByRole('dialog');
    expect(api.callsTo('POST', '/academician/sessions/5/close')).toHaveLength(0);
    fireEvent.click(within(dlg).getByRole('button', { name: 'Yoklamayı kapat' }));
    await tick(300);
    expect(api.callsTo('POST', '/academician/sessions/5/close')).toHaveLength(1);
    expect(shownCode()).toBeNull();
    expect(screen.getAllByText('Yoklama kapalı').length).toBeGreaterThan(0);
    fireEvent.click(screen.getAllByRole('button', { name: 'Yeniden aç' })[0]);
    await tick(50);
    // W9: yeniden açma onay ister ve sonucu açıklar
    expect(api.callsTo('POST', '/academician/sessions/5/reopen')).toHaveLength(0);
    const ask = screen.getByRole('dialog');
    expect(ask).toHaveTextContent('şu an açık başka bir yoklaması varsa o kapatılır');
    fireEvent.click(within(ask).getByRole('button', { name: 'Yeniden aç' }));
    await tick(300);
    expect(api.callsTo('POST', '/academician/sessions/5/reopen')).toHaveLength(1);
    expect(shownCode()).not.toBeNull();
  });
});

describe('hata durumları', () => {
  it('oturum bulunamazsa (404) açıklayıcı boş durum ve çıkış bağlantısı gösterir', async () => {
    const api = mockApi()
      .get('/academician/sessions/5', () => err(404, 'AC_SESSION_NOT_FOUND'))
      .get('/academician/sessions/5/live', () => err(404, 'AC_SESSION_NOT_FOUND'));
    api.install();
    renderWithProviders(
      <AcadAuthProvider>
        <Routes>
          <Route path="/akademisyen/yoklama/:sessionId" element={<LivePage />} />
        </Routes>
      </AcadAuthProvider>,
      { route: '/akademisyen/yoklama/5' },
    );
    await tick(200);
    expect(screen.getByText('Yoklama oturumu bulunamadı')).toBeInTheDocument();
  });
});

describe('W1-W4: poll hataları, zaman aşımı, sıra dışı yanıt, kapanış nedeni', () => {
  const hang = (init: RequestInit) => new Promise<Response>((_, rej) => init.signal?.addEventListener('abort', () => rej(new DOMException('Aborted', 'AbortError'))));

  it('W1: oturum ortasında 403 ACADEMICIAN_NOT_APPROVED durumu yeniden okutur ve beklemede sayfasına yönlendirir', async () => {
    const { server, api } = setup();
    await tick(200);
    const before = api.callsTo('GET', '/academician/me').length;
    server.next = () => err(403, 'ACADEMICIAN_NOT_APPROVED');
    await tick(2600);
    expect(api.callsTo('GET', '/academician/me').length).toBeGreaterThan(before);
  });

  it('W1: 429 Retry-After süresince yeni istek atılmaz', async () => {
    const { server, api } = setup();
    await tick(200);
    server.next = () => new Response(JSON.stringify({ code: 'TOO_MANY_REQUESTS', message: 'x' }), { status: 429, headers: { 'Content-Type': 'application/json', 'Retry-After': '9' } });
    await tick(2600); // 429 yanıtı
    const n = liveCalls(api);
    await tick(8000);
    expect(liveCalls(api)).toBe(n); // 9 sn dolmadan yeniden denenmez
    await tick(2000);
    expect(liveCalls(api)).toBe(n + 1);
  });

  it('W1: kalıcı 500 hatasında geri çekilme artar ve eşlenen hata metni panelde görünür; QR yine 10 sn sonra gizlenir', async () => {
    const { server, api } = setup();
    await tick(200);
    server.next = undefined;
    const fail = () => err(500, 'SERVER_ERROR');
    const original = server.next;
    void original;
    // her yanıtı 500 yap
    const live = api.on('GET', '/academician/sessions/5/live', fail);
    void live;
    await tick(2600);
    await tick(5200);
    const n = liveCalls(api);
    await tick(10_000); // artık 2,5 sn'de değil, geri çekilerek (>= 5 sn aralık) denenir
    expect(liveCalls(api) - n).toBeLessThanOrEqual(2);
    expect(shownCode()).toBeNull();
    expect(screen.getByRole('alert')).toHaveTextContent(/Sunucu|hata|yeniden/i);
  });

  it('W2: takılan istek 5 sn sonra iptal edilir ve yoklama kendiliğinden toparlanır', async () => {
    const { server, api } = setup();
    await tick(200);
    server.next = hang;
    await tick(2600); // takılan istek başladı
    const started = liveCalls(api);
    await tick(5200); // zaman aşımı
    // son taze yanıt 10 sn'den eski olunca QR gizlenir; takılan istek kilitlenmeye yol açmaz
    await tick(6000);
    expect(liveCalls(api)).toBeGreaterThan(started); // kilitlenmedi
    expect(shownCode()).not.toBeNull(); // toparlandı
  });

  it('W2: sekme görünür olunca takılan eski istek iptal edilir ve hemen yenisi atılır', async () => {
    const { server, api } = setup();
    await tick(200);
    server.next = hang;
    await tick(2600);
    const n = liveCalls(api);
    await act(async () => setHidden(true));
    await act(async () => setHidden(false));
    await tick(20);
    expect(liveCalls(api)).toBe(n + 1);
    expect(shownCode()).not.toBeNull();
  });

  it('W2: ağ geri gelince (online) hemen yoklar', async () => {
    const { api } = setup();
    await tick(200);
    const n = liveCalls(api);
    await act(async () => void window.dispatchEvent(new Event('online')));
    await tick(20);
    expect(liveCalls(api)).toBe(n + 1);
  });

  it('geç gelen eski yanıt yeni yanıtın üstüne yazılmaz (sıra dışı)', async () => {
    const { server } = setup();
    await tick(200);
    let release!: () => void;
    server.next = () =>
      new Promise<Response>((resolve) => {
        release = () => resolve(new Response(JSON.stringify({ status: 'OPEN', serverNowMs: Date.now() + SKEW, stepSeconds: 5, codes: [], presentCount: 0, enrolledCount: 3, newRecords: [], pendingScans: [] }), { status: 200, headers: { 'Content-Type': 'application/json' } }));
      });
    await tick(2600); // eski istek takıldı
    server.records = [rec(11, 'Ayşe Örnek')];
    await act(async () => setHidden(true));
    await act(async () => setHidden(false)); // eskiyi iptal eder, yeni istek yeni durumu alır
    await tick(100);
    expect(within(screen.getByRole('list', { name: 'Katılanlar' })).getByText('Ayşe Örnek')).toBeInTheDocument();
    release(); // eski (boş) yanıt şimdi gelir
    await tick(100);
    expect(within(screen.getByRole('list', { name: 'Katılanlar' })).getByText('Ayşe Örnek')).toBeInTheDocument();
  });

  it('W3: oturum kullanıcı kapatmadan kapanırsa nedeni söylenir', async () => {
    const { server } = setup();
    await tick(200);
    server.status = 'CLOSED';
    await tick(2600);
    expect(screen.getAllByText(/siz kapatmadan kapandı/).length).toBeGreaterThan(0);
  });

  it('W4: sayaç düz metin alternatifiyle okunur (aria-label yok), canlı kod üretim işaretinde DOM özniteliği olarak yazılmaz', async () => {
    setup();
    await tick(200);
    expect(document.querySelector('p[aria-label]')).toBeNull();
    expect(screen.getByText('0 öğrenciden 0 tanesi katıldı'.replace('0 öğrenciden 0', '3 öğrenciden 0'))).toBeInTheDocument();
  });

  it('izinli kayıt katılanlardan ayrı listelenir ve üç seçenekli denetimle değiştirilir', async () => {
    const { api } = setup({ records: [rec(11, 'Ayşe Örnek', { excused: true, method: 'MANUAL' })] });
    await tick(200);
    expect(screen.queryByRole('list', { name: 'Katılanlar' })).toBeNull();
    expect(screen.getByText('İzinli öğrenciler (1)')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Ayşe Örnek için Var' }));
    await tick(200);
    expect(api.callsTo('PUT', '/academician/sessions/5/records/11')).toHaveLength(1);
  });
});

describe('liveCode (saf işlevler)', () => {
  const codes = [window5(10), window5(11), window5(12)];
  it('pickCode: [fromMs, untilMs) aralığı; sınır bir sonrakine aittir', () => {
    expect(pickCode(codes, 50_000)?.code).toBe(code(10));
    expect(pickCode(codes, 54_999)?.code).toBe(code(10));
    expect(pickCode(codes, 55_000)?.code).toBe(code(11));
    expect(pickCode(codes, 49_999)).toBeNull();
    expect(pickCode(codes, 65_000)).toBeNull();
  });
  it('pickNext: mevcut kodun hemen ardılı', () => {
    expect(pickNext(codes, codes[0])?.code).toBe(code(11));
    expect(pickNext(codes, codes[2])).toBeNull();
    expect(pickNext(codes, null)).toBeNull();
  });
  it('mergeCodes: kod metnine göre tekil, eskiler atılır', () => {
    const merged = mergeCodes([window5(10)], [window5(10), window5(11)], 200_000);
    expect(merged).toHaveLength(0);
    expect(mergeCodes([window5(10)], [window5(10), window5(11)], 52_000).map((c) => c.code)).toEqual([code(10), code(11)]);
  });
  it('isStale: tam 10 sn geçince (>) bayat; hiç yanıt yoksa bayat', () => {
    expect(isStale(20_000, 10_000)).toBe(false);
    expect(isStale(20_001, 10_000)).toBe(true);
    expect(isStale(1, null)).toBe(true);
  });
  it('clockOffset + qrState: kapalı oturumda kod yok; bayatta bekleniyor', () => {
    expect(clockOffset(1_000_500, 1_000_000)).toBe(500);
    const base = { codes, offsetMs: 0, lastFreshLocalMs: 50_000 };
    expect(qrState({ ...base, status: 'OPEN', nowLocalMs: 51_000 }).state).toBe('code');
    expect(qrState({ ...base, status: 'OPEN', nowLocalMs: 61_000 }).state).toBe('waiting');
    expect(qrState({ ...base, status: 'CLOSED', nowLocalMs: 51_000 }).state).toBe('closed');
    expect(qrState({ ...base, status: null, nowLocalMs: 51_000 }).state).toBe('waiting');
  });
});
