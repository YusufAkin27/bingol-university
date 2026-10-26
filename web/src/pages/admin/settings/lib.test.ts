import { describe, expect, it } from 'vitest';
import {
  compareVersions,
  facultiesError,
  moveItem,
  parseFaculties,
  serializeFaculties,
  splitFacultyInput,
  validateSetting,
} from './lib';

describe('etkinlik ayarları', () => {
  it('onay anahtarı yalnızca true/false kabul eder', () => {
    expect(validateSetting('events_require_approval', 'true')).toBeNull();
    expect(validateSetting('events_require_approval', 'false')).toBeNull();
    expect(validateSetting('events_require_approval', 'evet')).toBe('BOOL');
  });
  it('sınırlar 0-1000 arası tam sayıdır', () => {
    for (const k of ['event_max_open_per_user', 'event_daily_create_limit']) {
      expect(validateSetting(k, '0')).toBeNull();
      expect(validateSetting(k, ' 5 ')).toBeNull();
      expect(validateSetting(k, '1000')).toBeNull();
      expect(validateSetting(k, '1001')).toBe('INT');
      expect(validateSetting(k, '-1')).toBe('INT');
      expect(validateSetting(k, '2.5')).toBe('INT');
      expect(validateSetting(k, '')).toBe('INT');
    }
  });
});

describe('fakülte listesi ↔ `;` ayrıştırma', () => {
  it('kırpar, boşları ve tekrarları atar', () => {
    expect(parseFaculties(' Mühendislik ; ; Fen ;Mühendislik;')).toEqual(['Mühendislik', 'Fen']);
    expect(parseFaculties('')).toEqual([]);
    expect(parseFaculties(undefined)).toEqual([]);
  });
  it('serileştirme sıralamayı korur ve gidiş-dönüş yapar', () => {
    const list = ['B Fakültesi', 'A Fakültesi', 'C Fakültesi'];
    expect(serializeFaculties(list)).toBe('B Fakültesi;A Fakültesi;C Fakültesi');
    expect(parseFaculties(serializeFaculties(list))).toEqual(list);
  });
  it('yapıştırılan metni ad ad böler', () => {
    expect(splitFacultyInput('A;B\nC;  ;')).toEqual(['A', 'B', 'C']);
    expect(splitFacultyInput('  Tek ad  ')).toEqual(['Tek ad']);
    expect(splitFacultyInput('   ')).toEqual([]);
  });
  it('ad ≤120, toplam ≤1000 karakter', () => {
    expect(facultiesError(['a'.repeat(120)])).toBeNull();
    expect(facultiesError(['a'.repeat(121)])).toBe('TOO_LONG');
    expect(facultiesError(Array.from({ length: 12 }, (_, i) => `${i}`.padEnd(100, 'x')))).toBe('TOTAL_TOO_LONG');
  });
  it('taşıma sınırda değişmez', () => {
    expect(moveItem(['a', 'b', 'c'], 1, -1)).toEqual(['b', 'a', 'c']);
    expect(moveItem(['a', 'b', 'c'], 1, 1)).toEqual(['a', 'c', 'b']);
    const l = ['a', 'b'];
    expect(moveItem(l, 0, -1)).toBe(l);
    expect(moveItem(l, 1, 1)).toBe(l);
  });
});

describe('ayar doğrulaması (sunucu kurallarıyla uyumlu)', () => {
  it('sürüm biçimi', () => {
    for (const k of ['min_version_android', 'latest_version_ios']) {
      expect(validateSetting(k, '1.2.3')).toBeNull();
      expect(validateSetting(k, '10')).toBeNull();
      expect(validateSetting(k, '1.2.3.4')).toBeNull();
      expect(validateSetting(k, '1.2.3.4.5')).toBe('VERSION');
      expect(validateSetting(k, 'v1.2')).toBe('VERSION');
      expect(validateSetting(k, '')).toBe('VERSION');
      expect(validateSetting(k, '1..2')).toBe('VERSION');
    }
  });
  it('bağlantılar https:// olmalı (boş serbest)', () => {
    for (const k of ['store_url_android', 'store_url_ios', 'banner_url', 'website']) {
      expect(validateSetting(k, 'https://example.com/x')).toBeNull();
      expect(validateSetting(k, '')).toBeNull();
      expect(validateSetting(k, 'http://example.com')).toBe('HTTPS');
      expect(validateSetting(k, 'javascript:alert(1)')).toBe('HTTPS');
    }
  });
  it('bakım modu true/false', () => {
    expect(validateSetting('maintenance_mode', 'true')).toBeNull();
    expect(validateSetting('maintenance_mode', 'false')).toBeNull();
    expect(validateSetting('maintenance_mode', 'evet')).toBe('BOOL');
  });
  it('e-posta biçimi', () => {
    expect(validateSetting('contact_email', '')).toBeNull();
    expect(validateSetting('contact_email', 'a@bingol.edu.tr')).toBeNull();
    expect(validateSetting('support_email', 'yanlis')).toBe('EMAIL');
  });
  it('fakülteler ve serbest metinler', () => {
    expect(validateSetting('faculties', 'A;B')).toBeNull();
    expect(validateSetting('faculties', 'a'.repeat(121))).toBe('TOO_LONG');
    expect(validateSetting('banner_text_tr', 'her şey')).toBeNull();
  });
  it('sürüm karşılaştırması sayısaldır', () => {
    expect(compareVersions('1.10.0', '1.9.3')).toBe(1);
    expect(compareVersions('1.0', '1.0.0')).toBe(0);
    expect(compareVersions('2.0.0', '10.0.0')).toBe(-1);
  });
});
