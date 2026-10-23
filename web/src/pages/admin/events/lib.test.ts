import { describe, expect, it } from 'vitest';
import { eventTiming, relativeStart } from './lib';

const NOW = new Date('2026-10-23T12:00:00Z');

describe('etkinlik zamanlama vurgusu', () => {
  it('geçmiş / yakında / sonra', () => {
    expect(eventTiming('2026-10-23T11:00:00Z', NOW)).toBe('past');
    expect(eventTiming('2026-10-23T13:00:00Z', NOW)).toBe('soon');
    expect(eventTiming('2026-10-25T11:59:00Z', NOW)).toBe('soon');
    expect(eventTiming('2026-10-25T12:01:00Z', NOW)).toBe('later');
    expect(eventTiming('bozuk', NOW)).toBe('later');
  });
  it('göreli süre yazısı', () => {
    expect(relativeStart('2026-10-23T15:00:00Z', 'en', NOW)).toBe('in 3 hours');
    expect(relativeStart('2026-10-23T12:30:00Z', 'en', NOW)).toBe('in 30 minutes');
  });
});
