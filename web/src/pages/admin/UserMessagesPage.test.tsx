import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Route, Routes } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import UserMessagesPage from './UserMessagesPage';

const USER = { id: 7, displayName: 'Ayşe Demir', avatarUrl: null };

const msg = (id: number, over: Record<string, unknown> = {}) => ({
  id,
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
  replyTo: null,
  reactions: [],
  attachments: [],
  ...over,
});

const CONVS = {
  user: USER,
  items: [
    {
      id: 30,
      type: 'DIRECT',
      title: null,
      peer: { id: 8, displayName: 'Mehmet Kaya', avatarUrl: null },
      memberCount: 2,
      totalMessages: 120,
      lastActivityAt: '2026-02-01T10:00:00Z',
      left: false,
      lastMessage: { id: 99, senderId: 8, mine: false, text: 'son mesaj önizleme', error: null, deleted: false, hidden: false, createdAt: '2026-02-01T10:00:00Z' },
    },
  ],
  nextCursor: null,
};

function setup(opts: { messagesError?: boolean } = {}) {
  const calls: string[] = [];
  mockFetch((url) => {
    calls.push(url);
    if (url.includes('/conversations/30/messages')) {
      if (opts.messagesError) return jsonResponse(503, { code: 'CRYPTO_UNAVAILABLE', message: 'x' });
      if (url.includes('before=61')) {
        return jsonResponse(200, {
          user: USER,
          conversation: { id: 30, type: 'DIRECT', title: null, peer: CONVS.items[0].peer, left: false },
          items: [msg(59, { text: 'eski-59' }), msg(60, { text: 'eski-60', mine: false, senderId: 8, senderName: 'Mehmet Kaya' })],
          nextBefore: null,
        });
      }
      return jsonResponse(200, {
        user: USER,
        conversation: { id: 30, type: 'DIRECT', title: null, peer: CONVS.items[0].peer, left: false },
        items: [
          msg(61, { text: 'benim mesajim' }),
          msg(62, { text: 'karsi taraf', mine: false, senderId: 8, senderName: 'Mehmet Kaya' }),
          msg(63, {
            text: 'gizli silinen',
            deleted: true,
            deletedAt: '2026-02-02T10:00:00Z',
            deletedBy: 8,
            deletedByName: 'Mehmet Kaya',
          }),
          msg(64, { text: 'yeni metin', edited: true, revisions: [{ text: 'eski metin', error: null, revisedAt: '2026-02-01T10:01:00Z' }] }),
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

describe('Kullanıcı mesajları sayfası', () => {
  it('konuşma listesini önizleme ve toplam sayıyla gösterir', async () => {
    setup();
    renderPage('/admin/users/7/messages');
    const list = await screen.findByTestId('conversation-list');
    expect(within(list).getByText('Mehmet Kaya')).toBeInTheDocument();
    expect(within(list).getByText('son mesaj önizleme')).toBeInTheDocument();
    expect(within(list).getByText('120 mesaj')).toBeInTheDocument();
    expect(screen.getByText('Soldan bir konuşma seçin')).toBeInTheDocument();
  });

  it('balonları yöne göre koyar; silinen mesaj çözülmüş metin ve silindi rozetiyle görünür', async () => {
    setup();
    renderPage();
    const bubbles = await screen.findAllByTestId('chat-bubble');
    expect(bubbles.map((b) => b.getAttribute('data-side'))).toEqual(['self', 'peer', 'self', 'self']);

    const deleted = bubbles[2];
    expect(deleted.getAttribute('data-deleted')).toBe('true');
    expect(within(deleted).getByText('gizli silinen')).toBeInTheDocument();
    expect(within(deleted).getByTestId('deleted-badge')).toHaveTextContent('silindi');
    expect(within(deleted).getByTestId('deleted-info')).toHaveTextContent('Mehmet Kaya');
    // silinmemiş mesajda rozet yok
    expect(within(bubbles[0]).queryByTestId('deleted-badge')).toBeNull();
    // düzenleme geçmişi
    expect(within(bubbles[3]).getByText('düzenlendi')).toBeInTheDocument();
    expect(within(bubbles[3]).getByText('eski metin')).toBeInTheDocument();
  });

  it('Arapçada aynı yön işaretleri korunur (ayna CSS mantıksal özelliklerle yapılır)', async () => {
    setup();
    renderPage('/admin/users/7/messages?c=30', 'ar');
    const bubbles = await screen.findAllByTestId('chat-bubble');
    expect(bubbles.map((b) => b.getAttribute('data-side'))).toEqual(['self', 'peer', 'self', 'self']);
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
    // devam yok: yükleme düğmesi kalkar
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Daha eski mesajları yükle' })).toBeNull());
  });

  it('düğmeyle de eski mesajları yükler', async () => {
    const calls = setup();
    renderPage();
    await screen.findAllByTestId('chat-bubble');
    await userEvent.click(screen.getByRole('button', { name: 'Daha eski mesajları yükle' }));
    await waitFor(() => expect(calls.some((u) => u.includes('before=61'))).toBe(true));
  });

  it('hata durumunda hata gösterir (içerik yok)', async () => {
    setup({ messagesError: true });
    renderPage();
    expect(await screen.findByRole('button', { name: /Tekrar dene|Yeniden dene/i })).toBeInTheDocument();
    expect(screen.queryByTestId('chat-bubble')).toBeNull();
  });
});
