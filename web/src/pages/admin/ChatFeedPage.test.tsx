import { screen, waitFor, within, cleanup } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { chatReasonKey, clearAllChatReasons, setChatReason } from './chat/chatReason';
import ChatFeedPage from './ChatFeedPage';

const person = (id: number, name: string) => ({ id, displayName: name, avatarUrl: null, email: `${name}@bingol.edu.tr` });
const media = (id: number, over: Record<string, unknown> = {}) => ({
  attachmentId: id,
  conversationId: 30,
  conversationTitle: 'Proje grubu',
  conversationType: 'GROUP',
  messageId: 500 + id,
  sender: person(7, 'Ayse'),
  recipients: [person(8, 'Mehmet')],
  memberCount: 3,
  kind: 'IMAGE',
  viewOnce: false,
  viewedBy: [],
  purged: false,
  messageDeleted: false,
  hidden: false,
  suppressed: false,
  createdAt: '2026-02-01T10:00:00Z',
  width: 10,
  height: 10,
  durationMs: null,
  bytes: 1500,
  previewUrl: `/api/admin/media/attachments/${id}/preview`,
  thumbUrl: `/api/admin/media/attachments/${id}/preview?thumb=true`,
  ...over,
});
const feedMsg = (id: number, over: Record<string, unknown> = {}) => ({
  conversation: { id: 30, type: 'GROUP', title: 'Proje grubu', memberCount: 3 },
  message: {
    id,
    conversationId: 30,
    senderId: 7,
    senderName: 'Ayse',
    sender: person(7, 'Ayse'),
    mine: false,
    createdAt: '2026-02-01T10:00:00Z',
    text: `akis-${id}`,
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
    status: 'SENT',
    replyTo: null,
    reactions: [],
    attachments: [],
    ...over,
  },
});
const counts = { imageCount: 5, videoCount: 2, viewOnceCount: 1, deletedMessageMediaCount: 3, hiddenCount: 0, suppressedCount: 0, purgedCount: 4, totalBytes: 4096 };

function setup(opts: { mediaError?: boolean } = {}) {
  const calls: string[] = [];
  mockFetch((url) => {
    calls.push(url);
    if (url.includes('/media/attachments/')) return new Response(new Blob(['x']), { status: 200, headers: { 'Content-Type': 'image/jpeg' } });
    if (url.includes('/chat-media/stats')) return jsonResponse(200, { ...counts, last24h: counts });
    if (url.includes('/chat-media')) {
      if (opts.mediaError) return jsonResponse(500, { code: 'X', message: 'x' });
      if (url.includes('cursor=2')) return jsonResponse(200, { items: [media(1)], nextCursor: null });
      return jsonResponse(200, {
        items: [media(3, { viewOnce: true, viewedBy: [{ id: 8, displayName: 'Mehmet', at: '2026-02-01T11:00:00Z' }] }), media(2, { messageDeleted: true, kind: 'VIDEO', durationMs: 5000 })],
        nextCursor: 2,
      });
    }
    if (url.includes('/chat-messages')) {
      return jsonResponse(200, { items: [feedMsg(900, { deleted: true, deletedAt: '2026-02-02T10:00:00Z', deletedByName: 'Ayse' }), feedMsg(901, { suppressed: true })], nextCursor: null });
    }
    if (url.includes('/admin/users')) return jsonResponse(200, { items: [{ id: 7, displayName: 'Ayse', email: 'ayse@bingol.edu.tr' }], page: 0, size: 8, totalItems: 1, totalPages: 1 });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
  return calls;
}

beforeEach(() => {
  // Sohbet içeriği sebep ister (W-P02): sebep kapısı geçilmiş sayılır; sebep akışı chatReason.test.tsx'te sınanır.
  setChatReason(chatReasonKey.feed(), 'Şikayet incelemesi (test)');
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: () => 'blob:test', revokeObjectURL: () => {} }));
});
afterEach(() => {
  cleanup(); // önce bileşenleri kaldır: sebep deposu temizlenince kapı yeniden render etmesin
  vi.unstubAllGlobals();
  clearAllChatReasons();
});

describe('Sohbet medyası ve mesajlar sayfası', () => {
  it('istatistik kartları ve medya ızgarası rozetlerle gelir; sonraki sayfa yüklenir', async () => {
    const calls = setup();
    renderWithProviders(<ChatFeedPage />);
    const grid = await screen.findByTestId('media-grid');
    expect(within(grid).getAllByTestId('viewonce-badge')).toHaveLength(1);
    expect(within(grid).getByText('Silindi')).toBeInTheDocument();
    expect(within(await screen.findByTestId('chat-stats')).getByText('5')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Daha fazla yükle' }));
    await waitFor(() => expect(calls.some((u) => u.includes('chat-media?') && u.includes('cursor=2'))).toBe(true));
    await waitFor(() => expect(within(screen.getByTestId('media-grid')).getAllByRole('listitem')).toHaveLength(3));
  });

  it('süzgeçler sorguya gider (tür, tek gönderimlik, silinmiş)', async () => {
    const calls = setup();
    renderWithProviders(<ChatFeedPage />);
    await screen.findByTestId('media-grid');
    await userEvent.selectOptions(screen.getByLabelText('Tür'), 'VIDEO');
    await userEvent.click(screen.getByRole('checkbox', { name: 'Tek gönderimlik' }));
    await userEvent.click(screen.getByRole('checkbox', { name: 'Silinmiş mesaj' }));
    await waitFor(() =>
      expect(calls.some((u) => u.includes('chat-media?') && u.includes('kind=VIDEO') && u.includes('viewOnce=true') && u.includes('deleted=true'))).toBe(true),
    );
  });

  it('lightbox açılır ve "Sohbette göster" bağlantısı mesaja gider', async () => {
    setup();
    renderWithProviders(<ChatFeedPage />);
    const grid = await screen.findByTestId('media-grid');
    await userEvent.click(within(grid).getAllByRole('button', { name: /Büyüt/ })[0]);
    const dialog = await screen.findByRole('dialog', { name: 'Medya görüntüleyici' });
    const link = within(dialog).getByRole('link', { name: 'Sohbette göster' });
    expect(link).toHaveAttribute('href', '/admin/users/7/messages?c=30&m=503');
  });

  it('Mesajlar sekmesi silinmiş ve iletilmemiş mesajları rozetle listeler', async () => {
    setup();
    renderWithProviders(<ChatFeedPage />);
    await userEvent.click(await screen.findByRole('tab', { name: 'Mesajlar' }));
    const list = await screen.findByTestId('feed-list');
    expect(within(list).getAllByTestId('feed-row')).toHaveLength(2);
    expect(within(list).getByText('akis-900')).toBeInTheDocument();
    expect(within(list).getByTestId('deleted-badge')).toBeInTheDocument();
    expect(within(list).getByTestId('suppressed-badge')).toBeInTheDocument();
    expect(within(list).getAllByRole('link', { name: 'Sohbette göster' })[0]).toHaveAttribute('href', '/admin/users/7/messages?c=30&m=900');
  });

  it('hata durumunu gösterir', async () => {
    setup({ mediaError: true });
    renderWithProviders(<ChatFeedPage />);
    expect(await screen.findByRole('button', { name: /Tekrar dene|Yeniden dene/i })).toBeInTheDocument();
  });
});
