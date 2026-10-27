#!/usr/bin/env node
// docs/legal/<tur>_<dil>.md dosyalarindan backend/src/main/resources/db/migration/V290__legal_texts_v3.sql uretir.
// Kullanim: node scripts/build-legal-migration.js [--check]   (--check: dosyayi yazmadan ayni mi diye bakar)
// Tek dogruluk kaynagi Markdown dosyalaridir; SQL'i elle DUZENLEMEYIN.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'docs', 'legal');
const OUT = path.join(ROOT, 'backend', 'src', 'main', 'resources', 'db', 'migration', 'V290__legal_texts_v3.sql');

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

const names = TYPES.map((t) => `'${t[1]}'`).join(', ');
let sql = `-- V290: Sozlesme metinleri 3. nesil (docs/legal/*.md'den scripts/build-legal-migration.js ile URETILDI; elle duzenlemeyin).
-- * legal_type_check 8 tureYE genisletilir (EXPLICIT_CONSENT, COOKIES, CONTENT_REMOVAL, RETENTION).
-- * Surum numarasi her tur icin COALESCE(MAX(version),0)+1 ile hesaplanir (yerel/test surumlerine dayanikli);
--   onceki aktif surumler (tum diller) pasife alinir, yeni tr+en ayni numarayla aktif eklenir.
-- * Yer tutucular ({{controller.name}} vb.) sunum aninda LegalService tarafindan app_setting'ten doldurulur.
-- * Kayitta zorunlu onay: TERMS, PRIVACY, KVKK, COMMUNITY_RULES (require_reaccept=true). Digerleri bilgilendirmedir.

ALTER TABLE legal_document DROP CONSTRAINT IF EXISTS legal_type_check;
ALTER TABLE legal_document ADD CONSTRAINT legal_type_check CHECK (type IN (${names}));

-- Yonetici ayarlari: yer tutucu kaynaklari (legal.* anahtarlari; support_email V5'te vardir)
INSERT INTO app_setting (setting_key, setting_value) VALUES
 ('legal.controller.name', 'Bingöl Üniversitesi'),
 ('legal.controller.address', ''),
 ('legal.controller.email', ''),
 ('legal.controller.kep', ''),
 ('legal.controller.verbis', ''),
 ('legal.hosting.location', '')
ON CONFLICT (setting_key) DO NOTHING;
`;

for (const [prefix, type, reaccept] of TYPES) {
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
sql = sql.replace('8 tureYE', '8 ture');

if (process.argv.includes('--check')) {
  const cur = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
  if (cur !== sql) {
    console.error('V290 eski: node scripts/build-legal-migration.js calistirin');
    process.exit(1);
  }
  console.log('V290 guncel');
} else {
  fs.writeFileSync(OUT, sql, { encoding: 'utf8' }); // BOM'suz
  console.log(`yazildi: ${OUT} (${sql.length} karakter)`);
}
