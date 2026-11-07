/**
 * Uygulama bağlantısı doğrulama dosyaları (Universal Links / App Links): paylaşım bağlantıları /s/* (docs/SHARING.md).
 * Değerler dağıtımda gelir; yoksa dosya ÜRETİLMEZ (uydurma değer yok) ve nginx yalın 404 verir.
 */
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, describe, expect, it } from 'vitest';
import { aasa, assetlinks, generate, normalizeFingerprints, normalizeTeamId } from '../../scripts/gen-app-links.mjs';

const FP = Array.from({ length: 32 }, (_, i) => (i * 7 + 3).toString(16).padStart(2, '0').toUpperCase()).join(':');
const quiet = { log: () => undefined, warn: () => undefined };
const dirs: string[] = [];
const tmp = () => {
  const d = mkdtempSync(join(tmpdir(), 'applinks-'));
  dirs.push(d);
  return d;
};
afterAll(() => dirs.forEach((d) => rmSync(d, { recursive: true, force: true })));

describe('gen-app-links', () => {
  it('Team ID: 10 büyük harf/rakam; aksi geçersiz', () => {
    expect(normalizeTeamId('abcde12345')).toBe('ABCDE12345');
    expect(normalizeTeamId('SHORT')).toBeNull();
    expect(normalizeTeamId('')).toBeNull();
    expect(normalizeTeamId(undefined)).toBeNull();
    expect(normalizeTeamId('ABCDE1234!')).toBeNull();
  });

  it('parmak izi: yer tutucu ve geçersizler atılır, 64 hex iki nokta üstüste biçimine çevrilir', () => {
    expect(normalizeFingerprints('__PLAY_APP_SIGNING_SHA256__')).toEqual([]);
    expect(normalizeFingerprints('')).toEqual([]);
    expect(normalizeFingerprints('AA:BB')).toEqual([]);
    expect(normalizeFingerprints(FP.toLowerCase())).toEqual([FP]);
    expect(normalizeFingerprints(FP.replaceAll(':', ''))).toEqual([FP]);
    expect(normalizeFingerprints(`${FP}, bozuk ,${FP}`)).toEqual([FP, FP]);
  });

  it('AASA yalnız /s/* yolunu uygulamaya açar', () => {
    expect(aasa('ABCDE12345')).toEqual({
      applinks: { apps: [], details: [{ appIDs: ['ABCDE12345.tr.com.bukampus.app'], paths: ['/s/*'] }] },
    });
  });

  it('assetlinks paket adı ve parmak izini taşır', () => {
    const [entry] = assetlinks([FP]);
    expect(entry.relation).toEqual(['delegate_permission/common.handle_all_urls']);
    expect(entry.target).toEqual({
      namespace: 'android_app',
      package_name: 'tr.com.bukampus.app',
      sha256_cert_fingerprints: [FP],
    });
  });

  it('değerler varsa üç dosya üretilir (uzantısız AASA hem .well-known hem kökte)', () => {
    const dist = tmp();
    const r = generate({ dist, teamId: 'ABCDE12345', sha256: FP, log: quiet });
    expect(r).toEqual({ aasa: true, assetlinks: true });
    const a = JSON.parse(readFileSync(join(dist, '.well-known', 'apple-app-site-association'), 'utf-8'));
    expect(a.applinks.details[0].appIDs[0]).toBe('ABCDE12345.tr.com.bukampus.app');
    expect(readFileSync(join(dist, 'apple-app-site-association'), 'utf-8')).toBe(
      readFileSync(join(dist, '.well-known', 'apple-app-site-association'), 'utf-8'),
    );
    const l = JSON.parse(readFileSync(join(dist, '.well-known', 'assetlinks.json'), 'utf-8'));
    expect(l[0].target.sha256_cert_fingerprints).toEqual([FP]);
  });

  it('değer yoksa/yer tutucuysa dosya ÜRETİLMEZ ve uyarı verilir', () => {
    const dist = tmp();
    const warns: string[] = [];
    const r = generate({
      dist,
      teamId: '',
      sha256: '__PLAY_APP_SIGNING_SHA256__',
      log: { log: () => undefined, warn: (m) => warns.push(m) },
    });
    expect(r).toEqual({ aasa: false, assetlinks: false });
    expect(existsSync(join(dist, '.well-known', 'assetlinks.json'))).toBe(false);
    expect(existsSync(join(dist, '.well-known', 'apple-app-site-association'))).toBe(false);
    expect(existsSync(join(dist, 'apple-app-site-association'))).toBe(false);
    expect(warns).toHaveLength(2);
  });

  it('yalnız biri varsa yalnız o üretilir', () => {
    const dist = tmp();
    expect(generate({ dist, teamId: 'ABCDE12345', sha256: '', log: quiet })).toEqual({ aasa: true, assetlinks: false });
    const dist2 = tmp();
    expect(generate({ dist: dist2, teamId: '', sha256: FP, log: quiet })).toEqual({ aasa: false, assetlinks: true });
  });
});
