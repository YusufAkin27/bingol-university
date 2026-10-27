import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes, useLocation } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import LegacyMessageRedirect from './chat/LegacyMessageRedirect';
import UserMessagesPage from './UserMessagesPage';

const USER = { id: 7, displayName: 'Ayşe Demir', avatarUrl: null };
const PEER = { id: 8, displayName: 'Mehmet Kaya', avatarUrl: null };

const msg = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  conversationId: 30,
  senderId: 7,
  senderName: 'Ayşe Demir',
  mine: true,
  createdAt: '2026-02-01T10:00:00Z',
  text: `mesaj-${id}`,
  error: null,
  edited: false,
  editedAt: null,
  revisions: [],
  deleted: false,
  deletedAt: null,
  deletedBy: null,
  deletedByName: null,
  hidden: false,
  suppressed: false,
  status: null,
  replyTo: null,
  reactions: [],
  attachments: [],
  ...over,
});

const att = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  kind: 'IMAGE',
  contentType: 'image/jpeg',
  width: 640,
  height: 480,
  durationMs: null,
  bytes: 2048,
  viewOnce: false,
  viewedBy: [],
  purged: false,
  hidden: false,
  messageDeleted: false,
  previewUrl: `/api/admin/media/attachments/${id}/preview`,
  thumbUrl: `/api/admin/media/attachments/${id}/preview?thumb=true`,
  ...over,
});

const conv = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  type: 'DIRECT',
  title: null,
  peer: PEER,
  memberCount: 2,
  totalMessages: 120,
  lastActivityAt: '2026-02-01T10:00:00Z',
  left: false,
  state: { hiddenByUser: false, cleared: false, archived: false, muted: false },
  lastMessage: {
    id: 99,
    senderId: 8,
    mine: false,
    text: 'son mesaj önizleme',
    error: null,
    deleted: false,
    hidden: false,
    suppressed: false,
    createdAt: '2026-02-01T10:00:00Z',
  },
  ...over,
});

const CONVS = {
  user: USER,
  items: [
    conv(30),
    conv(31, {
      peer: { id: 9, displayName: 'Zeynep Arslan', avatarUrl: null },
      left: true,
      state: { hiddenByUser: true, cleared: false, archived: true, muted: false },
      lastMessage: { id: 120, senderId: 9, mine: false, text: 'gizli önizleme', error: null, deleted: false, hidden: false, suppressed: true, createdAt: '2026-02-01T10:00:00Z' },
    }),
  ],
  nextCursor: null,
};

const INFO = { id: 30, type: 'DIRECT', title: null, peer: PEER, left: false };

function setup(opts: { messagesError?: boolean; messages?: unknown[]; pages?: Record<string, unknown> } = {}) {
  const calls: string[] = [];
  mockFetch((url) => {
    calls.push(url);
    if (url.includes('/media/attachments/')) return new Response(new Blob(['x']), { status: 200, headers: { 'Content-Type': 'image/jpeg' } });
    if (url.includes('/conversations/30/messages')) {
      if (opts.messagesError) return jsonResponse(503, { code: 'CRYPTO_UNAVAILABLE', message: 'x' });
      const key = /before=(\d+)/.exec(url)?.[1];
      if (key && opts.pages?.[key]) return jsonResponse(200, opts.pages[key]);
      if (key === '61') {
        return jsonResponse(200, {
          user: USER,
          conversation: INFO,
          items: [msg(59, { text: 'eski-59' }), msg(60, { text: 'eski-60', mine: false, senderId: 8, senderName: 'Mehmet Kaya' })],
          nextBefore: null,
        });
      }
      return jsonResponse(200, {
        user: USER,
        conversation: INFO,
        items: opts.messages ?? [
          msg(61, { text: 'benim mesajim', status: 'READ' }),
          msg(62, { text: 'karsi taraf', mine: false, senderId: 8, senderName: 'Mehmet Kaya' }),
          msg(63, { text: 'gizli silinen', deleted: true, deletedAt: '2026-02-02T10:00:00Z', deletedBy: 8, deletedByName: 'Mehmet Kaya' }),
          msg(64, { text: 'yeni metin', edited: true, revisions: [{ text: 'eski metin', error: null, revisedAt: '2026-02-01T10:01:00Z' }] }),
          msg(65, { text: 'engelli mesaj', suppressed: true, blockedBy: PEER }),
        ],
        nextBefore: 61,
      });
    }
    if (url.includes('/conversations')) return jsonResponse(200, CONVS);
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

function renderPage(route = '/admin/users/7/messages?c=30', lang: 'tr' | 'ar' = 'tr') {
  return renderWithProviders(
    <Routes>
      <Route path="/admin/users/:id/messages" element={<UserMessagesPage />} />
    </Routes>,
    { route, lang },
  );
}

beforeEach(() => {
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: () => 'blob:test', revokeObjectURL: () => {} }));
});
afterEach(() => vi.unstubAllGlobals());

describe('Kullanıcı mesajları sayfası', () => {
  it('tüm sohbetleri durum rozetleriyle gösterir (silinmiş, ayrılmış, arşivli, gölge engelli)', async () => {
    setup();
    renderPage('/admin/users/7/messages');
    const list = await screen.findByTestId('conversation-list');
    expect(within(list).getByText('Mehmet Kaya')).toBeInTheDocument();
    expect(within(list).getByText('son mesaj önizleme')).toBeInTheDocument();
    expect(within(list).getAllByText('120 mesaj').length).toBe(2);
    expect(within(list).getByTestId('conv-badge-deleted')).toHaveTextContent('Silinmiş');
    expect(within(list).getByTestId('conv-badge-left')).toHaveTextContent('Ayrıldı');
    expect(within(list).getByTestId('conv-badge-archived')).toBeInTheDocument();
    expect(within(list).getByTestId('conv-badge-shadow')).toHaveTextContent('Gölge engelli');
    expect(screen.getByText('Soldan bir sohbet seçin')).toBeInTheDocument();
    expect(screen.getByTestId('audit-note')).toHaveTextContent('denetim kaydına yazılır');
  });

  it('sohbet listesini istemci tarafında arar', async () => {
    setup();
    renderPage('/admin/users/7/messages');
    await screen.findByTestId('conversation-list');
    await userEvent.type(screen.getByRole('searchbox', { name: 'Sohbetlerde ara' }), 'zeynep');
    const list = screen.getByTestId('conversation-list');
    expect(within(list).queryByText('Mehmet Kaya')).toBeNull();
    expect(within(list).getByText('Zeynep Arslan')).toBeInTheDocument();
  });

  it('diğer kullanıcıların mesajları ayrı yanda; silinen, düzenlenen, gölge engelli ve makbuz gösterilir', async () => {
    setup();
    renderPage();
    const bubbles = await screen.findAllByTestId('chat-bubble');
    expect(bubbles.map((b) => b.getAttribute('data-side'))).toEqual(['self', 'peer', 'self', 'self', 'self']);

    const deleted = bubbles[2];
    expect(deleted.getAttribute('data-deleted')).toBe('true');
    expect(within(deleted).getByText('gizli silinen')).toBeInTheDocument();
    expect(within(deleted).getByTestId('deleted-badge')).toHaveTextContent('Silindi');
    expect(within(deleted).getByTestId('deleted-info')).toHaveTextContent('Mehmet Kaya');
    expect(within(bubbles[0]).queryByTestId('deleted-badge')).toBeNull();
    expect(within(bubbles[0]).getByTestId('receipt')).toHaveAttribute('aria-label', 'Okundu');

    expect(within(bubbles[3]).getByText('Düzenlendi')).toBeInTheDocument();
    expect(within(bubbles[3]).getByText('eski metin')).toBeInTheDocument();

    expect(within(bubbles[4]).getByTestId('suppressed-badge')).toHaveTextContent('Alıcıya iletilmedi (engel)');
    expect(within(bubbles[4]).getByText('Engelleyen: Mehmet Kaya')).toBeInTheDocument();
  });

  it('Arapçada aynı yön işaretleri korunur (ayna CSS mantıksal özelliklerle yapılır)', async () => {
    setup();
    renderPage('/admin/users/7/messages?c=30', 'ar');
    const bubbles = await screen.findAllByTestId('chat-bubble');
    expect(bubbles.map((b) => b.getAttribute('data-side'))).toEqual(['self', 'peer', 'self', 'self', 'self']);
  });

  it('yukarı kaydırınca before imleciyle eski sayfayı yükler ve başa ekler', async () => {
    const calls = setup();
    renderPage();
    await screen.findAllByTestId('chat-bubble');
    expect(calls.some((u) => u.includes('before='))).toBe(false);

    fireEvent.scroll(screen.getByTestId('message-scroller'), { target: { scrollTop: 0 } });

    await waitFor(() => expect(screen.getByText('eski-59')).toBeInTheDocument());
    expect(calls.some((u) => u.includes('before=61'))).toBe(true);
    const texts = screen.getAllByTestId('chat-bubble').map((b) => b.textContent ?? '');
    expect(texts[0]).toContain('eski-59');
    expect(texts[1]).toContain('eski-60');
    expect(texts[2]).toContain('benim mesajim');
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Daha eski mesajları yükle' })).toBeNull());
  });

  it('düğmeyle de eski mesajları yükler', async () => {
    const calls = setup();
    renderPage();
    await screen.findAllByTestId('chat-bubble');
    await userEvent.click(screen.getByRole('button', { name: 'Daha eski mesajları yükle' }));
    await waitFor(() => expect(calls.some((u) => u.includes('before=61'))).toBe(true));
  });

  it('?m= hedef mesaj ilk sayfada yoksa eski sayfaları yükler ve mesajı vurgular', async () => {
    const calls = setup();
    renderPage('/admin/users/7/messages?c=30&m=59');
    await waitFor(() => expect(calls.some((u) => u.includes('before=61'))).toBe(true));
    const target = await screen.findByText('eski-59');
    const bubble = target.closest('[data-testid="chat-bubble"]') as HTMLElement;
    await waitFor(() => expect(bubble.getAttribute('data-highlighted')).toBe('true'));
    // diğerleri vurgulanmaz
    expect(screen.getByText('benim mesajim').closest('[data-testid="chat-bubble"]')?.getAttribute('data-highlighted')).toBeNull();
  });

  it('?m= hedefi hiç bulunamazsa bilgi notu gösterir', async () => {
    setup();
    renderPage('/admin/users/7/messages?c=30&m=5');
    expect(await screen.findByTestId('target-missing')).toBeInTheDocument();
  });

  it('tek gönderimlik ek: rozet, "Açan" bilgisi; saklama süresi dolan ek ayrıca işaretlenir; lightbox gezinir ve kapanır', async () => {
    setup({
      messages: [
        msg(70, {
          text: 'foto',
          attachments: [
            att(1, { viewOnce: true, viewedBy: [{ id: 8, displayName: 'Mehmet Kaya', at: '2026-02-01T11:00:00Z' }] }),
            att(2, { viewOnce: true, purged: true, previewUrl: null, thumbUrl: null }),
            att(3),
          ],
        }),
      ],
      pages: {},
    });
    renderPage();
    const items = await screen.findAllByTestId('chat-attachment');
    expect(items).toHaveLength(3);
    expect(within(items[0]).getByTestId('viewonce-badge')).toHaveTextContent('Tek gönderimlik');
    expect(within(items[0]).getByTestId('viewed-by')).toHaveTextContent('Açan: Mehmet Kaya');
    expect(within(items[1]).getByTestId('purged-badge')).toHaveTextContent('Saklama süresi doldu');

    await userEvent.click(within(items[0]).getByRole('button', { name: /Büyüt/ }));
    const dialog = await screen.findByRole('dialog', { name: 'Medya görüntüleyici' });
    expect(within(dialog).getByTestId('lightbox-info')).toHaveTextContent('Ayşe Demir');
    expect(within(dialog).getByTestId('lightbox-info')).toHaveTextContent('2.0 KB');
    expect(within(dialog).getByTestId('lightbox-info')).toHaveTextContent('1 / 3');

    await userEvent.click(within(dialog).getByRole('button', { name: 'Sonraki' }));
    expect(within(dialog).getByTestId('lightbox-info')).toHaveTextContent('2 / 3');
    expect(within(dialog).getByText('Saklama süresi doldu', { selector: 'p' })).toBeInTheDocument();

    await userEvent.click(within(dialog).getByRole('button', { name: 'Kapat' }));
    expect(screen.queryByRole('dialog', { name: 'Medya görüntüleyici' })).toBeNull();
  });

  it('hata durumunda hata gösterir (içerik yok)', async () => {
    setup({ messagesError: true });
    renderPage();
    expect(await screen.findByRole('button', { name: /Tekrar dene|Yeniden dene/i })).toBeInTheDocument();
    expect(screen.queryByTestId('chat-bubble')).toBeNull();
  });
});

describe('Tekil yol yönlendirmesi', () => {
  it('/users/:id/message -> /users/:id/messages (sorgu korunur)', async () => {
    setup();
    function Where() {
      const l = useLocation();
      return <p data-testid="where">{`${l.pathname}${l.search}`}</p>;
    }
    renderWithProviders(
      <Routes>
        <Route path="/admin/users/:id/message" element={<LegacyMessageRedirect />} />
        <Route path="/admin/users/:id/messages" element={<Where />} />
      </Routes>,
      { route: '/admin/users/803/message?c=5&m=9' },
    );
    expect(await screen.findByTestId('where')).toHaveTextContent('/admin/users/803/messages?c=5&m=9');
  });
});
