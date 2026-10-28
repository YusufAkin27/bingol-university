import { screen, within, cleanup } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { jsonResponse, mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/utils';
import { chatReasonKey, clearAllChatReasons, setChatReason } from './chat/chatReason';
import ReportsPage from './ReportsPage';

const person = (id: number, name: string) => ({ id, displayName: name, email: `${name.toLowerCase()}@bingol.edu.tr` });

const queueRow = {
  id: 11,
  reporterId: 4,
  targetType: 'MESSAGE',
  targetId: 502,
  reason: 'HARASSMENT',
  note: 'Hakaret ediyor',
  status: 'OPEN',
  resolution: null,
  createdAt: '2026-02-01T10:00:00Z',
  priority: 10,
  reasonCode: 'HARASSMENT',
  preview: null,
  hidden: false,
  hiddenBy: null,
  openReporters: 1,
  reporter: person(4, 'Zeynep'),
  reportedUser: person(7, 'Ayse'),
  viewerPath: '/admin/users/7/messages?c=30&m=502',
};

const cmsg = (id: number, over: Record<string, unknown> = {}) => ({
  id,
  conversationId: 30,
  senderId: 7,
  senderName: 'Ayse',
  mine: false,
  createdAt: '2026-02-01T10:00:00Z',
  text: `ctx-${id}`,
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
  replyTo: null,
  reactions: [],
  attachments: [],
  ...over,
});

const detail = {
  id: 11,
  targetType: 'MESSAGE',
  targetId: 502,
  reason: 'HARASSMENT',
  reasonCode: 'HARASSMENT',
  note: 'Hakaret ediyor',
  status: 'OPEN',
  resolution: null,
  priority: 10,
  createdAt: '2026-02-01T10:00:00Z',
  resolvedAt: null,
  reporter: person(4, 'Zeynep'),
  reportedUser: person(7, 'Ayse'),
  context: {
    type: 'MESSAGE',
    targetExists: true,
    conversation: { id: 30, type: 'DIRECT', title: 'Ayse - Zeynep', memberCount: 2, members: [] },
    reportedMessageId: 502,
    reportedAttachmentId: null,
    messages: [
      { reported: false, message: cmsg(501) },
      { reported: true, message: cmsg(502, { text: 'silinmis hakaret', deleted: true, deletedAt: '2026-02-01T11:00:00Z', deletedByName: 'Ayse' }) },
      { reported: false, message: cmsg(503, { senderId: 4, senderName: 'Zeynep' }) },
    ],
    content: null,
    userStats: { reportsAgainstUser: 3, activeStrikes: 1, totalStrikes: 2 },
  },
  relatedReports: { sameTargetCount: 2, last: [{ id: 12, reporter: person(5, 'Can'), reason: 'SPAM', status: 'OPEN', createdAt: '2026-02-01T12:00:00Z' }] },
  viewerPath: '/admin/users/7/messages?c=30&m=502',
};

beforeEach(() => {
  // Sohbet mesajı şikayeti bağlamı sebep ister (W-P02): kapı geçilmiş sayılır; akış chatReason.test.tsx'te sınanır.
  setChatReason(chatReasonKey.report(11), 'Rapor incelemesi #11 (test)');
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: () => 'blob:test', revokeObjectURL: () => {} }));
});
afterEach(() => {
  cleanup(); // önce bileşenleri kaldır: sebep deposu temizlenince kapı yeniden render etmesin
  vi.unstubAllGlobals();
  clearAllChatReasons();
});

function setup(ctx: unknown = detail) {
  mockFetch((url) => {
    if (url.includes('/admin/reports/11')) return jsonResponse(200, ctx);
    if (url.includes('/admin/reports/reason-templates')) return jsonResponse(200, []);
    if (url.includes('/admin/reports')) return jsonResponse(200, { items: [queueRow], nextCursor: null });
    return jsonResponse(404, { code: 'NOT_FOUND', message: 'x' });
  });
}

describe('Şikâyet bağlamı', () => {
  it('kuyruk satırında şikâyet eden -> edilen ve sebep kodu görünür', async () => {
    setup();
    renderWithProviders(<ReportsPage />, { route: '/admin/reports' });
    const people = await screen.findByTestId('report-people');
    expect(people).toHaveTextContent('Zeynep → Ayse');
  });

  it('seçili şikâyette mesaj (silinmiş de), çevre mesajlar, ilişkili şikâyetler ve "Sohbette aç" gelir', async () => {
    setup();
    renderWithProviders(<ReportsPage />, { route: '/admin/reports' });
    const ctx = await screen.findByTestId('report-context');
    expect(within(ctx).getByTestId('ctx-reporter')).toHaveTextContent('Zeynep');
    expect(within(ctx).getByTestId('ctx-reported')).toHaveTextContent('Ayse');
    expect(within(ctx).getByText('Hakaret ediyor')).toBeInTheDocument();

    const bubbles = within(within(ctx).getByTestId('ctx-messages')).getAllByTestId('chat-bubble');
    expect(bubbles).toHaveLength(3);
    expect(within(bubbles[1]).getByText('silinmis hakaret')).toBeInTheDocument();
    expect(within(bubbles[1]).getByTestId('deleted-badge')).toBeInTheDocument();
    expect(within(bubbles[1]).getByTestId('reported-badge')).toHaveTextContent('Şikâyet edilen mesaj');
    expect(within(bubbles[0]).queryByTestId('reported-badge')).toBeNull();

    expect(within(ctx).getByTestId('ctx-related')).toHaveTextContent('Aynı hedefe yapılan şikâyetler: 2');
    expect(within(ctx).getByTestId('open-in-chat')).toHaveAttribute('href', '/admin/users/7/messages?c=30&m=502');
    // mevcut eylemler korunur
    expect(screen.getAllByRole('radio').length).toBeGreaterThan(0);
  });

  it('kullanıcı/içerik hedeflerinde içerik özeti gösterilir', async () => {
    setup({
      ...detail,
      targetType: 'POST',
      context: {
        type: 'CONTENT',
        targetExists: true,
        conversation: null,
        reportedMessageId: null,
        reportedAttachmentId: null,
        messages: [],
        content: { kind: 'POST', id: 5, title: 'Gönderi başlığı', text: 'gönderi metni', communityId: 2, ownerId: 7, imageUrl: null, deleted: false, status: 'ACTIVE', createdAt: '2026-02-01T09:00:00Z' },
        userStats: null,
      },
    });
    renderWithProviders(<ReportsPage />, { route: '/admin/reports' });
    const content = await screen.findByTestId('ctx-content');
    expect(content).toHaveTextContent('Gönderi başlığı');
    expect(content).toHaveTextContent('gönderi metni');
  });
});
