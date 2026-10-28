import { describe, expect, it } from 'vitest';
import type { OutboxRow } from '../../../api/adminMailOps';
import {
  barPercent,
  bulkEligibility,
  isSuppressionFormValid,
  isUserOptOut,
  quotaLevel,
  removalPolicy,
  statusTone,
  summarizeBulk,
} from './mailOpsLogic';

const row = (id: number, retryable: boolean, cancellable: boolean): OutboxRow => ({
  id,
  status: 'DEAD',
  template: 'ANNOUNCEMENT',
  category: 'ANNOUNCEMENT',
  toMasked: 'a***@b.co',
  lang: 'tr',
  attempts: 0,
  nextAttemptAt: null,
  createdAt: '2026-10-28T10:00:00Z',
  sentAt: null,
  lastError: null,
  retryable,
  cancellable,
});

describe('bastırma kaldırma kuralı', () => {
  it('kullanıcının kendi çıkışı: güçlü onay, 20 karakter, e-postayı yazdır', () => {
    for (const reason of ['UNSUBSCRIBED', 'COMPLAINT'] as const) {
      expect(isUserOptOut(reason)).toBe(true);
      expect(removalPolicy({ reason, fullEmail: 'a@b.co', hashPrefix: 'abc' })).toEqual({
        minReason: 20,
        strong: true,
        typeTarget: 'a@b.co',
      });
    }
  });

  it('adres çözülemezse özet ön ekini yazdırır', () => {
    expect(removalPolicy({ reason: 'UNSUBSCRIBED', fullEmail: null, hashPrefix: 'abcdef1234' }).typeTarget).toBe('abcdef1234');
  });

  it('BOUNCED/MANUAL: 5 karakter, yazarak onay yok', () => {
    for (const reason of ['BOUNCED', 'MANUAL'] as const) {
      expect(isUserOptOut(reason)).toBe(false);
      expect(removalPolicy({ reason, fullEmail: null, hashPrefix: 'x' })).toEqual({ minReason: 5, strong: false, typeTarget: null });
    }
  });

  it('sunucu kuralı önceliklidir', () => {
    expect(
      removalPolicy({ reason: 'BOUNCED', fullEmail: null, hashPrefix: 'x', removeMinReason: 30, removeNeedsConfirm: true }).minReason,
    ).toBe(30);
  });
});

describe('ekleme formu', () => {
  it('e-posta biçimi ve not >= 5', () => {
    expect(isSuppressionFormValid('a@b.co', 'sebep var')).toBe(true);
    expect(isSuppressionFormValid('a@b.co', 'abc')).toBe(false);
    expect(isSuppressionFormValid('yok', 'sebep var')).toBe(false);
    expect(isSuppressionFormValid('a b@c.co', 'sebep var')).toBe(false);
    expect(isSuppressionFormValid('a@b', 'sebep var')).toBe(false);
  });
});

describe('kota düzeyi', () => {
  it('eşikler: 79 normal, 80 uyarı, 95 kritik, sınırsız kapalı', () => {
    expect(quotaLevel(79.9)).toBe('OK');
    expect(quotaLevel(80)).toBe('WARN');
    expect(quotaLevel(94.9)).toBe('WARN');
    expect(quotaLevel(95)).toBe('CRITICAL');
    expect(quotaLevel(130)).toBe('CRITICAL');
    expect(quotaLevel(-1)).toBe('OFF');
  });
  it('çubuk yüzdesi 0-100 arasına kırpılır', () => {
    expect(barPercent(-1)).toBe(0);
    expect(barPercent(42.4)).toBe(42);
    expect(barPercent(180)).toBe(100);
  });
});

describe('kuyruk yardımcıları', () => {
  it('toplu uygunluk sayar', () => {
    const rows = [row(1, true, false), row(2, false, true), row(3, true, true), row(4, false, false)];
    expect(bulkEligibility(rows, new Set([1, 2, 3]))).toEqual({ total: 3, retryable: 2, cancellable: 2, overLimit: false });
  });
  it('toplu sonuç hata kodlarına göre özetlenir', () => {
    expect(
      summarizeBulk({
        action: 'RETRY',
        requested: 4,
        succeeded: 1,
        failed: [
          { id: 1, code: 'A' },
          { id: 2, code: 'B' },
          { id: 3, code: 'A' },
        ],
      }),
    ).toEqual([
      { code: 'A', count: 2 },
      { code: 'B', count: 1 },
    ]);
  });
  it('durum tonları', () => {
    expect(statusTone('SENT')).toBe('success');
    expect(statusTone('DEAD')).toBe('danger');
    expect(statusTone('SKIPPED')).toBe('neutral');
  });
});
