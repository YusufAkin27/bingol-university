import { describe, expect, it } from 'vitest';
import { endOfDayIso, isCidr, isDeviceId, isIPv4, isIPv6, isValidBanValue, parseLines, shortDevice } from './logic';

describe('erişim engeli doğrulama', () => {
  it('IPv4', () => {
    expect(isIPv4('203.0.113.7')).toBe(true);
    expect(isIPv4('256.0.0.1')).toBe(false);
    expect(isIPv4('1.2.3')).toBe(false);
    expect(isIPv4('01.2.3.4')).toBe(false);
  });

  it('IPv6', () => {
    expect(isIPv6('2001:db8::1')).toBe(true);
    expect(isIPv6('::1')).toBe(true);
    expect(isIPv6('::ffff:192.0.2.1')).toBe(true);
    expect(isIPv6('1:2:3:4:5:6:7:8')).toBe(true);
    expect(isIPv6('1:2:3:4:5:6:7')).toBe(false);
    expect(isIPv6('2001::db8::1')).toBe(false);
    expect(isIPv6('gggg::1')).toBe(false);
  });

  it('CIDR', () => {
    expect(isCidr('10.0.0.0/8')).toBe(true);
    expect(isCidr('10.0.0.0/33')).toBe(false);
    expect(isCidr('2001:db8::/32')).toBe(true);
    expect(isCidr('2001:db8::/129')).toBe(false);
    expect(isCidr('10.0.0.0')).toBe(false);
  });

  it('cihaz kimliği 8-128 karakter, boşluksuz', () => {
    expect(isDeviceId('abcdefgh')).toBe(true);
    expect(isDeviceId('abcdefg')).toBe(false);
    expect(isDeviceId('a'.repeat(129))).toBe(false);
    expect(isDeviceId('abcd efgh')).toBe(false);
  });

  it('türe göre değer', () => {
    expect(isValidBanValue('IP', ' 1.2.3.4 ')).toBe(true);
    expect(isValidBanValue('CIDR', '1.2.3.4')).toBe(false);
    expect(isValidBanValue('USER', '12')).toBe(true);
    expect(isValidBanValue('USER', '')).toBe(false);
  });

  it('satırları ayrıştırır, yorum ve boş satırları atar', () => {
    expect(parseLines('1.1.1.1\r\n\n# not\n  2.2.2.0/24  ')).toEqual(['1.1.1.1', '2.2.2.0/24']);
  });

  it('bitiş tarihi gelecekte olmalı; cihaz özeti kısalır', () => {
    expect(endOfDayIso('2000-01-01')).toBeNull();
    expect(endOfDayIso('2999-01-01')).not.toBeNull();
    expect(endOfDayIso('')).toBeNull();
    expect(shortDevice('abcdefghijklmnopqrstuvwxyz')).toBe('abcdefgh…wxyz');
  });
});
