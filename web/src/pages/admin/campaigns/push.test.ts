import { describe, expect, it } from 'vitest';
import {
  TARGET_TYPES,
  audienceFromState,
  buildQuickBody,
  campaignActions,
  emptyState,
  isDraftEmpty,
  parseEmailList,
} from './lib';

function filled(over: Partial<ReturnType<typeof emptyState>> = {}) {
  const s = emptyState();
  s.contents.tr = { title: 'Başlık', body: 'Metin' };
  return { ...s, ...over };
}

describe('yeni kitle türleri', () => {
  it('FACULTY ad ister ve kırpar', () => {
    expect(audienceFromState({ ...emptyState(), audienceType: 'FACULTY' }).error).toBe('FACULTY_REQUIRED');
    expect(audienceFromState({ ...emptyState(), audienceType: 'FACULTY', faculty: ' Hukuk Fakültesi ' }).audience).toEqual({
      type: 'FACULTY',
      value: 'Hukuk Fakültesi',
    });
  });

  it('LANGUAGE yalnız tr/en/ar kabul eder', () => {
    expect(audienceFromState({ ...emptyState(), audienceType: 'LANGUAGE' }).error).toBe('LANGUAGE_REQUIRED');
    expect(audienceFromState({ ...emptyState(), audienceType: 'LANGUAGE', language: 'ar' }).audience).toEqual({
      type: 'LANGUAGE',
      value: 'ar',
    });
  });

  it('EMAILS metni böler, tekrarları atar, sınırı denetler', () => {
    expect(parseEmailList('a@b.c, 12\n  A@B.C;x@y.z ')).toEqual(['a@b.c', '12', 'x@y.z']);
    expect(audienceFromState({ ...emptyState(), audienceType: 'EMAILS', emails: '  ' }).error).toBe('EMAILS_EMPTY');
    const many = Array.from({ length: 501 }, (_, i) => `u${i}@b.c`).join('\n');
    expect(audienceFromState({ ...emptyState(), audienceType: 'EMAILS', emails: many }).error).toBe('EMAILS_TOO_MANY');
    expect(audienceFromState({ ...emptyState(), audienceType: 'EMAILS', emails: 'a@b.c 7' }).audience).toEqual({
      type: 'EMAILS',
      value: 'a@b.c\n7',
    });
  });

  it('taslak boşluğu yeni alanları da sayar; POLL ve TICKET hedef olarak seçilebilir', () => {
    expect(isDraftEmpty(emptyState())).toBe(true);
    expect(isDraftEmpty({ ...emptyState(), emails: 'a@b.c' })).toBe(false);
    expect(isDraftEmpty({ ...emptyState(), faculty: 'Hukuk' })).toBe(false);
    expect(TARGET_TYPES).toContain('POLL');
    expect(TARGET_TYPES).toContain('TICKET');
  });
});

describe('hızlı gönderim gövdesi ve kampanya işlemleri', () => {
  it('içerik ve hedef geçerliyse kitle/zamanlama olmadan gövde kurar', () => {
    const r = buildQuickBody(filled({ targetType: 'POLL', targetValue: '9' }));
    expect(r.valid).toBe(true);
    expect(r.body).toEqual({
      type: 'ANNOUNCEMENT',
      tr: { title: 'Başlık', body: 'Metin' },
      target: { type: 'POLL', value: '9' },
    });
    expect(buildQuickBody(filled({ targetType: 'URL', targetValue: 'http://x' })).valid).toBe(false);
    expect(buildQuickBody(emptyState()).valid).toBe(false);
  });

  it('duraklat yalnız zamanlanmışta, devam yalnız duraklatılmışta, iptal ikisinde', () => {
    expect(campaignActions('SCHEDULED')).toEqual({ pause: true, resume: false, cancel: true });
    expect(campaignActions('PAUSED')).toEqual({ pause: false, resume: true, cancel: true });
    expect(campaignActions('SENDING')).toEqual({ pause: false, resume: false, cancel: false });
    expect(campaignActions('SENT')).toEqual({ pause: false, resume: false, cancel: false });
  });
});
