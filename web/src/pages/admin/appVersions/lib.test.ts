import { describe, expect, it } from 'vitest';
import type { VersionRow } from '../../../api/appVersions';
import { validateSetting } from '../settings/lib';
import { devicesBelow, enforceIssues, hasStoreLink, impactOf, isInverted, rowStatus } from './lib';

const rows: VersionRow[] = [
  { platform: 'android', version: '2.0.4', devices: 100 },
  { platform: 'android', version: '2.0.2', devices: 30 },
  { platform: 'android', version: '1.9.0', devices: 5 },
  { platform: 'android', version: null, devices: 7 },
  { platform: 'ios', version: '2.0.2', devices: 11 },
];
const store = { storeUrl: '', androidPackage: '', appleAppId: '' };

describe('sürüm dağılımı hesapları', () => {
  it('verilen sürümün altındaki cihazları sayar; bilinmeyenler ve başka platform sayılmaz', () => {
    expect(devicesBelow(rows, 'android', '2.0.5')).toBe(135);
    expect(devicesBelow(rows, 'android', '2.0.3')).toBe(35);
    expect(devicesBelow(rows, 'android', '1.0.0')).toBe(0);
    expect(devicesBelow(rows, 'ios', '2.0.5')).toBe(11);
    expect(devicesBelow(rows, 'android', 'abc')).toBe(0);
  });
  it('sayısal karşılaştırma: 2.0.10 > 2.0.9', () => {
    const r: VersionRow[] = [{ platform: 'android', version: '2.0.9', devices: 4 }];
    expect(devicesBelow(r, 'android', '2.0.10')).toBe(4);
  });
  it('etki: kapatma 0, diğerleri bu sürümün altı', () => {
    expect(impactOf(rows, 'android', 'OFF', '2.0.5')).toBe(0);
    expect(impactOf(rows, 'android', 'FORCE', '2.0.5')).toBe(135);
    expect(impactOf(rows, 'android', 'SOFT', '2.0.3')).toBe(35);
  });
  it('satır durumu', () => {
    const p = { minVersion: '2.0.3', latestVersion: '2.0.5' };
    expect(rowStatus(rows[2], p)).toBe('FORCED');
    expect(rowStatus(rows[0], p)).toBe('SUGGESTED');
    expect(rowStatus({ platform: 'android', version: '2.0.5', devices: 1 }, p)).toBe('CURRENT');
    expect(rowStatus(rows[3], p)).toBe('UNKNOWN');
  });
  it('min > latest tutarsızlığı', () => {
    expect(isInverted('2.1.0', '2.0.5')).toBe(true);
    expect(isInverted('2.0.5', '2.0.5')).toBe(false);
    expect(isInverted('', '2.0.5')).toBe(false);
  });
});

describe('mağaza bağlantısı var mı', () => {
  it('Android her zaman (paket varsayılanı), iOS yalnız kimlik ya da https bağlantı ile', () => {
    expect(hasStoreLink('android', store)).toBe(true);
    expect(hasStoreLink('ios', store)).toBe(false);
    expect(hasStoreLink('ios', { ...store, appleAppId: '6740123456' })).toBe(true);
    expect(hasStoreLink('ios', { ...store, appleAppId: 'id1' })).toBe(false);
    expect(hasStoreLink('ios', { ...store, storeUrl: 'https://apps.apple.com/app/id1' })).toBe(true);
    expect(hasStoreLink('ios', { ...store, storeUrl: 'http://x.y' })).toBe(false);
  });
});

describe('sihirbaz doğrulaması', () => {
  const base = { platform: 'android' as const, min: '1.0.0', latest: '2.0.4', store, rows };
  it('geçersiz sürüm hata', () => {
    expect(enforceIssues({ ...base, mode: 'FORCE', version: '2.x' }).errors).toEqual(['VERSION_INVALID']);
    expect(enforceIssues({ ...base, mode: 'FORCE', version: '' }).errors).toEqual(['VERSION_INVALID']);
  });
  it('zorunlu sürüm yayındakinden düşük olamaz (sunucu ile aynı)', () => {
    expect(enforceIssues({ ...base, mode: 'FORCE', version: '2.0.3' }).errors).toEqual(['BELOW_LATEST']);
    expect(enforceIssues({ ...base, mode: 'FORCE', version: '2.0.4' }).errors).toEqual([]);
  });
  it('öneri zorunlu en düşük sürümün altına inemez', () => {
    expect(enforceIssues({ ...base, min: '2.0.0', mode: 'SOFT', version: '1.9.0' }).errors).toEqual(['BELOW_MIN']);
    expect(enforceIssues({ ...base, min: '2.0.0', mode: 'SOFT', version: '2.0.1' }).errors).toEqual([]);
  });
  it('kapatma sürüm istemez', () => {
    expect(enforceIssues({ ...base, mode: 'OFF', version: '' })).toEqual({ errors: [], warnings: [] });
  });
  it('iOS bağlantısızken zorlama uyarısı: düğme çalışmaz ve iOS mağazada olmayabilir', () => {
    const r = enforceIssues({ ...base, platform: 'ios', latest: '1.0.0', mode: 'FORCE', version: '2.0.2' });
    expect(r.errors).toEqual([]);
    expect(r.warnings).toEqual(['NO_STORE_LINK', 'IOS_NOT_PUBLISHED']);
    const ok = enforceIssues({ ...base, platform: 'ios', latest: '1.0.0', mode: 'FORCE', version: '2.0.2', store: { ...store, appleAppId: '6740123456' } });
    expect(ok.warnings).toEqual([]);
  });
  it('hiçbir cihazda olmayan sürümü zorlamak uyarı verir', () => {
    expect(enforceIssues({ ...base, mode: 'FORCE', version: '9.0.0' }).warnings).toEqual(['ABOVE_EVERYONE']);
    expect(enforceIssues({ ...base, mode: 'FORCE', version: '2.0.4' }).warnings).toEqual([]);
  });
});

describe('yeni ayar doğrulamaları (sunucu ile aynı)', () => {
  it('güncelleme metni', () => {
    expect(validateSetting('update_message_tr', '')).toBeNull();
    expect(validateSetting('update_message_tr', 'Yeni sürüm hazır.')).toBeNull();
    expect(validateSetting('update_message_tr', 'x'.repeat(281))).toBe('MESSAGE');
    expect(validateSetting('update_message_en', '<b>x</b>')).toBe('MESSAGE');
    expect(validateSetting('update_message_en', 'go https://x.example')).toBe('MESSAGE');
    expect(validateSetting('update_message_ar', 'a\nb')).toBe('MESSAGE');
  });
  it('paket adı ve Apple kimliği', () => {
    expect(validateSetting('store_package_android', 'tr.com.bukampus.app')).toBeNull();
    expect(validateSetting('store_package_android', 'tek')).toBe('PACKAGE');
    expect(validateSetting('store_package_android', '')).toBeNull();
    expect(validateSetting('apple_app_id_ios', '6740123456')).toBeNull();
    expect(validateSetting('apple_app_id_ios', 'id123')).toBe('APPLE_ID');
    expect(validateSetting('apple_app_id_ios', '12')).toBe('APPLE_ID');
  });
});
