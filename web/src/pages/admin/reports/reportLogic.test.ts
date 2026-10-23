import { describe, expect, it } from 'vitest';
import type { ReportView } from '../../../api/types';
import { buildResolveRequest, countByTarget, moveSelection, validateDecision } from './reportLogic';

const rep = (id: number, targetId: number): ReportView => ({
  id,
  reporterId: 1,
  targetType: 'USER',
  targetId,
  reason: 'SPAM',
  note: null,
  status: 'OPEN',
  resolution: null,
  createdAt: '2026-01-01T00:00:00Z',
});

describe('karar doğrulaması', () => {
  it('askıya almada neden zorunlu', () => {
    expect(validateDecision('SUSPEND_USER', '  ')).toBe('reasonRequired');
    expect(validateDecision('SUSPEND_USER', 'spam hesabı')).toBeNull();
  });
  it('diğer kararlarda mesaj isteğe bağlı, 300 karakter üstü reddedilir', () => {
    expect(validateDecision('DISMISS', '')).toBeNull();
    expect(validateDecision('WARN', '')).toBeNull();
    expect(validateDecision('WARN', 'x'.repeat(301))).toBe('tooLong');
  });
  it('istek gövdesi yalnızca gerekli kararlarda mesaj taşır', () => {
    expect(buildResolveRequest('DISMISS', 'not')).toEqual({ action: 'DISMISS' });
    expect(buildResolveRequest('HIDE', 'not')).toEqual({ action: 'HIDE' });
    expect(buildResolveRequest('WARN', ' dikkat ')).toEqual({ action: 'WARN', message: 'dikkat' });
    expect(buildResolveRequest('WARN', '')).toEqual({ action: 'WARN' });
  });
});

describe('kuyruk yardımcıları', () => {
  it('aynı hedefe gelen raporları sayar', () => {
    const m = countByTarget([rep(1, 5), rep(2, 5), rep(3, 6)]);
    expect(m.get('USER:5')).toBe(2);
    expect(m.get('USER:6')).toBe(1);
  });
  it('j/k gezinmesi sınırlarda durur', () => {
    expect(moveSelection(-1, 1, 3)).toBe(0);
    expect(moveSelection(-1, -1, 3)).toBe(2);
    expect(moveSelection(2, 1, 3)).toBe(2);
    expect(moveSelection(0, -1, 3)).toBe(0);
    expect(moveSelection(0, 1, 0)).toBe(-1);
  });
});
