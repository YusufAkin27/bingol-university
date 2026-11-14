#!/usr/bin/env node
// docs/legal/<tur>_<dil>.md dosyalarindan V1910__legal_texts_academician.sql migration'ini uretir (2026-11-14: akademisyen alani,
// ders kaydi, QR ile ders yoklamasi, ogrenci rehberi, ders duyurulari ve devamsizlik uyarilari icin aydinlatma guncellemesi).
// TERMS, PRIVACY, KVKK ve RETENTION icin YENI SURUM (tr+en+ar ayni numara, eskiler pasif). V1470 ve oncesi DONDURULMUSTUR
// (V1470 kaynaklari docs/legal/archive/v1470/, V820'nin saklama metni docs/legal/archive/v820/ altindadir); sonraki metin
// degisikliginde yeni bir migration ekleyin ve bu betigin tur listesini uyarlayin.
// Kullanim: node scripts/build-legal-migration-v1910.js [--check]   (--check: dosyayi yazmadan ayni mi diye bakar)
// Tek dogruluk kaynagi Markdown dosyalaridir; SQL'i elle DUZENLEMEYIN.
// require_reaccept: TERMS, PRIVACY, KVKK = TRUE (yeni islem amaci ve yeni veri kategorisi; V820/V1470'teki "yeni amac yok"
// gerekcesi bu surum icin gecerli DEGIL; muhafazakar secim, bkz. docs/LEGAL_NOTES.md bolum 15). RETENTION = FALSE (bilgilendirme).
// Yayin sirasi: hukuk onayi olmadan bu migration prod'a UYGULANMAMALIDIR (docs/legal/internal/academician-revision-notes.md).
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'docs', 'legal');
const OUT = path.join(ROOT, 'backend', 'src', 'main', 'resources', 'db', 'migration', 'V1910__legal_texts_academician.sql');

// [dosya oneki, LegalType, yeniden onay]
const TYPES = [
  ['terms', 'TERMS', true],
  ['privacy', 'PRIVACY', true],
  ['kvkk', 'KVKK', true],
  ['retention', 'RETENTION', false],
];

function load(prefix, lang) {
  const file = path.join(SRC, `${prefix}_${lang}.md`);
  const raw = fs.readFileSync(file, 'utf8').replace(/^﻿/, '').replace(/\r\n?/g, '\n');
  const m = /^# (.+)\n/.exec(raw);
  if (!m) throw new Error(`${file}: ilk satir "# Baslik" olmali`);
  const title = m[1].trim();
  const content = raw.slice(m[0].length).trim();
  if (title.length > 200) throw new Error(`${file}: baslik 200 karakteri asiyor`);
  if (content.length > 100000) throw new Error(`${file}: icerik 100000 karakteri asiyor`);
  return { title, content };
}

function lit(tag, text) {
  const t = `$${tag}$`;
  if (text.includes(t)) throw new Error(`metin ${t} iceriyor`);
  return `${t}${text}${t}`;
}

let sql = `-- V1910: Hukuki metinler 6. tur (akademisyen alani) (docs/legal/*.md'den scripts/build-legal-migration-v1910.js ile URETILDI; elle duzenlemeyin).
-- * TERMS, PRIVACY, KVKK ve RETENTION icin yeni surum (COALESCE(MAX(version),0)+1) tr+en+ar ayni numarayla aktif eklenir, onceki aktif
--   surumler pasife alinir (eski surumler ve kayitli onaylar DEGISMEZ). Diger turler degismedi.
-- * Icerik: akademisyen basvurusu, onayli akademisyene ogrenci rehberi (ad, ogrenci no, fakulte, bolum, sinif), derse ekleme,
--   QR/elle ders yoklamasi, devamsizlik uyarilari, ders duyurulari ve ekleri; yonetici salt okunur izleme; saklama ve silme
--   kapsami (ders/hesap silinene kadar, otomatik sure yok); konum ve cihaz kimligi ISLENMEZ. EN ve AR metinler TR ile bolum bolum esit.
-- * require_reaccept = TRUE (TERMS, PRIVACY, KVKK), FALSE (RETENTION). Gerekce: docs/LEGAL_NOTES.md bolum 15.
-- * HUKUK ONAYI OLMADAN PROD'A UYGULANMAMALIDIR (docs/legal/internal/academician-revision-notes.md "ACIK SORULAR").
`;

for (const [prefix, type, reaccept] of TYPES) {
  const tr = load(prefix, 'tr');
  const en = load(prefix, 'en');
  const ar = load(prefix, 'ar');
  const flag = reaccept ? 'TRUE' : 'FALSE';
  sql += `
DO $do_${prefix}$
DECLARE
    v INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1 INTO v FROM legal_document WHERE type = '${type}';
    UPDATE legal_document SET active = FALSE WHERE type = '${type}' AND active;
    INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active) VALUES
    ('${type}', 'tr', v, ${lit(`t_${prefix}_tr`, tr.title)}, ${lit(`c_${prefix}_tr`, tr.content)}, ${flag}, TRUE),
    ('${type}', 'en', v, ${lit(`t_${prefix}_en`, en.title)}, ${lit(`c_${prefix}_en`, en.content)}, ${flag}, TRUE),
    ('${type}', 'ar', v, ${lit(`t_${prefix}_ar`, ar.title)}, ${lit(`c_${prefix}_ar`, ar.content)}, ${flag}, TRUE);
END
$do_${prefix}$;
`;
}

if (process.argv.includes('--check')) {
  const cur = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8').replace(/\r\n/g, '\n') : '';
  if (cur !== sql) {
    console.error('V1910 eski: node scripts/build-legal-migration-v1910.js calistirin');
    process.exit(1);
  }
  console.log('V1910 guncel');
} else {
  fs.writeFileSync(OUT, sql, { encoding: 'utf8' }); // BOM'suz, LF
  console.log(`yazildi: ${OUT} (${sql.length} karakter)`);
}
