import { describe, expect, it } from 'vitest';
import {
  BULK_MAX,
  buildDecryptRequest,
  cleanReasonCode,
  countLabel,
  isSafeImageUrl,
  isValidSha256,
  normalizeSha256,
  parseId,
  previewApiPath,
  shortHash,
  summarizeBulk,
  toggleSelected,
  usesMessage,
  validateDecrypt,
  type DecryptForm,
} from './modLogic';

const form = (over: Partial<DecryptForm> = {}): DecryptForm => ({
  conversationId: '12',
  fromMessageId: '100',
  toMessageId: '',
  reason: 'Şikâyet incelemesi için gerekli',
  ...over,
});

describe('mesaj çözme formu', () => {
  it('geçerli formu kabul eder', () => {
    expect(validateDecrypt(form())).toBeNull();
    expect(validateDecrypt(form({ toMessageId: '150' }))).toBeNull();
  });
  it('gerekçe kırpılmış 10 karakterden kısaysa reddeder', () => {
    expect(validateDecrypt(form({ reason: '   kısa    ' }))).toBe('reasonShort');
    expect(validateDecrypt(form({ reason: '1234567890' }))).toBeNull();
    expect(validateDecrypt(form({ reason: 'x'.repeat(501) }))).toBe('reasonLong');
  });
  it('geçersiz konuşma ve aralıkları yakalar', () => {
    expect(validateDecrypt(form({ conversationId: '' }))).toBe('conversation');
    expect(validateDecrypt(form({ conversationId: '0' }))).toBe('conversation');
    expect(validateDecrypt(form({ fromMessageId: 'abc' }))).toBe('range');
    expect(validateDecrypt(form({ toMessageId: '50' }))).toBe('range');
    expect(validateDecrypt(form({ toMessageId: '-1' }))).toBe('range');
  });
  it('istek gövdesini sayılara çevirir; boş son kimlik gönderilmez', () => {
    expect(buildDecryptRequest(form({ reason: '  yeterince uzun gerekçe  ' }))).toEqual({
      conversationId: 12,
      fromMessageId: 100,
      reason: 'yeterince uzun gerekçe',
    });
    expect(buildDecryptRequest(form({ toMessageId: '120' })).toMessageId).toBe(120);
  });
});

describe('toplu karar yardımcıları', () => {
  it('seçimi açıp kapatır ve 100 sınırını aşmaz', () => {
    expect(toggleSelected([1, 2], 3)).toEqual([1, 2, 3]);
    expect(toggleSelected([1, 2, 3], 2)).toEqual([1, 3]);
    const full = Array.from({ length: BULK_MAX }, (_, i) => i + 1);
    expect(toggleSelected(full, 999)).toBe(full);
  });
  it('satır sonuçlarını özetler', () => {
    const s = summarizeBulk([
      { id: 1, ok: true, error: null },
      { id: 2, ok: false, error: 'ALREADY_RESOLVED' },
      { id: 3, ok: false, error: null },
    ]);
    expect(s.ok).toBe(1);
    expect(s.failed).toBe(2);
    expect(s.errors).toEqual([
      { id: 2, error: 'ALREADY_RESOLVED' },
      { id: 3, error: 'UNKNOWN' },
    ]);
  });
  it('yalnızca uyar ve askıya almada mesaj kullanılır', () => {
    expect(usesMessage('WARN')).toBe(true);
    expect(usesMessage('SUSPEND_USER')).toBe(true);
    expect(usesMessage('HIDE')).toBe(false);
    expect(usesMessage('DISMISS')).toBe(false);
  });
  it('geçersiz neden kodunu atar', () => {
    expect(cleanReasonCode('HATE')).toBe('HATE');
    expect(cleanReasonCode('hate')).toBeUndefined();
    expect(cleanReasonCode('')).toBeUndefined();
    expect(cleanReasonCode(null)).toBeUndefined();
  });
});

describe('önizleme adresleri', () => {
  it('/api adreslerini yetkili çekim için yola çevirir, diğerlerini doğrudan bırakır', () => {
    expect(previewApiPath('/api/admin/moderation/media/5')).toBe('/admin/moderation/media/5');
    expect(previewApiPath('/files/a.jpg')).toBeNull();
    expect(previewApiPath(null)).toBeNull();
  });
  it('yalnızca aynı kök yol ve https görsel olarak kabul edilir', () => {
    expect(isSafeImageUrl('/files/a.jpg')).toBe(true);
    expect(isSafeImageUrl('https://cdn.example.com/a.jpg')).toBe(true);
    expect(isSafeImageUrl('//evil.example.com/a.jpg')).toBe(false);
    expect(isSafeImageUrl('javascript:alert(1)')).toBe(false);
    expect(isSafeImageUrl('http://example.com/a.jpg')).toBe(false);
    expect(isSafeImageUrl('')).toBe(false);
  });
});

describe('SHA-256 özeti', () => {
  const ok = 'a'.repeat(64);
  it('64 onaltılık karakteri kabul eder, büyük harfi küçültür', () => {
    expect(isValidSha256(ok)).toBe(true);
    expect(isValidSha256(` ${ok.toUpperCase()} `)).toBe(true);
    expect(normalizeSha256(` ${ok.toUpperCase()} `)).toBe(ok);
  });
  it('eksik, fazla ve onaltılık olmayanı reddeder', () => {
    expect(isValidSha256('a'.repeat(63))).toBe(false);
    expect(isValidSha256('a'.repeat(65))).toBe(false);
    expect(isValidSha256('g'.repeat(64))).toBe(false);
  });
  it('uzun özeti kısaltır', () => {
    expect(shortHash(ok)).toBe(`${'a'.repeat(12)}…${'a'.repeat(6)}`);
    expect(shortHash('abc')).toBe('abc');
  });
});

describe('kimlik ve sayaç', () => {
  it('pozitif tam sayıyı ayrıştırır', () => {
    expect(parseId(' 42 ')).toBe(42);
    expect(parseId('0')).toBeNull();
    expect(parseId('-3')).toBeNull();
    expect(parseId('4.2')).toBeNull();
    expect(parseId('')).toBeNull();
  });
  it('sonraki sayfa varsa artı işareti ekler', () => {
    expect(countLabel(7, false)).toBe('7');
    expect(countLabel(50, true)).toBe('50+');
  });
});
