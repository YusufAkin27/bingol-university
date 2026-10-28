// Sohbet müdahalesi (P08) saf mantığı: mesaj durumu, açık işlemler, toplu seçim, dışa aktarma kapısı.
import { describe, expect, it } from 'vitest';
import {
  BULK_HIDE_MAX,
  availableActions,
  exportFileName,
  exportGate,
  isBulkSelectable,
  messageState,
  pruneSelection,
  summarizeBulk,
  toggleSelection,
} from './chatAction';

const base = { deleted: false, hidden: false };

describe('messageState / availableActions', () => {
  it('görünür mesajda yalnız gizle ve kalıcı sil açıktır', () => {
    expect(messageState(base)).toBe('VISIBLE');
    expect(availableActions('VISIBLE')).toEqual({ hide: true, unhide: false, purge: true });
  });
  it('yönetici gizlemesi geri gösterilebilir; moderasyon gizlemesi ve kullanıcı silmesi geri açılamaz', () => {
    const adminHidden = { deleted: false, hidden: true, adminHidden: true };
    expect(messageState(adminHidden)).toBe('ADMIN_HIDDEN');
    expect(availableActions('ADMIN_HIDDEN')).toEqual({ hide: false, unhide: true, purge: true });
    expect(messageState({ deleted: false, hidden: true })).toBe('HIDDEN');
    expect(availableActions('HIDDEN')).toEqual({ hide: false, unhide: false, purge: true });
    expect(messageState({ deleted: true, hidden: false })).toBe('DELETED');
    expect(availableActions('DELETED').hide).toBe(false);
  });
  it('kalıcı silinmiş mesajda hiçbir işlem yoktur (öncelik: PURGED)', () => {
    const purged = { deleted: true, hidden: true, adminHidden: true, purged: true };
    expect(messageState(purged)).toBe('PURGED');
    expect(availableActions('PURGED')).toEqual({ hide: false, unhide: false, purge: false });
  });
});

describe('toplu seçim', () => {
  it('yalnız görünür mesaj seçilebilir', () => {
    expect(isBulkSelectable(base)).toBe(true);
    expect(isBulkSelectable({ deleted: false, hidden: true })).toBe(false);
    expect(isBulkSelectable({ deleted: true, hidden: false })).toBe(false);
    expect(isBulkSelectable({ ...base, purged: true })).toBe(false);
  });
  it('seçim değişmez (yeni Set) ve 200 sınırını aşmaz', () => {
    const empty = new Set<number>();
    const one = toggleSelection(empty, 5, true);
    expect(empty.size).toBe(0);
    expect([...one]).toEqual([5]);
    expect(toggleSelection(one, 5, false).size).toBe(0);
    let full = new Set<number>();
    for (let i = 1; i <= BULK_HIDE_MAX + 5; i++) full = toggleSelection(full, i, true);
    expect(full.size).toBe(BULK_HIDE_MAX);
    expect(BULK_HIDE_MAX).toBe(200);
  });
  it('liste yenilenince artık seçilemeyen kimlikler düşer', () => {
    const sel = new Set([1, 2, 3]);
    const next = pruneSelection(sel, [
      { id: 1, ...base },
      { id: 2, deleted: false, hidden: true, adminHidden: true },
    ]);
    expect([...next]).toEqual([1]);
  });
  it('toplu sonuç özeti başarı/hata sayar ve hata kodlarını tekilleştirir', () => {
    const s = summarizeBulk([
      { ok: true, error: null },
      { ok: false, error: 'MESSAGE_ALREADY_HIDDEN' },
      { ok: false, error: 'MESSAGE_ALREADY_HIDDEN' },
      { ok: false, error: 'MESSAGE_NOT_FOUND' },
    ]);
    expect(s).toEqual({ ok: 1, failed: 3, codes: ['MESSAGE_ALREADY_HIDDEN', 'MESSAGE_NOT_FOUND'] });
  });
});

describe('dışa aktarma iki aşamalı kapı', () => {
  it('sebep 20 karakterden kısaysa ya da sohbet kimliği yazılmadıysa hazır değildir', () => {
    expect(exportGate('on dokuz karakter!!', '42', 42).reasonOk).toBe(false); // 19
    const longReason = 'mahkeme karari 2026/15 sayili dosya';
    expect(exportGate(longReason, '', 42)).toEqual({ reasonOk: true, confirmOk: false, ready: false });
    expect(exportGate(longReason, '41', 42).ready).toBe(false);
    expect(exportGate(longReason, ' 42 ', 42).ready).toBe(true);
  });
  it('boşluklarla şişirilmiş sebep sayılmaz', () => {
    expect(exportGate('   abc   ', '7', 7).reasonOk).toBe(false);
  });
  it('dosya adı sohbet kimliği, biçim ve devam imlecini içerir', () => {
    expect(exportFileName(42, 'json')).toBe('sohbet-42.json');
    expect(exportFileName(42, 'csv', 5000)).toBe('sohbet-42-sonrasi-5000.csv');
  });
});
