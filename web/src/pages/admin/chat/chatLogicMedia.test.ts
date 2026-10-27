import { describe, expect, it } from 'vitest';
import type { AdminChatConversation } from '../../../api/types';
import {
  attachmentToItem,
  conversationBadges,
  conversationName,
  filterConversations,
  formatBytes,
  formatDuration,
  parseId,
  receiptTicks,
  stepIndex,
  viewerLink,
} from './chatLogic';

const conv = (over: Partial<AdminChatConversation> = {}): AdminChatConversation => ({
  id: 1,
  type: 'DIRECT',
  title: null,
  peer: { id: 2, displayName: 'Mehmet Kaya', avatarUrl: null },
  memberCount: 2,
  totalMessages: 3,
  lastActivityAt: null,
  left: false,
  state: { hiddenByUser: false, cleared: false, archived: false, muted: false },
  lastMessage: null,
  ...over,
});

describe('chatLogic (medya ve sohbet listesi)', () => {
  it('sohbet rozetleri: silinmiş, ayrılmış, arşivli, temizlenmiş, gölge engelli', () => {
    expect(conversationBadges(conv())).toEqual([]);
    const all = conv({
      left: true,
      state: { hiddenByUser: true, cleared: true, archived: true, muted: false },
      lastMessage: { id: 1, senderId: 1, mine: true, text: 'x', error: null, deleted: false, hidden: false, suppressed: true, createdAt: '' },
    });
    expect(conversationBadges(all)).toEqual(['deleted', 'left', 'archived', 'cleared', 'shadow']);
  });

  it('sohbet adı: birebirde karşı taraf, grupta başlık', () => {
    expect(conversationName(conv(), 'x', 'g')).toBe('Mehmet Kaya');
    expect(conversationName(conv({ type: 'GROUP', title: 'Proje' }), 'x', 'g')).toBe('Proje');
    expect(conversationName(conv({ type: 'GROUP', title: null }), 'x', 'g')).toBe('g');
    expect(conversationName(conv({ peer: null }), 'x', 'g')).toBe('x');
  });

  it('sohbet süzgeci ad ve son mesaj metnine bakar (tr büyük/küçük harf)', () => {
    const a = conv({ id: 1 });
    const b = conv({ id: 2, peer: { id: 3, displayName: 'IŞIL Öz', avatarUrl: null } });
    const name = (c: AdminChatConversation) => c.peer?.displayName ?? '';
    expect(filterConversations([a, b], '', name)).toHaveLength(2);
    expect(filterConversations([a, b], 'ışıl', name).map((c) => c.id)).toEqual([2]);
    expect(filterConversations([a, b], 'yok', name)).toEqual([]);
  });

  it('biçimleyiciler', () => {
    expect(formatBytes(512)).toBe('512 B');
    expect(formatBytes(2048)).toBe('2.0 KB');
    expect(formatBytes(5 * 1024 * 1024)).toBe('5.0 MB');
    expect(formatDuration(65000)).toBe('1:05');
    expect(formatDuration(null)).toBe('');
    expect(receiptTicks('SENT')).toBe('✓');
    expect(receiptTicks('READ')).toBe('✓✓');
    expect(receiptTicks(null)).toBe('');
  });

  it('parseId ve stepIndex', () => {
    expect(parseId('12')).toBe(12);
    expect(parseId('0')).toBeNull();
    expect(parseId('abc')).toBeNull();
    expect(parseId(null)).toBeNull();
    expect(stepIndex(0, -1, 3)).toBe(0);
    expect(stepIndex(2, 1, 3)).toBe(2);
    expect(stepIndex(1, 1, 3)).toBe(2);
  });

  it('viewerLink sohbet ve mesaj parametrelerini üretir', () => {
    expect(viewerLink(7, 30, 55)).toBe('/admin/users/7/messages?c=30&m=55');
    expect(viewerLink(null, 30, 55)).toBeNull();
  });

  it('attachmentToItem silinmiş mesajı ve tek gönderimlik bilgisini taşır', () => {
    const item = attachmentToItem(
      {
        id: 4, kind: 'VIDEO', contentType: 'video/mp4', width: 1, height: 1, durationMs: 3000, bytes: 10, hidden: false,
        viewOnce: true, viewedBy: [{ id: 2, displayName: 'B', at: 't' }], purged: false, previewUrl: '/p', thumbUrl: '/t',
      },
      { senderName: 'A', sender: null, createdAt: 'c', deleted: true, suppressed: false },
      '/l',
    );
    expect(item).toMatchObject({ key: 'a4', viewOnce: true, messageDeleted: true, senderName: 'A', link: '/l', durationMs: 3000 });
    expect(item.viewedBy).toHaveLength(1);
  });
});
