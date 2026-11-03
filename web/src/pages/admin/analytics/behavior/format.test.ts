import { describe, expect, it } from 'vitest';
import {
  actionLabel,
  activePreset,
  clampRange,
  drawerDays,
  formatClock,
  formatDec,
  formatDuration,
  formatInt,
  formatOffset,
  formatPct,
  formatPctPoints,
  heat,
  parseRange,
  presetRange,
  rangeDays,
  reasonLabel,
  screenKey,
  screenLabel,
} from './format';

describe('formatDuration', () => {
  it('milisaniyeyi okunur süreye çevirir', () => {
    expect(formatDuration(0)).toBe('0 sn');
    expect(formatDuration(400)).toBe('< 1 sn');
    expect(formatDuration(1000)).toBe('1 sn');
    expect(formatDuration(45_000)).toBe('45 sn');
    expect(formatDuration(60_000)).toBe('1 dk');
    expect(formatDuration(134_000)).toBe('2 dk 14 sn');
    expect(formatDuration(3_600_000)).toBe('1 sa');
    expect(formatDuration(3_900_000)).toBe('1 sa 5 dk');
  });
  it('veri yoksa ya da geçersizse tire yazar', () => {
    expect(formatDuration(null)).toBe('—');
    expect(formatDuration(undefined)).toBe('—');
    expect(formatDuration(-5)).toBe('—');
    expect(formatDuration(Number.NaN)).toBe('—');
  });
});

describe('sayı ve oran biçimleri', () => {
  it('oranı yüzdeye çevirir (virgüllü)', () => {
    expect(formatPct(0.123)).toBe('%12,3');
    expect(formatPct(0)).toBe('%0');
    expect(formatPct(1)).toBe('%100');
    expect(formatPct(null)).toBe('—');
    expect(formatPctPoints(7.25)).toBe('%7,3');
  });
  it('tam ve ondalıklı sayı', () => {
    expect(formatInt(12345)).toBe('12.345');
    expect(formatDec(3.44)).toBe('3,4');
    expect(formatInt(null)).toBe('—');
  });
  it('ısı oranı 0..1 ile sınırlıdır', () => {
    expect(heat(5, 10)).toBe(0.5);
    expect(heat(20, 10)).toBe(1);
    expect(heat(5, 0)).toBe(0);
    expect(heat(-1, 10)).toBe(0);
  });
});

describe('ekran ve eylem adları', () => {
  it('rota adı biçimlerini aynı anahtara indirger', () => {
    expect(screenKey('/chat-detail')).toBe('chat_detail');
    expect(screenKey('ChatDetailPage')).toBe('chat_detail');
    expect(screenKey('news_detail')).toBe('news_detail');
    expect(screenKey('/home/')).toBe('home');
  });
  it('bilinen rotayı Türkçeleştirir, bilinmeyeni olduğu gibi bırakır', () => {
    expect(screenLabel('/home')).toBe('Ana Sayfa');
    expect(screenLabel('NewsDetailPage')).toBe('Haber Detayı');
    expect(screenLabel('/yeni-ekran-x')).toBe('/yeni-ekran-x');
    expect(screenLabel('')).toBe('Bilinmeyen');
    expect(screenLabel(null)).toBe('Bilinmeyen');
  });
  it('eylem ve bitiş nedeni etiketleri', () => {
    expect(actionLabel('like')).toBe('Beğeni');
    expect(actionLabel('yeni_eylem')).toBe('yeni_eylem');
    expect(reasonLabel('background')).toBe('Arka plana atıldı');
    expect(reasonLabel('derived')).toBe('Türetilmiş (eski sürüm)');
  });
});

describe('tarih aralığı', () => {
  const now = new Date('2026-11-03T09:00:00Z');
  it('gün sayısı uçlar dahildir', () => {
    expect(rangeDays({ from: '2026-11-01', to: '2026-11-03' })).toBe(3);
    expect(rangeDays({ from: '2026-11-03', to: '2026-11-03' })).toBe(1);
    expect(rangeDays({ from: '2026-11-04', to: '2026-11-03' })).toBe(0);
  });
  it('hazır seçim bugünü (İstanbul) dahil eder', () => {
    expect(presetRange(7, now)).toEqual({ from: '2026-10-28', to: '2026-11-03' });
    expect(activePreset({ from: '2026-10-28', to: '2026-11-03' }, now)).toBe(7);
    expect(activePreset({ from: '2026-10-29', to: '2026-11-03' }, now)).toBeNull();
  });
  it('45 günü aşan aralık bitiş korunarak kısaltılır, ters aralık düzeltilir', () => {
    const r = clampRange({ from: '2026-01-01', to: '2026-11-03' });
    expect(rangeDays(r)).toBe(45);
    expect(r.to).toBe('2026-11-03');
    expect(r.from).toBe('2026-09-20');
    expect(clampRange({ from: '2026-11-03', to: '2026-11-01' })).toEqual({ from: '2026-11-01', to: '2026-11-03' });
  });
  it('URL değeri geçersizse son 7 güne döner', () => {
    expect(parseRange(null, null, now)).toEqual(presetRange(7, now));
    expect(parseRange('x', '2026-11-03', now)).toEqual(presetRange(7, now));
    expect(parseRange('2026-10-01', '2026-10-10', now)).toEqual({ from: '2026-10-01', to: '2026-10-10' });
  });
  it('çekmece gün sayısı 1..45', () => {
    expect(drawerDays({ from: '2026-11-03', to: '2026-11-03' })).toBe(1);
    expect(drawerDays({ from: '2026-10-28', to: '2026-11-03' })).toBe(7);
    expect(drawerDays({ from: '2026-01-01', to: '2026-11-03' })).toBe(45);
  });
});

describe('zaman çizelgesi biçimleri', () => {
  it('saat İstanbul dilimindedir (UTC+3)', () => {
    expect(formatClock('2026-11-03T11:03:22Z')).toBe('14:03:22');
    expect(formatClock(null)).toBe('—');
    expect(formatClock('bozuk')).toBe('—');
  });
  it('oturum başından geçen süre dk:sn', () => {
    expect(formatOffset('2026-11-03T11:00:00Z', '2026-11-03T11:00:12Z')).toBe('+0:12');
    expect(formatOffset('2026-11-03T11:00:00Z', '2026-11-03T11:02:05Z')).toBe('+2:05');
  });
});
