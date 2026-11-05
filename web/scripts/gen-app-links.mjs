#!/usr/bin/env node
// Uygulama baglantisi dogrulama dosyalari (iOS Universal Links / Android App Links) - docs/SHARING.md
//
// Ortam (Docker build arg ya da ortam degiskeni):
//   APPLE_TEAM_ID            Apple Developer Team ID (10 karakter, ornek ABCDE12345)
//   PLAY_APP_SIGNING_SHA256  Play Console > Play Uygulama Imzalama SHA-256 parmak izi (AA:BB:...; birden cok ise virgulle)
//
// Uretir (dist/ altina; nginx yonlendirmesiz, application/json sunar - web/nginx.conf):
//   dist/.well-known/apple-app-site-association  (uzantisiz)  +  dist/apple-app-site-association (eski iOS)
//   dist/.well-known/assetlinks.json
// Deger bos / yer tutucu (__PLAY_APP_SIGNING_SHA256__) / gecersizse O DOSYA URETILMEZ (nginx yalin 404 verir) ve UYARI basilir;
// derleme basarisiz OLMAZ (paylasim baglantisi yine magaza/web sayfasina duser, yalniz uygulamayi dogrudan acmaz).
// Yalnizca /s/* yolu uygulamaya acilir (paylasim baglantisi: https://bukampus.com.tr/s/{p|r|n|e}/{id}).
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const BUNDLE_ID = 'tr.com.bukampus.app';
export const PLACEHOLDER = '__PLAY_APP_SIGNING_SHA256__';

/** Team ID: 10 buyuk harf/rakam. Gecersizse null. */
export function normalizeTeamId(raw) {
  const v = (raw ?? '').trim().toUpperCase();
  return /^[A-Z0-9]{10}$/.test(v) ? v : null;
}

/** SHA-256 parmak izleri: "AA:BB:..." (32 bayt); iki nokta ustuste yoksa 64 hex de kabul edilir. Gecerliler dizisi (bos olabilir). */
export function normalizeFingerprints(raw) {
  const out = [];
  for (const part of (raw ?? '').split(',')) {
    let v = part.trim().toUpperCase();
    if (!v || v === PLACEHOLDER) continue;
    if (/^[0-9A-F]{64}$/.test(v)) v = v.match(/../g).join(':');
    if (/^([0-9A-F]{2}:){31}[0-9A-F]{2}$/.test(v)) out.push(v);
  }
  return out;
}

export function aasa(teamId) {
  return { applinks: { apps: [], details: [{ appIDs: [`${teamId}.${BUNDLE_ID}`], paths: ['/s/*'] }] } };
}

export function assetlinks(fingerprints) {
  return [
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: { namespace: 'android_app', package_name: BUNDLE_ID, sha256_cert_fingerprints: fingerprints },
    },
  ];
}

function write(path, data) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(data) + '\n');
}

export function generate({ dist, teamId, sha256, log = console }) {
  const result = { aasa: false, assetlinks: false };
  const team = normalizeTeamId(teamId);
  if (team) {
    const doc = aasa(team);
    write(join(dist, '.well-known', 'apple-app-site-association'), doc);
    write(join(dist, 'apple-app-site-association'), doc);
    result.aasa = true;
    log.log(`gen-app-links: apple-app-site-association uretildi (${team}.${BUNDLE_ID}, /s/*)`);
  } else {
    log.warn(
      'gen-app-links: UYARI: APPLE_TEAM_ID bos/gecersiz -> apple-app-site-association URETILMEDI (iOS paylasim baglantisi uygulamayi dogrudan acmaz; docs/SHARING.md)',
    );
  }
  const fps = normalizeFingerprints(sha256);
  if (fps.length) {
    write(join(dist, '.well-known', 'assetlinks.json'), assetlinks(fps));
    result.assetlinks = true;
    log.log(`gen-app-links: assetlinks.json uretildi (${BUNDLE_ID}, ${fps.length} parmak izi)`);
  } else {
    log.warn(
      'gen-app-links: UYARI: PLAY_APP_SIGNING_SHA256 bos/yer tutucu/gecersiz -> assetlinks.json URETILMEDI (Android App Links dogrulanmaz; docs/SHARING.md)',
    );
  }
  return result;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const dist = resolve(dirname(fileURLToPath(import.meta.url)), '..', process.env.DIST_DIR || 'dist');
  generate({ dist, teamId: process.env.APPLE_TEAM_ID, sha256: process.env.PLAY_APP_SIGNING_SHA256 });
}
