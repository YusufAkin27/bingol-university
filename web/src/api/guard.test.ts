import { describe, expect, it } from 'vitest';
import { guardHeaders } from './guard';

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
