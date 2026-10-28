import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import MessageAccessPage from './MessageAccessPage';

const access = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  adminId: 5,
  adminEmail: 'root@bingol.edu.tr',
  conversationId: 10,
  targetUserId: 1,
  kind: 'VIEW_MESSAGES',
  messageCount: 3,
  fromMessageId: 120,
  toMessageId: 122,
  reason: 'şikayet no 4521 incelemesi',
  ip: '10.0.0.7',
  at: '2026-10-28T09:10:00Z',
  ...over,
});

function setup(opts: { items?: unknown[]; fail?: boolean; totalPages?: number } = {}) {
  const calls: string[] = [];
  mockFetch((url) => {
    calls.push(url);
    if (url.includes('/admin/audit/message-access')) {
      if (opts.fail) return jsonResponse(503, { code: 'X', message: 'x' });
      const items = opts.items ?? [access(77), access(76, { kind: 'FEED', conversationId: null, targetUserId: null, messageCount: null, fromMessageId: null, toMessageId: null, reason: null, adminEmail: null })];
      return jsonResponse(200, { items, page: 0, totalPages: opts.totalPages ?? 1, totalItems: items.length });
    }
    if (url.includes('/admin/users')) return jsonResponse(200, { items: [{ id: 5, email: 'root@bingol.edu.tr' }], page: 0, size: 100, totalItems: 1, totalPages: 1 });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}
const last = (calls: string[]) => calls.filter((u) => u.includes('/message-access')).at(-1) ?? '';
const paramsOf = (u: string) => new URL(u, 'http://x').searchParams;

function renderPage(route = '/admin/audit/message-access') {
  return renderWithProviders(
    <Routes>
      <Route path="/admin/audit/message-access" element={<MessageAccessPage />} />
    </Routes>,
    { route },
  );
}

afterEach(() => cleanup());

describe('Mesaj erişim kayıtları', () => {
  it('kim, hangi kullanıcının hangi sohbetini, ne zaman, hangi sebeple açtı', async () => {
    setup();
    renderPage();
    await screen.findByText('şikayet no 4521 incelemesi');
    const rows = screen.getAllByRole('row').slice(1);
    expect(rows).toHaveLength(2);
    const r = within(rows[0]);
    expect(r.getByText('root@bingol.edu.tr')).toBeInTheDocument();
    expect(r.getByRole('link', { name: 'Kullanıcı 1' })).toHaveAttribute('href', '/admin/users/1');
    expect(r.getByRole('link', { name: 'Sohbet 10' })).toHaveAttribute('href', '/admin/users/1/messages?c=10');
    expect(r.getByText('Mesajlar')).toBeInTheDocument();
    expect(r.getByText('#120 – #122')).toBeInTheDocument();
    expect(r.getByText('10.0.0.7')).toBeInTheDocument();

    // toplu akış kaydı: kullanıcı/sohbet/aralık yok
    const feed = within(rows[1]);
    expect(feed.getByText('Toplu akış')).toBeInTheDocument();
    expect(feed.queryByRole('link')).toBeNull();
  });

  it('süzgeçler istek parametrelerine gider', async () => {
    const calls = setup();
    renderPage();
    await screen.findByText('şikayet no 4521 incelemesi');
    await userEvent.selectOptions(screen.getByLabelText('Erişim türü'), 'MEDIA');
    await userEvent.selectOptions(screen.getByLabelText('Yönetici'), '5');
    await userEvent.type(screen.getByLabelText('Kullanıcı kimliği'), '7');
    await userEvent.type(screen.getByLabelText('Sohbet kimliği'), '30');
    fireEvent.change(screen.getByLabelText('Başlangıç tarihi'), { target: { value: '2026-10-01' } });
    await userEvent.type(screen.getByRole('searchbox'), 'rapor');
    await waitFor(() =>
      expect(Object.fromEntries(paramsOf(last(calls)).entries())).toEqual({
        page: '0',
        size: '20',
        kind: 'MEDIA',
        adminId: '5',
        targetUserId: '7',
        conversationId: '30',
        from: '2026-10-01',
        q: 'rapor',
      }),
    );
    await userEvent.click(screen.getByRole('button', { name: 'Filtreleri temizle' }));
    await waitFor(() => expect(Object.fromEntries(paramsOf(last(calls)).entries())).toEqual({ page: '0', size: '20' }));
  });

  it('URL süzgeçleriyle açılır ve sayfalama çalışır', async () => {
    const calls = setup({ totalPages: 2 });
    renderPage('/admin/audit/message-access?targetUserId=9&kind=FEED');
    await screen.findByText('şikayet no 4521 incelemesi');
    expect(paramsOf(last(calls)).get('targetUserId')).toBe('9');
    expect(paramsOf(last(calls)).get('kind')).toBe('FEED');
    await userEvent.click(screen.getByRole('button', { name: 'Sonraki sayfa' }));
    await waitFor(() => expect(paramsOf(last(calls)).get('page')).toBe('1'));
    expect(paramsOf(last(calls)).get('targetUserId')).toBe('9');
  });

  it('boş ve hata durumları', async () => {
    setup({ items: [] });
    const first = renderPage();
    expect(await screen.findByText('Bu süzgeçlere uyan erişim kaydı yok')).toBeInTheDocument();
    first.unmount();
    setup({ fail: true });
    renderPage();
    expect(await screen.findByText('Mesaj erişim kayıtları yüklenemedi')).toBeInTheDocument();
  });
});
