// Forum yönetimi yanıt normalleştiricileri: backend şekli ayrışırsa yalnız burası ve adminForum.ts uyarlanır.
import { describe, expect, it } from 'vitest';
import { normalizeAction, normalizeCategory, normalizeReport, normalizeTopic } from './adminForum';

describe('adminForum normalleştiriciler', () => {
  it('kategori: nameTr ya da names{tr,en,ar}; eksik alanlar güvenli varsayılan', () => {
    expect(normalizeCategory({ id: 1, slug: 'a', nameTr: 'Gündem', sortOrder: 2 })).toMatchObject({ nameTr: 'Gündem', nameEn: '', active: true, topicCount: 0, sortOrder: 2 });
    expect(normalizeCategory({ id: 2, names: { tr: 'Dersler', en: 'Courses', ar: 'مواد' }, active: false })).toMatchObject({ nameTr: 'Dersler', nameEn: 'Courses', nameAr: 'مواد', active: false });
  });

  it('anonim konuda yazar adı taşınmaz (sunucu adı yollasa bile)', () => {
    const t = normalizeTopic({ id: 1, title: 'x', anonymous: true, author: { displayName: 'Gerçek Ad', anonymous: true } });
    expect(t.anonymous).toBe(true);
    expect(t.authorName).toBeNull();
    expect(normalizeTopic({ id: 2, title: 'y', author: { displayName: 'Ali' } }).authorName).toBe('Ali');
  });

  it('konu: pinnedAt/lockedAt zaman damgaları sabit/kilit sayılır; status REMOVED', () => {
    const t = normalizeTopic({ id: 1, title: 'x', pinnedAt: '2026-11-01T00:00:00Z', lockedAt: null, status: 'REMOVED', reportCount: 4 });
    expect(t).toMatchObject({ pinned: true, locked: false, status: 'REMOVED', openReportCount: 4 });
  });

  it('şikâyet: tek reason, anonim önizleme adı, yorum türü', () => {
    const r = normalizeReport({
      id: 5,
      targetType: 'FORUM_COMMENT',
      targetId: 9,
      topicId: 3,
      reason: 'SPAM',
      status: 'RESOLVED',
      preview: { body: 'metin', author: { displayName: 'Sızmamalı', anonymous: true } },
    });
    expect(r).toMatchObject({ targetType: 'FORUM_COMMENT', topicId: 3, reasons: ['SPAM'], status: 'RESOLVED', reportCount: 1 });
    expect(r.preview.authorName).toBeNull();
    expect(r.preview.anonymous).toBe(true);
  });

  it('şikâyet: konu hedefinde topicId = targetId; bilinmeyen tür konu sayılır', () => {
    expect(normalizeReport({ id: 1, targetType: 'FORUM_TOPIC', targetId: 11 }).topicId).toBe(11);
    expect(normalizeReport({ id: 1, targetId: 11 }).targetType).toBe('FORUM_TOPIC');
  });

  it('işlem kaydı: actor nesnesi ya da düz alanlar', () => {
    expect(normalizeAction({ id: 1, actor: { id: 7, displayName: 'Mert' }, targetType: 'FORUM_COMMENT', targetId: 2, action: 'REMOVE', reason: 'r' })).toMatchObject({ actorId: 7, actorName: 'Mert', targetType: 'FORUM_COMMENT' });
    expect(normalizeAction({ id: 2, actorId: 3, actorName: 'Ece' })).toMatchObject({ actorId: 3, actorName: 'Ece', reason: '' });
  });
});
