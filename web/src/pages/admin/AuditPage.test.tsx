import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import AuditPage from './AuditPage';

const row = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  adminId: 5,
  adminEmail: 'root@bingol.edu.tr',
  method: 'PATCH',
  path: '/api/admin/users/3/role',
  status: 204,
  at: '2026-10-28T09:12:44Z',
  ip: '10.0.0.7',
  targetType: 'USER',
  targetId: '3',
  reason: 'yetki düzeltme talebi',
  summary: 'rol -> USER',
  requestId: '9c1f0a7e-1111-2222-3333-444455556666',
  ...over,
});

const ROWS = [
  row(981),
  row(980, {
    adminId: null,
    adminEmail: 'basic-admin',
    method: 'POST',
    path: '/api/admin/events/5/approve',
    targetType: 'EVENT',
    targetId: '5',
    reason: null,
    summary: null,
  }),
  // v1 (eski) satır: yeni alanlar yok
  {
    id: 12,
    adminId: 5,
    adminEmail: 'root@bingol.edu.tr',
    method: 'PUT',
    path: '/api/admin/settings/maintenance_mode',
    status: 403,
    at: '2026-01-02T08:00:00Z',
    ip: null,
  },
];

function page(items: unknown[], extra: Record<string, unknown> = {}) {
  return { items, page: 0, totalPages: 1, totalItems: items.length, ...extra };
}

function setup(opts: { items?: unknown[]; totalPages?: number; fail?: boolean } = {}) {
  const calls: string[] = [];
  mockFetch((url) => {
    calls.push(url);
    if (url.includes('/admin/audit/export.csv')) {
      return new Response(new Blob(['id,at\r\n1,2\r\n']), { status: 200, headers: { 'Content-Type': 'text/csv' } });
    }
    if (url.includes('/admin/audit')) {
      if (opts.fail) return jsonResponse(500, { code: 'X', message: 'x' });
      return jsonResponse(200, page(opts.items ?? ROWS, { totalPages: opts.totalPages ?? 1 }));
    }
    if (url.includes('/admin/users')) return jsonResponse(200, { items: [{ id: 5, email: 'root@bingol.edu.tr' }, { id: 6, email: 'ops@bingol.edu.tr' }], page: 0, size: 100, totalItems: 2, totalPages: 1 });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

const auditCalls = (calls: string[]) => calls.filter((u) => /\/admin\/audit\?/.test(u));
const lastAudit = (calls: string[]) => auditCalls(calls).at(-1) ?? '';
const paramsOf = (url: string) => new URL(url, 'http://x').searchParams;

/** Tablo verisi gelene dek bekler (başlık satırı hemen vardır) ve veri satırlarını döner. */
async function loadedRows() {
  await screen.findByText('Ayar değiştirildi');
  return screen.getAllByRole('row').slice(1);
}

function renderPage(route = '/admin/audit') {
  return renderWithProviders(
    <Routes>
      <Route path="/admin/audit" element={<AuditPage />} />
    </Routes>,
    { route },
  );
}

beforeEach(() => {
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: () => 'blob:csv', revokeObjectURL: () => {} }));
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('Denetim kaydı v2', () => {
  it('satırlar: insan okur işlem + ham yol, hedef bağlantısı, sebep, özet, durum, IP, istek kimliği', async () => {
    setup();
    renderPage();
    const rows = await loadedRows();
    expect(rows).toHaveLength(3);

    const first = within(rows[0]);
    expect(first.getByText('root@bingol.edu.tr')).toBeInTheDocument();
    expect(first.getByText('Kullanıcı rolü değiştirildi')).toBeInTheDocument();
    expect(first.getByText('/api/admin/users/3/role')).toBeInTheDocument();
    expect(first.getByRole('link', { name: /USER/ })).toHaveAttribute('href', '/admin/users/3');
    expect(first.getByText('yetki düzeltme talebi')).toBeInTheDocument();
    expect(first.getByText('rol -> USER')).toBeInTheDocument();
    expect(first.getByText('204')).toBeInTheDocument();
    expect(first.getByText('10.0.0.7')).toBeInTheDocument();
    expect(first.getByText('9c1f0a7e')).toBeInTheDocument();
    expect(first.getByRole('button', { name: 'İstek kimliğini kopyala' })).toBeInTheDocument();

    const second = within(rows[1]);
    expect(second.getByText('basic-admin')).toBeInTheDocument();
    expect(second.getByText('Etkinlik onaylandı')).toBeInTheDocument();
    expect(second.getByRole('link', { name: /EVENT/ })).toHaveAttribute('href', '/admin/events?open=5');

    // eski satır: hedef/sebep/özet/istek kimliği yok, 403 vurgulu
    const old = within(rows[2]);
    expect(old.getByText('Ayar değiştirildi')).toBeInTheDocument();
    expect(old.getByText('Yetkisiz')).toBeInTheDocument();
    expect(old.queryByRole('link')).toBeNull();
    expect(old.queryByRole('button', { name: 'İstek kimliğini kopyala' })).toBeNull();
  });

  it('süzgeçler istek parametrelerine ve URL’ye yansır (yöntem, durum, hedef türü, tarih, hedef kimliği, metin)', async () => {
    const calls = setup();
    renderPage();
    await loadedRows();
    expect(paramsOf(lastAudit(calls)).get('size')).toBe('20');
    expect(paramsOf(lastAudit(calls)).get('method')).toBeNull();

    await userEvent.selectOptions(screen.getByLabelText('Yöntem'), 'PATCH');
    await waitFor(() => expect(paramsOf(lastAudit(calls)).get('method')).toBe('PATCH'));
    await userEvent.selectOptions(screen.getByLabelText('Durum kodu'), '403');
    await userEvent.selectOptions(screen.getByLabelText('Hedef türü'), 'USER');
    await userEvent.selectOptions(screen.getByLabelText('Yönetici'), '6');
    fireEvent.change(screen.getByLabelText('Başlangıç tarihi'), { target: { value: '2026-10-01' } });
    fireEvent.change(screen.getByLabelText('Bitiş tarihi'), { target: { value: '2026-10-28' } });
    await userEvent.type(screen.getByLabelText('Hedef kimliği'), '42');
    await userEvent.type(screen.getByRole('searchbox'), 'rol');

    await waitFor(() => {
      const p = paramsOf(lastAudit(calls));
      expect(Object.fromEntries(p.entries())).toEqual({
        page: '0',
        size: '20',
        adminId: '6',
        method: 'PATCH',
        status: '403',
        targetType: 'USER',
        targetId: '42',
        from: '2026-10-01',
        to: '2026-10-28',
        q: 'rol',
      });
    });
    expect(screen.getByText('8 filtre etkin')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Filtreleri temizle' }));
    await waitFor(() => expect(Object.fromEntries(paramsOf(lastAudit(calls)).entries())).toEqual({ page: '0', size: '20' }));
    expect(screen.getByLabelText('Yöntem')).toHaveValue('');
    expect(screen.getByLabelText('Hedef kimliği')).toHaveValue('');
  });

  it('URL’deki süzgeçlerle açılır (paylaşılan bağlantı / AuditTrail “tümünü aç”)', async () => {
    const calls = setup();
    renderPage('/admin/audit?targetType=EVENT&targetId=5&status=4xx&page=1');
    await loadedRows();
    const p = paramsOf(lastAudit(calls));
    expect(p.get('targetType')).toBe('EVENT');
    expect(p.get('targetId')).toBe('5');
    expect(p.get('status')).toBe('4xx');
    expect(p.get('page')).toBe('1');
    expect(screen.getByLabelText('Hedef türü')).toHaveValue('EVENT');
    expect(screen.getByLabelText('Hedef kimliği')).toHaveValue('5');
  });

  it('sayfalama sonraki sayfayı ister', async () => {
    const calls = setup({ totalPages: 3 });
    renderPage();
    await loadedRows();
    await userEvent.click(screen.getByRole('button', { name: 'Sonraki sayfa' }));
    await waitFor(() => expect(paramsOf(lastAudit(calls)).get('page')).toBe('1'));
  });

  it('satıra tıklayınca ayrıntı çekmecesi tüm alanlarla açılır', async () => {
    setup();
    renderPage();
    const rows = await loadedRows();
    await userEvent.click(rows[0]);
    const drawer = await screen.findByTestId('audit-drawer');
    const d = within(drawer);
    expect(d.getByText('Kullanıcı rolü değiştirildi')).toBeInTheDocument();
    expect(d.getByText('yetki düzeltme talebi')).toBeInTheDocument();
    expect(d.getByText('rol -> USER')).toBeInTheDocument();
    expect(d.getByText('9c1f0a7e-1111-2222-3333-444455556666')).toBeInTheDocument();
    expect(d.getByRole('link', { name: 'Hedefi aç' })).toHaveAttribute('href', '/admin/users/3');
    expect(d.getByRole('link', { name: 'Bu hedefin diğer kayıtları' })).toHaveAttribute(
      'href',
      '/admin/audit?targetType=USER&targetId=3',
    );
    expect(d.getByRole('button', { name: 'İstek kimliğini kopyala' })).toBeInTheDocument();
  });

  it('basic-admin yöneticisi çekmecede uyarı rozetiyle gösterilir; eski satırda "eski kayıt" notu çıkar', async () => {
    setup();
    renderPage();
    const rows = await loadedRows();
    await userEvent.click(rows[1]);
    expect(within(await screen.findByTestId('audit-drawer')).getByText('Temel kimlik (basic-admin)')).toBeInTheDocument();
    await userEvent.keyboard('{Escape}');
    await waitFor(() => expect(screen.queryByTestId('audit-drawer')).toBeNull());
    await userEvent.click(rows[2]);
    expect(await screen.findByText('Eski kayıt: hedef, sebep ve özet bilgisi yok.')).toBeInTheDocument();
  });

  it('CSV dışa aktar: uyarı gösterilir, süzgeçlerle (sayfasız) export.csv istenir ve dosya indirilir', async () => {
    const calls = setup();
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
    renderPage('/admin/audit?method=POST&status=403&from=2026-10-01&targetType=USER');
    await loadedRows();
    await userEvent.click(screen.getByRole('button', { name: 'CSV dışa aktar' }));

    const dialog = await screen.findByRole('dialog', { name: 'CSV dışa aktar' });
    expect(dialog).toHaveTextContent('en çok 50.000 satır');
    expect(dialog).toHaveTextContent('denetim kaydına yazılır');
    expect(calls.some((u) => u.includes('export.csv'))).toBe(false);

    await userEvent.click(within(dialog).getByRole('button', { name: 'CSV dışa aktar' }));
    await waitFor(() => expect(calls.some((u) => u.includes('/admin/audit/export.csv'))).toBe(true));
    const url = calls.find((u) => u.includes('export.csv')) as string;
    expect(Object.fromEntries(paramsOf(url).entries())).toEqual({
      method: 'POST',
      status: '403',
      from: '2026-10-01',
      targetType: 'USER',
    });
    await waitFor(() => expect(click).toHaveBeenCalled());
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'CSV dışa aktar' })).toBeNull());
  });

  it('CSV hatasında diyalog açık kalır ve hata bildirilir', async () => {
    mockFetch((url) => {
      if (url.includes('export.csv')) return jsonResponse(429, { code: 'RATE_LIMITED', message: 'x' });
      if (url.includes('/admin/audit')) return jsonResponse(200, page(ROWS));
      return jsonResponse(200, { items: [], page: 0, size: 100, totalItems: 0, totalPages: 1 });
    });
    renderPage();
    await loadedRows();
    await userEvent.click(screen.getByRole('button', { name: 'CSV dışa aktar' }));
    const dialog = await screen.findByRole('dialog', { name: 'CSV dışa aktar' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'CSV dışa aktar' }));
    expect(await screen.findByText(/CSV oluşturulamadı/)).toBeInTheDocument();
    expect(screen.getByRole('dialog', { name: 'CSV dışa aktar' })).toBeInTheDocument();
  });

  it('sonuç yoksa boş durum, hata varsa hata durumu gösterir', async () => {
    setup({ items: [] });
    const first = renderPage('/admin/audit?q=yok');
    expect(await screen.findByText('Bu süzgeçlere uyan kayıt yok')).toBeInTheDocument();
    first.unmount();

    setup({ fail: true });
    renderPage();
    expect(await screen.findByText('Denetim kaydı yüklenemedi')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Tekrar dene|Yeniden dene/i })).toBeInTheDocument();
  });

  it('başlıkta mesaj erişim kayıtlarına bağlantı vardır', async () => {
    setup();
    renderPage();
    expect(await screen.findByRole('link', { name: 'Mesaj erişim kayıtları' })).toHaveAttribute('href', '/admin/audit/message-access');
  });
});
