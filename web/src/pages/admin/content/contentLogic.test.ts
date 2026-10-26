import { describe, expect, it } from 'vitest';
import type { LegalVersionRow } from '../../../api/types';
import { applyFormat } from './markdownFormat';
import {
  acceptanceRatio,
  activeVersion,
  buildPublishRequest,
  emptyDrafts,
  isDirty,
  nextVersion,
} from './legalLogic';

describe('applyFormat', () => {
  it('seçimi kalın yapar ve geri alır', () => {
    const r = applyFormat('merhaba dunya', 0, 7, 'bold');
    expect(r.value).toBe('**merhaba** dunya');
    expect(r.value.slice(r.selStart, r.selEnd)).toBe('merhaba');
    const back = applyFormat(r.value, r.selStart, r.selEnd, 'bold');
    expect(back.value).toBe('merhaba dunya');
  });
  it('seçim yokken yer tutucu ekler', () => {
    const r = applyFormat('', 0, 0, 'italic');
    expect(r.value).toBe('*metin*');
    expect(r.value.slice(r.selStart, r.selEnd)).toBe('metin');
  });
  it('başlık ve liste satır başına önek koyar, tekrar basınca kaldırır', () => {
    const h = applyFormat('a\nb\nc', 2, 2, 'heading');
    expect(h.value).toBe('a\n## b\nc');
    expect(applyFormat(h.value, h.selStart, h.selEnd, 'heading').value).toBe('a\nb\nc');
    const l = applyFormat('x\ny', 0, 3, 'list');
    expect(l.value).toBe('- x\n- y');
  });
  it('bağlantı ekler ve adres kısmını seçer', () => {
    const r = applyFormat('git', 0, 3, 'link');
    expect(r.value).toBe('[git](https://)');
    expect(r.value.slice(r.selStart, r.selEnd)).toBe('https://');
  });
});

describe('buildPublishRequest', () => {
  const filled = { title: 'Başlık', content: 'İçerik' };
  it('tr zorunludur', () => {
    const r = buildPublishRequest(emptyDrafts(), true);
    expect(r.request).toBeNull();
    expect(r.errors).toContain('trRequired');
  });
  it('boş diller Türkçe gösterilecekler listesine girer ve istekte yer almaz', () => {
    const d = { ...emptyDrafts(), tr: filled, en: filled };
    const r = buildPublishRequest(d, true);
    expect(r.errors).toEqual([]);
    expect(r.fallbackLangs).toEqual(['ar']);
    expect(r.included).toEqual(['tr', 'en']);
    expect(r.request).toEqual({ tr: filled, en: filled, requireReaccept: true });
    expect(r.request).not.toHaveProperty('ar');
  });
  it('yarım doldurulmuş dil hatadır', () => {
    const d = { ...emptyDrafts(), tr: filled, ar: { title: 'x', content: '' } };
    expect(buildPublishRequest(d, false).errors).toEqual(['arIncomplete']);
  });
  it('yeniden onay anahtarı isteğe aynen yansır', () => {
    const d = { ...emptyDrafts(), tr: filled };
    expect(buildPublishRequest(d, false).request?.requireReaccept).toBe(false);
    expect(buildPublishRequest(d, true).request?.requireReaccept).toBe(true);
  });
  it('metni kırpar', () => {
    const d = { ...emptyDrafts(), tr: { title: '  A ', content: ' B\n' } };
    expect(buildPublishRequest(d, true).request?.tr).toEqual({ title: 'A', content: 'B' });
  });
});

describe('yardımcılar', () => {
  it('kirli durumu ve sürüm numarasını hesaplar', () => {
    expect(isDirty(emptyDrafts())).toBe(false);
    expect(isDirty({ ...emptyDrafts(), en: { title: 'a', content: '' } })).toBe(true);
    const rows = [
      { version: 2, lang: 'tr', active: true },
      { version: 2, lang: 'en', active: true },
      { version: 1, lang: 'tr', active: false },
    ] as LegalVersionRow[];
    expect(nextVersion(rows)).toBe(3);
    expect(activeVersion(rows, 'en')?.version).toBe(2);
    expect(activeVersion(rows, 'ar')).toBeNull();
    expect(acceptanceRatio(3, 12)).toBeCloseTo(0.25);
    expect(acceptanceRatio(1, 0)).toBe(0);
  });
});
