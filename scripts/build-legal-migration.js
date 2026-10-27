#!/usr/bin/env node
// docs/legal/<tur>_<dil>.md dosyalarindan guncel sozlesme migration'ini uretir: V370__legal_texts_v4.sql
// (V290 ilk nesildir, DONDURULMUSTUR; bu betik artik yalniz V370'i yazar. Sonraki metin degisikliginde yeni V37x eklemek icin TARGET'i artirin.)
// Kullanim: node scripts/build-legal-migration.js [--check]   (--check: dosyayi yazmadan ayni mi diye bakar)
// Tek dogruluk kaynagi Markdown dosyalaridir; SQL'i elle DUZENLEMEYIN.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'docs', 'legal');
const OUT = path.join(ROOT, 'backend', 'src', 'main', 'resources', 'db', 'migration', 'V370__legal_texts_v4.sql');
// V370'te metni degisen turler (COOKIES degismedi; gereksiz yeni surum/yeniden onay uretmesin)
const CHANGED = new Set(['TERMS', 'PRIVACY', 'KVKK', 'COMMUNITY_RULES', 'EXPLICIT_CONSENT', 'CONTENT_REMOVAL', 'RETENTION']);

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
const LANGS = ['tr', 'en'];

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

let sql = `-- V370: Sozlesme metinleri 4. nesil (docs/legal/*.md'den scripts/build-legal-migration.js ile URETILDI; elle duzenlemeyin).
-- * Gonderi/yorum/hikaye, takip, kaydetme, etiket, anket, ders programi, cihaz kimligi/erisim engeli, kufur filtresi,
--   push kuyrugu, gonderi videosu yeniden kodlama/sifreleme ve konum toplanmadigi bilgisi metinlere islendi.
-- * Surum numarasi her tur icin COALESCE(MAX(version),0)+1; onceki aktif surumler pasife alinir, yeni tr+en ayni numarayla aktif eklenir.
-- * require_reaccept: TERMS, PRIVACY, KVKK, COMMUNITY_RULES icin TRUE (mevcut kullanicilar yeni surumu yeniden onaylar); digerleri bilgilendirmedir.
-- * COOKIES degismedigi icin yeni surum uretilmez.
`;

for (const [prefix, type, reaccept] of TYPES) {
  if (!CHANGED.has(type)) continue;
  const tr = load(prefix, 'tr');
  const en = load(prefix, 'en');
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
    ('${type}', 'en', v, ${lit(`t_${prefix}_en`, en.title)}, ${lit(`c_${prefix}_en`, en.content)}, ${flag}, TRUE);
END
$do_${prefix}$;
`;
}

if (process.argv.includes('--check')) {
  const cur = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
  if (cur !== sql) {
    console.error('V370 eski: node scripts/build-legal-migration.js calistirin');
    process.exit(1);
  }
  console.log('V370 guncel');
} else {
  fs.writeFileSync(OUT, sql, { encoding: 'utf8' }); // BOM'suz
  console.log(`yazildi: ${OUT} (${sql.length} karakter)`);
}
