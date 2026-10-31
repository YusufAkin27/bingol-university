import { describe, expect, it } from 'vitest';
import { ApiError } from './client';
import { adminSeg, cleanReason, guardHeaders, hasControlChars } from './guard';

describe('guardHeaders', () => {
  it('sebep ve anahtar yoksa başlık eklenmez', () => {
    expect(guardHeaders()).toBeUndefined();
    expect(guardHeaders({ reason: '   ' })).toBeUndefined();
  });
  it('sebep yüzde-kodlu X-Admin-Reason olarak, anahtar Idempotency-Key olarak gider', () => {
    const h = guardHeaders({ reason: ' Görev değişikliği ', idempotencyKey: 'k-1' })!.headers!;
    expect(h['Idempotency-Key']).toBe('k-1');
    expect(h['X-Admin-Reason']).toBe(encodeURIComponent('Görev değişikliği'));
    expect(decodeURIComponent(h['X-Admin-Reason'])).toBe('Görev değişikliği');
  });
});

describe('sebep temizliği (W1-B T-013: REASON_INVALID önlemi)', () => {
  it('satır sonu / sekme / NUL boşluğa çevrilir; başlıkta kontrol karakteri kalmaz', () => {
    const raw = 'ilk satır' + String.fromCharCode(13, 10) + 'ikinci' + String.fromCharCode(9) + 'üçüncü' + String.fromCharCode(0);
    expect(hasControlChars(raw)).toBe(true);
    expect(cleanReason(raw)).toBe('ilk satır  ikinci üçüncü');
    const h = guardHeaders({ reason: raw })!.headers!['X-Admin-Reason'];
    expect(decodeURIComponent(h)).toBe('ilk satır  ikinci üçüncü');
    expect(hasControlChars(decodeURIComponent(h))).toBe(false);
  });
  it('düz Türkçe metin değişmez', () => {
    expect(hasControlChars('Şikâyet incelemesi')).toBe(false);
    expect(cleanReason('  Şikâyet incelemesi ')).toBe('Şikâyet incelemesi');
  });
});

describe('adminSeg (W1-B T-010: ADMIN_PATH_INVALID önlemi)', () => {
  it('e-postadaki @ yalnız %40 olur ve kabul edilir', () => {
    expect(adminSeg('a@bingol.edu.tr')).toBe('a%40bingol.edu.tr');
    expect(adminSeg('legal.controller.name')).toBe('legal.controller.name');
    expect(adminSeg(12)).toBe('12');
  });
  it('/ ve boşluk gibi %xx üreten değer sunucuya gitmeden ADMIN_PATH_INVALID ile reddedilir', () => {
    for (const bad of ['a/b', 'a b', 'a%b', 'a?b', 'a#b']) {
      let err: unknown;
      try {
        adminSeg(bad);
      } catch (e) {
        err = e;
      }
      expect(err).toBeInstanceOf(ApiError);
      expect((err as ApiError).code).toBe('ADMIN_PATH_INVALID');
    }
  });
});
