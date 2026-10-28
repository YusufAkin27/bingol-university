#!/usr/bin/env node
// docs/legal/<tur>_<dil>.md dosyalarindan V820__legal_terms_v4.sql migration'ini uretir (PAKET LG: kullanim kosullari, KVKK,
// gizlilik, topluluk kurallari, icerik bildirimi ve saklama metinleri icin tek yeni surum; tr+en+ar ayni numara, eskiler pasif).
// V620 ve oncesi DONDURULMUSTUR (V480: scripts/build-legal-migration.js; V620: scripts/build-legal-migration-v620.js). Bu betik
// yalniz V820'yi uretir; sonraki metin degisikliginde yeni bir V82x ekleyin ve hedef/tur listesini uyarlayin.
// Kullanim: node scripts/build-legal-migration-v820.js [--check]   (--check: dosyayi yazmadan ayni mi diye bakar)
// Tek dogruluk kaynagi Markdown dosyalaridir; SQL'i elle DUZENLEMEYIN.
// require_reaccept = FALSE (tum turler): degisiklikler kullanici aleyhine esasli degildir (kaldirilmis ozelliklerin metinden
// cikarilmasi, ucuncu kisi alicisi olmayan satirin kaldirilmasi, mevcut uygulamanin seffaf anlatimi, eksik EN/AR ceviri).
// Gerekce: docs/LEGAL_NOTES.md bolum 9. Daha once yayimlanmis zorunlu onay (ornegin V480 TERMS/PRIVACY) bu sayede dusmez:
// LegalService.pending en yeni require_reaccept=TRUE surumunu arar.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'docs', 'legal');
const OUT = path.join(ROOT, 'backend', 'src', 'main', 'resources', 'db', 'migration', 'V820__legal_terms_v4.sql');

// [dosya oneki, LegalType, yeniden onay]
const TYPES = [
  ['terms', 'TERMS', false],
  ['privacy', 'PRIVACY', false],
  ['kvkk', 'KVKK', false],
  ['community_rules', 'COMMUNITY_RULES', false],
  ['content_removal', 'CONTENT_REMOVAL', false],
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

let sql = `-- V820: Hukuki metinler 4. tur (docs/legal/*.md'den scripts/build-legal-migration-v820.js ile URETILDI; elle duzenlemeyin).
-- * TERMS, PRIVACY, KVKK, COMMUNITY_RULES, CONTENT_REMOVAL ve RETENTION icin yeni surum (COALESCE(MAX(version),0)+1) tr+en+ar ayni
--   numarayla aktif eklenir, onceki aktif surumler pasife alinir. EXPLICIT_CONSENT ve COOKIES degismedi.
-- * Icerik: kaldirilmis ozellikler (yorum, hikaye, gonderi videosu, etiket/ani, kaydet) metinlerden cikarildi; gonderi = tek fotograf +
--   en cok 7 kelime + begeni; KVKK/Gizlilik alici tablosundan Universite satiri kaldirildi (kod dogrulamasi: uygulama kullanici verisini
--   universiteye gondermez); sohbet videosunda ust verinin sunucuda temizlenmedigi acikca yazildi; yonetici rolleri (tam, moderator,
--   destek, editor, salt okunur) ve ozel yazismaya erisim sartlari (yalniz tam yonetici + moderator, yazili gerekce, degistirilemez kayit);
--   cok hesapli bildirimle otomatik gecici gizleme; kulup sahibi hesabi silinince devir/kapatma; 5651 trafik bilgisi saklama beyani
--   gercek 90 gunluk uygulamaya gore duzeltildi; EN ve AR metinler TR ile madde madde esit (tam ceviri).
-- * require_reaccept = FALSE (tum turler). Gerekce: docs/LEGAL_NOTES.md bolum 9.
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
    console.error('V820 eski: node scripts/build-legal-migration-v820.js calistirin');
    process.exit(1);
  }
  console.log('V820 guncel');
} else {
  fs.writeFileSync(OUT, sql, { encoding: 'utf8' }); // BOM'suz
  console.log(`yazildi: ${OUT} (${sql.length} karakter)`);
}
