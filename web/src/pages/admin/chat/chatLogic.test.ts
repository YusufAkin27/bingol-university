import { describe, expect, it } from 'vitest';
import type { AdminChatMessage, AdminChatMessagePage } from '../../../api/types';
import {
  LOAD_OLDER_THRESHOLD_PX,
  bubbleSide,
  dayKey,
  flattenPages,
  nextBeforeParam,
  previewApiPath,
  restoredScrollTop,
  shouldLoadOlder,
} from './chatLogic';

const msg = (id: number, over: Partial<AdminChatMessage> = {}): AdminChatMessage => ({
  id,
  senderId: 1,
  senderName: 'A',
  mine: true,
  createdAt: '2026-02-01T10:00:00Z',
  text: `m${id}`,
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

const page = (ids: number[], nextBefore: number | null): AdminChatMessagePage => ({
  user: { id: 1, displayName: 'A', avatarUrl: null },
  conversation: { id: 9, type: 'DIRECT', title: null, peer: null, left: false },
  items: ids.map((i) => msg(i)),
  nextBefore,
});

describe('sayfa birleştirme (yeniden eskiye sayfalama)', () => {
  it('ilk sayfa en yeni; eski sayfalar başa eklenir ve sıra eskiden yeniye kalır', () => {
    const newest = page([61, 62, 63], 61);
    const older = page([58, 59, 60], 58);
    expect(flattenPages([newest]).map((m) => m.id)).toEqual([61, 62, 63]);
    expect(flattenPages([newest, older]).map((m) => m.id)).toEqual([58, 59, 60, 61, 62, 63]);
  });
  it('yinelenen kimlikleri tekilleştirir', () => {
    expect(flattenPages([page([3, 4], 3), page([2, 3], 2)]).map((m) => m.id)).toEqual([2, 3, 4]);
  });
  it('imleç: nextBefore varsa o, yoksa undefined', () => {
    expect(nextBeforeParam(page([5, 6], 5))).toBe(5);
    expect(nextBeforeParam(page([1], null))).toBeUndefined();
  });
});

describe('balon yönü', () => {
  it('açılan kullanıcının mesajı self, karşı taraf peer', () => {
    expect(bubbleSide(msg(1, { mine: true }))).toBe('self');
    expect(bubbleSide(msg(2, { mine: false }))).toBe('peer');
  });
});

describe('yukarı kaydırmada yükleme', () => {
  it('eşiğe gelince, devam varsa ve istek yoksa yükler', () => {
    expect(shouldLoadOlder(0, true, false)).toBe(true);
    expect(shouldLoadOlder(LOAD_OLDER_THRESHOLD_PX, true, false)).toBe(true);
    expect(shouldLoadOlder(LOAD_OLDER_THRESHOLD_PX + 1, true, false)).toBe(false);
    expect(shouldLoadOlder(0, false, false)).toBe(false);
    expect(shouldLoadOlder(0, true, true)).toBe(false);
  });
  it('eski sayfa eklenince konum yükseklik farkı kadar kayar', () => {
    expect(restoredScrollTop(10, 1000, 1600)).toBe(610);
    expect(restoredScrollTop(10, 1000, 900)).toBe(10);
  });
});

describe('yardımcılar', () => {
  it('gün anahtarı aynı yerel günde aynıdır', () => {
    expect(dayKey('2026-02-01T10:00:00')).toBe(dayKey('2026-02-01T20:00:00'));
    expect(dayKey('2026-02-01T10:00:00')).not.toBe(dayKey('2026-02-02T10:00:00'));
  });
  it('önizleme yolundan /api önekini atar', () => {
    expect(previewApiPath('/api/admin/media/attachments/3/preview?thumb=true')).toBe(
      '/admin/media/attachments/3/preview?thumb=true',
    );
  });
});
