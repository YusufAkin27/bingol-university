#!/usr/bin/env node
// docs/legal/<tur>_<dil>.md dosyalarindan V1470__legal_texts_any_email.sql migration'ini uretir (2026-11-06: e-posta alan adi kisiti
// kalkti; kayit herhangi bir gecerli e-posta ile + e-posta dogrulama kodu; istege bagli Google/Apple ile giris veri kategorisi).
// Yalniz TERMS, PRIVACY ve KVKK icin YENI SURUM (tr+en+ar ayni numara, eskiler pasif). V820 ve oncesi DONDURULMUSTUR (V820
// kaynaklari docs/legal/archive/v820/ altindadir); sonraki metin degisikliginde yeni bir migration ekleyin ve bu betigin tur
// listesini uyarlayin.
// Kullanim: node scripts/build-legal-migration-v1470.js [--check]   (--check: dosyayi yazmadan ayni mi diye bakar)
// Tek dogruluk kaynagi Markdown dosyalaridir; SQL'i elle DUZENLEMEYIN.
// require_reaccept = FALSE (uc tur): kisit KALDIRILDI (kullanici lehine genisleme), yeni riza gerektiren islem yok; Google/Apple
// girisi sozlesmenin ifasi kapsaminda bir aydinlatma guncellemesidir. Gerekce: docs/LEGAL_NOTES.md bolum 14. Daha once yayimlanmis
// zorunlu onay (V480 TERMS/PRIVACY) bu sayede dusmez: LegalService.pending en yeni require_reaccept=TRUE surumunu arar.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'docs', 'legal');
const OUT = path.join(ROOT, 'backend', 'src', 'main', 'resources', 'db', 'migration', 'V1470__legal_texts_any_email.sql');

// [dosya oneki, LegalType, yeniden onay]
const TYPES = [
  ['terms', 'TERMS', false],
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

let sql = `-- V1470: Hukuki metinler 5. tur (docs/legal/*.md'den scripts/build-legal-migration-v1470.js ile URETILDI; elle duzenlemeyin).
-- * TERMS, PRIVACY ve KVKK icin yeni surum (COALESCE(MAX(version),0)+1) tr+en+ar ayni numarayla aktif eklenir, onceki aktif
--   surumler pasife alinir (eski surumler ve kayitli onaylar DEGISMEZ). Diger turler degismedi.
-- * Icerik: "yalniz bingol.edu.tr e-postasiyla kayit" kisiti kaldirildi (herhangi bir gecerli e-posta + e-posta dogrulama kodu;
--   uyelik bagi dogrulanmaz); Gizlilik/KVKK'ya istege bagli Google/Apple ile giris veri kategorisi eklendi; alan adi denetimi ve
--   "kurumsal e-posta" ifadeleri duzeltildi; EN ve AR metinler TR ile madde madde esit.
-- * require_reaccept = FALSE (uc tur). Gerekce: docs/LEGAL_NOTES.md bolum 14.
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
    console.error('V1470 eski: node scripts/build-legal-migration-v1470.js calistirin');
    process.exit(1);
  }
  console.log('V1470 guncel');
} else {
  fs.writeFileSync(OUT, sql, { encoding: 'utf8' }); // BOM'suz, LF
  console.log(`yazildi: ${OUT} (${sql.length} karakter)`);
}
