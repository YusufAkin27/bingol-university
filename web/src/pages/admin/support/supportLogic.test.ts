import { beforeEach, describe, expect, it } from 'vitest';
import type { AdminFeedbackView } from '../../../api/types';
import {
  TEMPLATES_KEY,
  addTemplate,
  canReply,
  feedbackPatch,
  isSubmitShortcut,
  loadTemplates,
  nextTicketStatus,
  removeTemplate,
  saveTemplates,
} from './supportLogic';

describe('talep durum geçişleri', () => {
  it('yanıt ANSWERED yapar, kapat CLOSED yapar, kapalı talep kapalı kalır', () => {
    expect(nextTicketStatus('OPEN', 'reply')).toBe('ANSWERED');
    expect(nextTicketStatus('ANSWERED', 'reply')).toBe('ANSWERED');
    expect(nextTicketStatus('CLOSED', 'reply')).toBe('CLOSED');
    expect(nextTicketStatus('OPEN', 'close')).toBe('CLOSED');
    expect(canReply('CLOSED')).toBe(false);
    expect(canReply('OPEN')).toBe(true);
  });
  it('Ctrl+Enter ve Cmd+Enter gönderir', () => {
    expect(isSubmitShortcut({ key: 'Enter', ctrlKey: true, metaKey: false })).toBe(true);
    expect(isSubmitShortcut({ key: 'Enter', ctrlKey: false, metaKey: true })).toBe(true);
    expect(isSubmitShortcut({ key: 'Enter', ctrlKey: false, metaKey: false })).toBe(false);
  });
});

describe('hazır yanıt şablonları', () => {
  beforeEach(() => window.localStorage.clear());
  it('ekler, kaydeder, yeniden yükler ve siler', () => {
    let list = addTemplate([], '  Merhaba, talebiniz alındı.  ');
    expect(list).toHaveLength(1);
    expect(list[0].text).toBe('Merhaba, talebiniz alındı.');
    saveTemplates(list);
    expect(JSON.parse(window.localStorage.getItem(TEMPLATES_KEY) ?? '[]')).toHaveLength(1);
    list = loadTemplates();
    expect(list[0].text).toBe('Merhaba, talebiniz alındı.');
    expect(removeTemplate(list, list[0].id)).toEqual([]);
  });
  it('boş ve tekrar eden metni eklemez', () => {
    const one = addTemplate([], 'a');
    expect(addTemplate(one, '   ')).toBe(one);
    expect(addTemplate(one, 'a')).toBe(one);
  });
  it('bozuk depolama içeriğinde boş liste döner', () => {
    window.localStorage.setItem(TEMPLATES_KEY, '{bozuk');
    expect(loadTemplates()).toEqual([]);
    window.localStorage.setItem(TEMPLATES_KEY, '[1,{"id":"x","text":"ok"}]');
    expect(loadTemplates()).toEqual([{ id: 'x', text: 'ok' }]);
  });
});

describe('geri bildirim güncelleme gövdesi', () => {
  const base: AdminFeedbackView = {
    id: 1,
    userId: 2,
    userEmail: 'a@bingol.edu.tr',
    category: 'SUGGESTION',
    subject: 's',
    message: 'm',
    status: 'NEW',
    adminResponse: null,
    publicVisible: false,
    voteCount: 0,
    appVersion: null,
    platform: null,
    createdAt: '2026-01-01T00:00:00Z',
  };
  it('değişiklik yoksa null', () => {
    expect(feedbackPatch(base, { status: 'NEW', adminResponse: '', publicVisible: false })).toBeNull();
  });
  it('yalnızca değişen alanları gönderir', () => {
    expect(feedbackPatch(base, { status: 'PLANNED', adminResponse: ' Planlandı ', publicVisible: true })).toEqual({
      status: 'PLANNED',
      adminResponse: 'Planlandı',
      publicVisible: true,
    });
  });
  it('öneri olmayanda herkese açık alanı göndermez', () => {
    const bug = { ...base, category: 'BUG' as const };
    expect(feedbackPatch(bug, { status: 'NEW', adminResponse: '', publicVisible: true })).toBeNull();
  });
});
