import { describe, expect, it } from 'vitest';
import { ApiError } from '../../../api/client';
import { dictionaries, translate } from '../../../i18n';
import {
  audienceReady,
  buildAudience,
  emptyAudience,
  emptyForm,
  hasErrors,
  insertAt,
  mailErrorMessage,
  parseEmails,
  parseSchedule,
  toRequest,
  validateForm,
} from './mailLogic';

const i18n = {
  t: (k: string, p?: Record<string, string | number>) => translate('tr', k, p),
  td: (k: string, f?: string) => (k in dictionaries.tr ? translate('tr', k) : (f ?? '')),
} as unknown as Parameters<typeof mailErrorMessage>[0];

describe('şablon formu', () => {
  it('boş formda ad ve tr konu/HTML zorunlu', () => {
    const e = validateForm(emptyForm());
    expect(e.name).toBe('required');
    expect(e.lang.tr).toEqual({ subject: 'required', html: 'required' });
    expect(hasErrors(e)).toBe(true);
  });

  it('boş en/ar atlanır, yarım doldurulan dil hata verir', () => {
    const f = emptyForm();
    f.name = 'x';
    f.tr = { subject: 's', html: '<p>a</p>', text: '' };
    expect(hasErrors(validateForm(f))).toBe(false);
    f.en.subject = 'only subject';
    expect(validateForm(f).lang.en).toEqual({ html: 'required' });
  });

  it('uzunluk sınırlarını denetler', () => {
    const f = emptyForm();
    f.name = 'x';
    f.tr = { subject: 'a'.repeat(201), html: 'b'.repeat(100001), text: '' };
    expect(validateForm(f).lang.tr).toEqual({ subject: 'tooLong', html: 'tooLong' });
  });

  it('istekte boş diller null, boş düz metin null olur', () => {
    const f = emptyForm();
    f.name = ' ad ';
    f.tr = { subject: ' s ', html: '<p/>', text: '' };
    const r = toRequest(f);
    expect(r.name).toBe('ad');
    expect(r.en).toBeNull();
    expect(r.ar).toBeNull();
    expect(r.tr).toEqual({ subject: 's', html: '<p/>', text: null });
  });

  it('değişkeni imleç konumuna ekler', () => {
    expect(insertAt('Merhaba !', 8, 8, '{{ad}}')).toEqual({ value: 'Merhaba {{ad}}!', caret: 14 });
    expect(insertAt('abc', 1, 2, 'X').value).toBe('aXc');
  });
});

describe('kitle', () => {
  it('e-posta listesini ayrıştırır, yineleneni ve geçersizi sayar', () => {
    const r = parseEmails('A@bingol.edu.tr, b@bingol.edu.tr;a@bingol.edu.tr\nbozuk x@y');
    expect(r.valid).toEqual(['a@bingol.edu.tr', 'b@bingol.edu.tr']);
    expect(r.duplicates).toBe(1);
    expect(r.invalid).toEqual(['bozuk', 'x@y']);
  });

  it('kitle gövdesini türe göre kurar', () => {
    expect(buildAudience(emptyAudience())).toEqual({ type: 'ALL' });
    const f = { ...emptyAudience(), type: 'FILTER' as const, faculty: ' Mühendislik ', classYear: '2', role: 'USER' as const };
    expect(buildAudience(f)).toEqual({ type: 'FILTER', filter: { faculty: 'Mühendislik', classYear: 2, role: 'USER' } });
    expect(buildAudience({ ...emptyAudience(), type: 'USERS', userIds: [3, 4] })).toEqual({ type: 'USERS', userIds: [3, 4] });
    expect(buildAudience({ ...emptyAudience(), type: 'EMAILS', emailsText: 'a@b.co, a@b.co' })).toEqual({
      type: 'EMAILS',
      emails: ['a@b.co'],
    });
  });

  it('boş süzgeç/liste hazır sayılmaz', () => {
    expect(audienceReady(emptyAudience())).toBe(true);
    expect(audienceReady({ ...emptyAudience(), type: 'FILTER' })).toBe(false);
    expect(audienceReady({ ...emptyAudience(), type: 'FILTER', language: 'en' })).toBe(true);
    expect(audienceReady({ ...emptyAudience(), type: 'USERS' })).toBe(false);
    expect(audienceReady({ ...emptyAudience(), type: 'EMAILS', emailsText: 'zzz' })).toBe(false);
  });
});

describe('zamanlama', () => {
  const now = new Date('2026-11-01T10:00:00Z');
  it('geçmişi, 90 günden ilerisini ve boşu reddeder', () => {
    expect(parseSchedule('', now)).toEqual({ error: 'required' });
    expect(parseSchedule('2026-10-01T10:00', now)).toEqual({ error: 'past' });
    expect(parseSchedule('2027-06-01T10:00', now)).toEqual({ error: 'tooFar' });
    expect(parseSchedule('2026-11-10T10:00', now)).toHaveProperty('iso');
  });
});

describe('hata kodu mesajları', () => {
  it.each([
    ['MAIL_TEMPLATE_NOT_PUBLISHED', 409, 'yayında'],
    ['MAIL_TEMPLATE_IN_USE', 409, 'arşivleyin'],
    ['MAIL_CAMPAIGN_NO_RECIPIENTS', 400, 'alıcı yok'],
    ['MAIL_CAMPAIGN_INVALID_STATE', 409, 'uygun değil'],
    ['MAIL_UNAVAILABLE', 503, 'kullanılamıyor'],
  ])('%s çevrilir', (code, status, part) => {
    expect(mailErrorMessage(i18n, new ApiError(status as number, code as string, 'sunucu'))).toContain(part as string);
  });

  it('doğrulama hatasında sunucu ayrıntısını ekler', () => {
    const m = mailErrorMessage(i18n, new ApiError(400, 'MAIL_TEMPLATE_VARIABLE_UNKNOWN', 'Bilinmeyen değişken: {{x}}'));
    expect(m).toContain('tanımsız');
    expect(m).toContain('{{x}}');
  });

  it('429 genel mesaja düşer', () => {
    expect(mailErrorMessage(i18n, new ApiError(429, 'RATE_LIMITED_X', 'x'))).toContain('Çok fazla');
  });
});

describe('sözlük', () => {
  it('admin.mail anahtarları üç dilde var ve yer tutucular eşit', () => {
    const keys = Object.keys(dictionaries.tr).filter((k) => k.startsWith('admin.mail.'));
    expect(keys.length).toBeGreaterThan(100);
    const ph = (s: string) => (s.match(/\{\w+\}/g) ?? []).sort().join(',');
    for (const k of keys) {
      for (const l of ['en', 'ar'] as const) {
        const v = (dictionaries[l] as Record<string, string>)[k];
        expect(v, `${l}:${k}`).toBeTruthy();
        expect(ph(v), `${l}:${k}`).toBe(ph((dictionaries.tr as Record<string, string>)[k]));
      }
    }
  });
});
