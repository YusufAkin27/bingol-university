import { describe, expect, it } from 'vitest';
import {
  BODY_MAX,
  DRAFT_KEY,
  MAX_USERS,
  TITLE_MAX,
  audienceFromState,
  buildRequest,
  clearDraft,
  contentErrors,
  counterTone,
  emptyState,
  isDraftEmpty,
  loadDraft,
  localToIso,
  needsExtraConfirm,
  saveDraft,
  scheduleError,
  targetError,
  toLocalInput,
  type ComposeState,
} from './lib';
import { readStorage, writeStorage } from '../../../lib/storage';

const NOW = new Date('2026-10-23T12:00:00Z');

function filled(over: Partial<ComposeState> = {}): ComposeState {
  const s = emptyState();
  s.contents.tr = { title: 'Başlık', body: 'Metin' };
  return { ...s, ...over };
}

describe('hedef kitle doğrulaması', () => {
  it('ALL, ADMINS ve SELF değer taşımaz', () => {
    for (const type of ['ALL', 'ADMINS', 'SELF'] as const) {
      const r = audienceFromState({ ...emptyState(), audienceType: type });
      expect(r.audience).toEqual({ type, value: null });
    }
  });

  it('DEPARTMENT bölüm adı ister (en çok 120 karakter)', () => {
    expect(audienceFromState({ ...emptyState(), audienceType: 'DEPARTMENT' }).error).toBe('DEPARTMENT_REQUIRED');
    expect(
      audienceFromState({ ...emptyState(), audienceType: 'DEPARTMENT', department: ' Bilgisayar ' }).audience,
    ).toEqual({ type: 'DEPARTMENT', value: 'Bilgisayar' });
    expect(
      audienceFromState({ ...emptyState(), audienceType: 'DEPARTMENT', department: 'x'.repeat(121) }).error,
    ).toBe('DEPARTMENT_REQUIRED');
  });

  it('CLASS_YEAR yalnızca 1-8', () => {
    const at = (classYear: string) => audienceFromState({ ...emptyState(), audienceType: 'CLASS_YEAR', classYear });
    expect(at('').error).toBe('CLASS_YEAR_INVALID');
    expect(at('0').error).toBe('CLASS_YEAR_INVALID');
    expect(at('9').error).toBe('CLASS_YEAR_INVALID');
    expect(at('1.5').error).toBe('CLASS_YEAR_INVALID');
    expect(at('abc').error).toBe('CLASS_YEAR_INVALID');
    expect(at('4').audience).toEqual({ type: 'CLASS_YEAR', value: '4' });
  });

  it('USERS en az 1, en çok 500 kullanıcı; değer virgüllü kimlik listesidir', () => {
    const mk = (n: number) => Array.from({ length: n }, (_, i) => ({ id: i + 1, displayName: `u${i}`, email: `u${i}@x` }));
    const at = (users: ReturnType<typeof mk>) => audienceFromState({ ...emptyState(), audienceType: 'USERS', users });
    expect(at([]).error).toBe('USERS_EMPTY');
    expect(at(mk(3)).audience).toEqual({ type: 'USERS', value: '1,2,3' });
    expect(at(mk(MAX_USERS)).audience?.value?.split(',')).toHaveLength(500);
    expect(at(mk(MAX_USERS + 1)).error).toBe('USERS_TOO_MANY');
  });
});

describe('karakter sayaçları', () => {
  it('sınırın %90ından sonra uyarı, aşınca hata tonu', () => {
    expect(counterTone(10, TITLE_MAX)).toBe('ok');
    expect(counterTone(89, TITLE_MAX)).toBe('ok');
    expect(counterTone(90, TITLE_MAX)).toBe('warn');
    expect(counterTone(100, TITLE_MAX)).toBe('warn');
    expect(counterTone(101, TITLE_MAX)).toBe('over');
    expect(counterTone(BODY_MAX + 1, BODY_MAX)).toBe('over');
  });

  it('içerik: Türkçe zorunlu, sınır aşımı ve yarım dil hatalıdır', () => {
    const s = emptyState();
    expect(contentErrors(s.contents).tr).toBe('TR_REQUIRED');
    s.contents.tr = { title: 'a', body: 'b' };
    expect(contentErrors(s.contents)).toEqual({});
    s.contents.en = { title: 'only title', body: '' };
    expect(contentErrors(s.contents).en).toBe('PARTIAL');
    s.contents.en = { title: 'x'.repeat(101), body: 'b' };
    expect(contentErrors(s.contents).en).toBe('TOO_LONG');
    s.contents.en = { title: '', body: '' };
    s.contents.ar = { title: 'a', body: 'x'.repeat(301) };
    expect(contentErrors(s.contents).ar).toBe('TOO_LONG');
  });
});

describe('zaman dönüşümü', () => {
  it('yerel saat -> ISO UTC', () => {
    const iso = localToIso('2026-11-01T10:30');
    expect(iso).toBe(new Date(2026, 10, 1, 10, 30).toISOString());
    expect(iso).toMatch(/Z$/);
  });
  it('geçersiz girdi null', () => {
    expect(localToIso('')).toBeNull();
    expect(localToIso('2026-11-01')).toBeNull();
    expect(localToIso('2026-13-45T99:99')).toBeNull();
  });
  it('toLocalInput yerel biçimi üretir ve localToIso ile gidiş-dönüş yapar', () => {
    const d = new Date(2026, 5, 7, 9, 5);
    expect(toLocalInput(d)).toBe('2026-06-07T09:05');
    expect(localToIso(toLocalInput(d))).toBe(d.toISOString());
  });
  it('zamanlama: gelecekte ve en çok 30 gün', () => {
    const at = (ms: number) => toLocalInput(new Date(NOW.getTime() + ms));
    expect(scheduleError('', NOW)).toBe('REQUIRED');
    expect(scheduleError(at(-3600_000), NOW)).toBe('PAST');
    expect(scheduleError(at(3600_000), NOW)).toBeNull();
    expect(scheduleError(at(29 * 86_400_000), NOW)).toBeNull();
    expect(scheduleError(at(31 * 86_400_000), NOW)).toBe('TOO_FAR');
  });
});

describe('hedef (dokununca açılacak yer)', () => {
  it('yok her zaman geçerli', () => expect(targetError('NONE', '')).toBeNull());
  it('URL yalnızca https://', () => {
    expect(targetError('URL', 'https://bingol.edu.tr/x')).toBeNull();
    expect(targetError('URL', 'http://bingol.edu.tr')).toBe('URL_HTTPS');
    expect(targetError('URL', 'javascript:alert(1)')).toBe('URL_HTTPS');
    expect(targetError('URL', 'https://')).toBe('URL_HTTPS');
    expect(targetError('URL', '')).toBe('URL_HTTPS');
  });
  it('haber/etkinlik/topluluk numarası rakam olmalı', () => {
    for (const t of ['NEWS', 'EVENT', 'COMMUNITY'] as const) {
      expect(targetError(t, '123')).toBeNull();
      expect(targetError(t, '12a')).toBe('ID_REQUIRED');
      expect(targetError(t, '')).toBe('ID_REQUIRED');
    }
  });
});

describe('istek kurma', () => {
  it('SELF + yalnız Türkçe: en/ar gönderilmez, hemen gider', () => {
    const r = buildRequest(filled(), NOW, 1);
    expect(r.valid).toBe(true);
    expect(r.request).toMatchObject({
      type: 'ANNOUNCEMENT',
      audience: { type: 'SELF', value: null },
      tr: { title: 'Başlık', body: 'Metin' },
      target: { type: 'NONE', value: null },
    });
    expect(r.request?.en).toBeUndefined();
    expect(r.request?.ar).toBeUndefined();
    expect(r.request?.scheduledAt).toBeUndefined();
  });
  it('alıcı sayısı 0 veya bilinmiyorsa gönderilemez', () => {
    expect(buildRequest(filled(), NOW, 0).valid).toBe(false);
    expect(buildRequest(filled(), NOW, null).valid).toBe(false);
  });
  it('en/ar dolu ise eklenir; zamanlama ISO UTC olur', () => {
    const s = filled({ scheduleMode: 'later', scheduledLocal: toLocalInput(new Date(NOW.getTime() + 7200_000)) });
    s.contents.en = { title: ' T ', body: ' B ' };
    s.contents.ar = { title: 'ع', body: 'ن' };
    const r = buildRequest(s, NOW, 5);
    expect(r.valid).toBe(true);
    expect(r.request?.en).toEqual({ title: 'T', body: 'B' });
    expect(r.request?.ar).toEqual({ title: 'ع', body: 'ن' });
    expect(r.request?.scheduledAt).toMatch(/^\d{4}-\d{2}-\d{2}T.*Z$/);
  });
  it('geçersiz hedef veya geçmiş zaman isteği engeller', () => {
    expect(buildRequest(filled({ targetType: 'URL', targetValue: 'http://x' }), NOW, 3).valid).toBe(false);
    expect(
      buildRequest(filled({ scheduleMode: 'later', scheduledLocal: toLocalInput(new Date(NOW.getTime() - 60_000)) }), NOW, 3).valid,
    ).toBe(false);
  });
  it('ALL ve SYSTEM çift onay ister', () => {
    expect(needsExtraConfirm({ audienceType: 'ALL', notifType: 'ANNOUNCEMENT' })).toEqual({ all: true, system: false });
    expect(needsExtraConfirm({ audienceType: 'SELF', notifType: 'SYSTEM' })).toEqual({ all: false, system: true });
    expect(needsExtraConfirm({ audienceType: 'SELF', notifType: 'NEWS' })).toEqual({ all: false, system: false });
  });
});

describe('taslak saklama', () => {
  it('kaydeder, geri yükler, temizler', () => {
    const s = filled({ audienceType: 'DEPARTMENT', department: 'Hukuk', notifType: 'SYSTEM' });
    saveDraft(s);
    expect(loadDraft()).toEqual(s);
    clearDraft();
    expect(loadDraft()).toBeNull();
  });
  it('bozuk JSON ve yanlış tipler hata vermez', () => {
    writeStorage('local', DRAFT_KEY, '{bozuk');
    expect(loadDraft()).toBeNull();
    writeStorage('local', DRAFT_KEY, JSON.stringify({ audienceType: 'HEPSI', notifType: 5, contents: { tr: { title: 7 } }, users: [{ id: 'x' }, { id: 3, displayName: 'A', email: 'a@b' }] }));
    const d = loadDraft();
    expect(d?.audienceType).toBe('SELF');
    expect(d?.notifType).toBe('ANNOUNCEMENT');
    expect(d?.contents.tr.title).toBe('');
    expect(d?.users).toEqual([{ id: 3, displayName: 'A', email: 'a@b' }]);
    writeStorage('local', DRAFT_KEY, 'null');
    expect(loadDraft()).toBeNull();
  });
  it('depolama erişimi atarsa bellek yedeğine düşer', () => {
    const orig = Object.getOwnPropertyDescriptor(window, 'localStorage');
    Object.defineProperty(window, 'localStorage', {
      configurable: true,
      get() {
        throw new Error('engellendi');
      },
    });
    try {
      expect(() => saveDraft(filled())).not.toThrow();
      expect(loadDraft()?.contents.tr.title).toBe('Başlık');
    } finally {
      if (orig) Object.defineProperty(window, 'localStorage', orig);
      clearDraft();
    }
    expect(readStorage('local', DRAFT_KEY)).toBeNull();
  });
  it('boş taslak algılanır', () => {
    expect(isDraftEmpty(emptyState())).toBe(true);
    expect(isDraftEmpty(filled())).toBe(false);
  });
});
