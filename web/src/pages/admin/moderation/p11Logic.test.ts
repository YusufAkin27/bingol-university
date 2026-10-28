import { describe, expect, it } from 'vitest';
import type { AdminMessage } from '../../../api/supportAdmin';
import {
  EMPTY_TEMPLATE,
  canAddTemplate,
  canForgive,
  csvName,
  internalNotes,
  mergeThread,
  moveItem,
  parseAssignee,
  restoreAvailability,
  strikeState,
  templateBody,
  templateErrors,
  threadMessages,
} from './p11Logic';

describe('şablon doğrulama', () => {
  const ok = { ...EMPTY_TEMPLATE, code: 'KURAL_IHLALI', textTr: 'Kural ihlali' };

  it('kod kuralı yalnız yeni şablonda aranır', () => {
    expect(templateErrors(ok, true)).toEqual({});
    expect(templateErrors({ ...ok, code: '1abc' }, true).code).toBeDefined();
    expect(templateErrors({ ...ok, code: 'a' }, true).code).toBeDefined();
    expect(templateErrors({ ...ok, code: 'çay' }, true).code).toBeDefined();
    expect(templateErrors({ ...ok, code: '' }, false)).toEqual({});
  });

  it('Türkçe metin zorunlu, en/ar isteğe bağlı, 300 karakter sınırı', () => {
    expect(templateErrors({ ...ok, textTr: '  ' }, true).textTr).toBeDefined();
    expect(templateErrors({ ...ok, textEn: 'x'.repeat(301) }, true).textEn).toBeDefined();
    expect(templateErrors({ ...ok, textAr: 'x'.repeat(300) }, true).textAr).toBeUndefined();
  });

  it('sıra boş ya da 1-5 haneli sayı', () => {
    expect(templateErrors({ ...ok, sortOrder: '' }, true).sortOrder).toBeUndefined();
    expect(templateErrors({ ...ok, sortOrder: '12' }, true).sortOrder).toBeUndefined();
    expect(templateErrors({ ...ok, sortOrder: '-1' }, true).sortOrder).toBeDefined();
    expect(templateErrors({ ...ok, sortOrder: '123456' }, true).sortOrder).toBeDefined();
  });

  it('gövde: yeni şablonda kod büyük harfe çevrilir, düzenlemede kod gönderilmez; boş sıra gönderilmez', () => {
    expect(templateBody({ ...ok, code: ' kural_ihlali ', textEn: ' Rule ', sortOrder: '' }, true)).toEqual({
      code: 'KURAL_IHLALI',
      textTr: 'Kural ihlali',
      textEn: 'Rule',
      textAr: '',
      active: true,
    });
    const edit = templateBody({ ...ok, sortOrder: '30' }, false);
    expect('code' in edit).toBe(false);
    expect(edit.sortOrder).toBe(30);
  });

  it('50 şablon üst sınırı', () => {
    expect(canAddTemplate(49, 50)).toBe(true);
    expect(canAddTemplate(50, 50)).toBe(false);
  });
});

describe('ihlal ve gizlenen içerik durumu', () => {
  it('sayılan / affedilen / itirazla iptal', () => {
    expect(strikeState({ active: true, forgiven: false })).toBe('ACTIVE');
    expect(strikeState({ active: false, forgiven: true })).toBe('FORGIVEN');
    expect(strikeState({ active: false, forgiven: false })).toBe('REVOKED');
    expect(canForgive({ active: true })).toBe(true);
    expect(canForgive({ active: false })).toBe(false);
  });

  it('geri alma yalnız geri alınabilir ve var olan içerikte', () => {
    expect(restoreAvailability({ reversible: true, exists: true })).toEqual({ ok: true });
    expect(restoreAvailability({ reversible: false, exists: true }).why).toBe('admin.p11.hidden.why.notReversible');
    expect(restoreAvailability({ reversible: true, exists: false }).why).toBe('admin.p11.hidden.why.gone');
  });
});

describe('sıralama ve yardımcılar', () => {
  it('moveItem sınırda aynı sırayı döner, orijinali değiştirmez', () => {
    const src = [1, 2, 3];
    expect(moveItem(src, 1, -1)).toEqual([2, 1, 3]);
    expect(moveItem(src, 1, 1)).toEqual([1, 3, 2]);
    expect(moveItem(src, 0, -1)).toEqual([1, 2, 3]);
    expect(moveItem(src, 2, 1)).toEqual([1, 2, 3]);
    expect(moveItem(src, 9, 1)).toEqual([1, 2, 3]);
    expect(src).toEqual([1, 2, 3]);
  });

  it('csvName tarihli dosya adı üretir', () => {
    expect(csvName('raporlar', new Date('2026-10-28T10:00:00Z'))).toBe('raporlar-2026-10-28.csv');
  });

  it('parseAssignee yalnız pozitif tamsayı kabul eder', () => {
    expect(parseAssignee(' 42 ')).toBe(42);
    expect(parseAssignee('0')).toBeNull();
    expect(parseAssignee('-3')).toBeNull();
    expect(parseAssignee('4a')).toBeNull();
    expect(parseAssignee('')).toBeNull();
  });
});

describe('iç not ve mesaj ayrımı', () => {
  const msg = (id: number, internal: boolean, at: string, fromStaff = internal): AdminMessage => ({
    id,
    fromStaff,
    internal,
    text: `m${id}`,
    createdAt: at,
    authorId: null,
  });
  const all = [msg(1, false, '2026-01-01T10:00:00Z'), msg(1, true, '2026-01-01T10:30:00Z')];

  it('sohbet balonlarına iç not girmez; alan yoksa mesaj sayılır', () => {
    expect(threadMessages(all).map((m) => m.id)).toEqual([1]);
    expect(threadMessages(all).every((m) => !m.internal)).toBe(true);
    expect(internalNotes(all)).toHaveLength(1);
    const legacy = [{ id: 7, fromStaff: false, text: 'x', createdAt: '2026-01-01T10:00:00Z' }] as unknown as AdminMessage[];
    expect(threadMessages(legacy)).toHaveLength(1);
    expect(internalNotes(legacy)).toHaveLength(0);
  });

  it('yanıt sonrası iç notlar korunur ve zaman sırası bozulmaz', () => {
    const reply = [
      { id: 1, fromStaff: false, text: 'ilk', createdAt: '2026-01-01T10:00:00Z' },
      { id: 2, fromStaff: true, text: 'yanit', createdAt: '2026-01-01T11:00:00Z' },
    ];
    const merged = mergeThread(reply, all);
    expect(merged.map((m) => `${m.internal ? 'n' : 'm'}${m.id}`)).toEqual(['m1', 'n1', 'm2']);
  });
});
