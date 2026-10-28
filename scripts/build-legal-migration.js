#!/usr/bin/env node
// docs/legal/<tur>_<dil>.md dosyalarindan guncel sozlesme migration'ini uretir: V480__legal_texts_v3.sql
// (V290 ve V370 onceki nesillerdir, DONDURULMUSTUR. V480 de artik DONDURULDU: docs/legal V620'de duzeltildi, bu betik V480'i
// yeniden URETMEZ. Sonraki metin degisikligi: scripts/build-legal-migration-v620.js ornegiyle yeni bir V62x betigi/migration'i.)
// Kullanim: node scripts/build-legal-migration.js [--check]   (--check: dosyayi yazmadan ayni mi diye bakar)
// Tek dogruluk kaynagi Markdown dosyalaridir; SQL'i elle DUZENLEMEYIN.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'docs', 'legal');
const OUT = path.join(ROOT, 'backend', 'src', 'main', 'resources', 'db', 'migration', 'V480__legal_texts_v3.sql');
// V480'de tr/en metni degisen turler: yeni surum (tr+en+ar). Digerlerine yalniz mevcut aktif surume ar eklenir (yeniden onay uretmez).
const CHANGED = new Set(['TERMS', 'PRIVACY', 'CONTENT_REMOVAL']);
if (!process.argv.includes('--regenerate-frozen-v480')) {
  console.error('V480 donduruldu (docs/legal V620 icin degisti). Yeni metin: node scripts/build-legal-migration-v620.js');
  process.exit(0);
}

// [dosya oneki, LegalType, kayitta zorunlu onay / yeniden onay]
const TYPES = [
  ['terms', 'TERMS', true],
  ['privacy', 'PRIVACY', true],
  ['kvkk', 'KVKK', true],
  ['community_rules', 'COMMUNITY_RULES', true],
  ['explicit_consent', 'EXPLICIT_CONSENT', false],
  ['cookies', 'COOKIES', false],
  ['content_removal', 'CONTENT_REMOVAL', false],
  ['retention', 'RETENTION', false],
];


function load(prefix, lang) {
  const file = path.join(SRC, `${prefix}_${lang}.md`);
  const raw = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n');
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

let sql = `-- V480: Sozlesme metinleri 5. nesil (docs/legal/*.md'den scripts/build-legal-migration.js ile URETILDI; elle duzenlemeyin).
-- * Arapca (ar) metinler eklendi. Kullanim Kosullari (TERMS), Gizlilik (PRIVACY) ve Icerik Bildirimi (CONTENT_REMOVAL) tr/en metni degistigi icin
--   yeni surum (COALESCE(MAX(version),0)+1) tr+en+ar ayni numarayla aktif eklenir, onceki aktif surumler pasife alinir.
-- * Metni degismeyen turlerde (KVKK, COMMUNITY_RULES, EXPLICIT_CONSENT, COOKIES, RETENTION) mevcut aktif tr surumune ar satiri eklenir; surum degismez, yeniden onay istenmez.
-- * require_reaccept: yeni surumde TERMS ve PRIVACY icin TRUE (mevcut kullanicilar yeniden onaylar), CONTENT_REMOVAL bilgilendirmedir.
-- * Yeni yonetici ayarlari: legal.controller.relation (Universite ile iliski cumlesi), legal.controller.jurisdiction (yetkili mahkeme sehri). Bos birakilirsa metindeki varsayilan cumle/Bingol kullanilir.
-- * Dosya adi V480__legal_texts_v3.sql talep uzerine boyledir (icerik olarak 5. nesil).

INSERT INTO app_setting (setting_key, setting_value) VALUES
 ('legal.controller.relation', ''),
 ('legal.controller.jurisdiction', '')
ON CONFLICT (setting_key) DO NOTHING;
`;

for (const [prefix, type, reaccept] of TYPES) {
  const tr = load(prefix, 'tr');
  const en = load(prefix, 'en');
  const ar = load(prefix, 'ar');
  if (!CHANGED.has(type)) {
    sql += `
-- ${type}: mevcut aktif surume Arapca ekle (yoksa)
INSERT INTO legal_document (type, lang, version, title, content, require_reaccept, active)
SELECT '${type}', 'ar', d.version, ${lit(`t_${prefix}_ar`, ar.title)}, ${lit(`c_${prefix}_ar`, ar.content)}, d.require_reaccept, TRUE
FROM legal_document d
WHERE d.type = '${type}' AND d.lang = 'tr' AND d.active
  AND NOT EXISTS (SELECT 1 FROM legal_document x WHERE x.type = '${type}' AND x.lang = 'ar' AND (x.version = d.version OR x.active));
`;
    continue;
  }
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
    console.error('V480 eski: node scripts/build-legal-migration.js calistirin');
    process.exit(1);
  }
  console.log('V480 guncel');
} else {
  fs.writeFileSync(OUT, sql, { encoding: 'utf8' }); // BOM'suz
  console.log(`yazildi: ${OUT} (${sql.length} karakter)`);
}
