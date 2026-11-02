import { act, renderHook } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { CODE_RESEND_SECONDS, formatClock, minutesLeft, resendSecondsOf, useResendCountdown } from './resendCountdown';

describe('resendCountdown', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('sabit ve biçim: 180 sn, d:ss', () => {
    expect(CODE_RESEND_SECONDS).toBe(180);
    expect(formatClock(180)).toBe('3:00');
    expect(formatClock(179)).toBe('2:59');
    expect(formatClock(61)).toBe('1:01');
    expect(formatClock(9)).toBe('0:09');
    expect(formatClock(-3)).toBe('0:00');
  });

  it('sunucu yanıtından süre okunur, yoksa 180', () => {
    expect(resendSecondsOf({ resendAfterSeconds: 95 })).toBe(95);
    expect(resendSecondsOf({})).toBe(180);
    expect(resendSecondsOf(null)).toBe(180);
    expect(resendSecondsOf({ resendAfterSeconds: 0 })).toBe(180);
  });

  it('ekran okuyucu özeti dakikaya yuvarlar (yukarı)', () => {
    expect(minutesLeft(180)).toBe(3);
    expect(minutesLeft(121)).toBe(3);
    expect(minutesLeft(120)).toBe(2);
    expect(minutesLeft(1)).toBe(1);
    expect(minutesLeft(0)).toBe(0);
  });

  it('3:00 başlar, saniyede bir azalır, 0 olunca durur', () => {
    const { result } = renderHook(() => useResendCountdown());
    expect(result.current.left).toBe(180);
    act(() => void vi.advanceTimersByTime(1000));
    expect(result.current.left).toBe(179);
    act(() => void vi.advanceTimersByTime(178_000));
    expect(result.current.left).toBe(1);
    act(() => void vi.advanceTimersByTime(1000));
    expect(result.current.left).toBe(0);
    act(() => void vi.advanceTimersByTime(5000));
    expect(result.current.left).toBe(0);
  });

  it('sunucu süresiyle başlar ve restart(sn) kalan süreye ayarlar; 0 başlangıç hazırdır', () => {
    const { result } = renderHook(() => useResendCountdown(95));
    expect(result.current.left).toBe(95);
    act(() => result.current.restart(120));
    expect(result.current.left).toBe(120);
    act(() => void vi.advanceTimersByTime(1000));
    expect(result.current.left).toBe(119);
    act(() => result.current.restart());
    expect(result.current.left).toBe(180);
    const ready = renderHook(() => useResendCountdown(0));
    expect(ready.result.current.left).toBe(0);
    act(() => ready.result.current.restart(30));
    expect(ready.result.current.left).toBe(30);
    act(() => void vi.advanceTimersByTime(30_000));
    expect(ready.result.current.left).toBe(0);
  });
});
