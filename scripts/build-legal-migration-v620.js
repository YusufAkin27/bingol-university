#!/usr/bin/env node
// docs/legal/<tur>_<dil>.md dosyalarindan V620__legal_retention_fix.sql migration'ini uretir (KVKK / saklama suresi duzeltmesi).
// V480 ve oncesi DONDURULMUSTUR (scripts/build-legal-migration.js artik V480'i yeniden uretmez); sonraki metin
// degisikliginde yeni bir V62x ekleyin ve bu betigin hedef/tur listesini uyarlayin.
// Kullanim: node scripts/build-legal-migration-v620.js [--check]   (--check: dosyayi yazmadan ayni mi diye bakar)
// Tek dogruluk kaynagi Markdown dosyalaridir; SQL'i elle DUZENLEMEYIN.
// Yalnizca RETENTION, PRIVACY ve KVKK icin YENI SURUM (tr+en+ar ayni numara, eskiler pasif).
// require_reaccept = FALSE: saklama sureleri koddaki gercek (daha kisa) degerlere gore duzeltildi, yeni veri isleme
// getirilmedi; bu bilgilendirme niteligindeki duzeltmedir (gerekce: docs/LEGAL_NOTES.md). Daha once yayimlanmis zorunlu
// onay (ornegin V480 PRIVACY) bu sayede dusmez: LegalService.pending en yeni zorunlu surumu aranir.
'use strict';
const fs = require('fs');
const path = require('path');

// V620 de artik DONDURULDU: docs/legal V820'de degisti, bu betik V620'yi yeniden URETMEZ (--check dahil). Yeni metin: scripts/build-legal-migration-v820.js
if (!process.argv.includes('--regenerate-frozen-v620')) {
  console.error('V620 donduruldu (docs/legal V820 icin degisti). Yeni metin: node scripts/build-legal-migration-v820.js');
  process.exit(0);
}

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'docs', 'legal');
const OUT = path.join(ROOT, 'backend', 'src', 'main', 'resources', 'db', 'migration', 'V620__legal_retention_fix.sql');

// [dosya oneki, LegalType, yeniden onay]
const TYPES = [
  ['retention', 'RETENTION', false],
  ['privacy', 'PRIVACY', false],
  ['kvkk', 'KVKK', false],
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

let sql = `-- V620: Saklama/aydinlatma metinleri duzeltmesi (docs/legal/*.md'den scripts/build-legal-migration-v620.js ile URETILDI; elle duzenlemeyin).
-- * RETENTION, PRIVACY ve KVKK icin yeni surum (COALESCE(MAX(version),0)+1) tr+en+ar ayni numarayla aktif eklenir, onceki aktif surumler pasife alinir.
-- * Duzeltmeler koddaki gercek degerlere gore: analitik ham olay 45 gun, bildirim kutusu okunmus 30 / okunmamis 90 gun (+200 sinir),
--   e-posta kuyrugu gonderilen 7 / basarisiz 30 gun, kampanya kayitlari 180 gun, gunluk aktiflik 400 gun, admin islem kaydi 365 gun,
--   mesaj erisim ve kulup islem kaydi 730 gun; hikaye/yorum/etiket ifadeleri kaldirildi (V470); e-posta saglayicisi (Brevo) ve
--   bildirim saglayicisi (Firebase) aktarim satirlari; hesap silme kapsami (sahipsiz kulup, etkinlik basvurulari, gorseller).
-- * require_reaccept = FALSE (bilgilendirme duzeltmesi; yeni veri isleme yok, sureler kisaldi). Gerekce: docs/LEGAL_NOTES.md.
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
  const cur = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
  if (cur !== sql) {
    console.error('V620 eski: node scripts/build-legal-migration-v620.js calistirin');
    process.exit(1);
  }
  console.log('V620 guncel');
} else {
  fs.writeFileSync(OUT, sql, { encoding: 'utf8' }); // BOM'suz
  console.log(`yazildi: ${OUT} (${sql.length} karakter)`);
}
