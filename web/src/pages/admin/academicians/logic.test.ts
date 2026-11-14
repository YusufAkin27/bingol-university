import { describe, expect, it } from 'vitest';
import { limitStatus, sessionSummary } from './logic';

const s = (absentCount: number, over = false, risk = false) => ({ absentCount, overLimit: over, atRisk: risk });

describe('limitStatus', () => {
  it('COUNT: eşitse "ulaştı", aşıldıysa "aşıldı", bir kala "atRisk"', () => {
    const l = { type: 'COUNT' as const, value: 3 };
    expect(limitStatus(l, s(3, true))).toBe('reached');
    expect(limitStatus(l, s(4, true))).toBe('over');
    expect(limitStatus(l, s(2, false, true))).toBe('atRisk');
    expect(limitStatus(l, s(0))).toBe('ok');
    expect(limitStatus(null, s(9))).toBe('none');
  });
  it('PERCENT: 4 oturum yapılmadan değerlendirilmez', () => {
    const l = { type: 'PERCENT' as const, value: 30 };
    expect(limitStatus(l, s(2, true), 3)).toBe('pending');
    expect(limitStatus(l, s(2, true), 4)).toBe('over');
  });
});

describe('sessionSummary', () => {
  it('izinli, kayıtsız ve bilinmeyen durumlar devamsız sayılmaz', () => {
    const st = [
      { studentId: 1, marks: { '1': 'EXCUSED' } },
      { studentId: 2, marks: { '1': 'NOT_ENROLLED_YET' } },
      { studentId: 3, marks: { '1': 'ABSENT' } },
      { studentId: 4, marks: { '1': 'PRESENT_QR' } },
    ] as never;
    expect(sessionSummary(1, st)).toMatchObject({ present: 1, absent: 1, revoked: 0, total: 4 });
  });
});
