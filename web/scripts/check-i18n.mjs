// tr/en/ar sözlük anahtar eşitliği denetimi: node scripts/check-i18n.mjs
// Her ad alanı dosyasında anahtar kümeleri, boş değerler ve {yer tutucu} uyumu karşılaştırılır.
import { readdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'i18n');
const langs = ['tr', 'en', 'ar'];

/** 'anahtar': 'değer' çiftlerini (tek/çift/ters tırnak, çok satırlı) çıkarır. */
export function parseEntries(src) {
  const out = new Map();
  const re = /^\s*'([\w.\-]+)'\s*:\s*((?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|`(?:\\.|[^`\\])*`)(?:\s*\+\s*(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"))*)\s*,?\s*$/gm;
  let m;
  while ((m = re.exec(src))) out.set(m[1], m[2]);
  return out;
}

const ph = (s) => (s.match(/\{\w+\}/g) ?? []).sort().join(',');
// Yönetim paneli yalnız Türkçedir: bu ad alanları en/ar eşitliğinden muaftır (index.ts en/ar'a tr metnini katar).
const TR_ONLY = new Set(['admin-guard.ts', 'admin-shell.ts', 'admin-p05.ts', 'admin-p03.ts', 'admin-wp02.ts', 'admin-p06.ts', 'admin-p07.ts', 'admin-p08.ts', 'admin-p09.ts', 'admin-p11.ts', 'admin-p13.ts', 'admin-p14.ts', 'admin-p15.ts', 'admin-p16.ts', 'admin-cr1.ts', 'admin-ds1.ts', 'admin-reg.ts', 'admin-uv1.ts', 'admin-kit.ts', 'admin-v2-community.ts', 'admin-v2-people.ts', 'admin-v2-moderation.ts', 'admin-v2-notifsys.ts', 'admin-bh.ts', 'admin-campus.ts', 'admin-gd1.ts', 'admin-unitnews.ts', 'admin-twofactor.ts']);
TR_ONLY.add('admin-arama.ts'); // PANEL-arama: kısayollar, yardım, sayfa hatası (yalnız Türkçe)
TR_ONLY.add('admin-genel.ts'); // PANEL-genel-bakis
TR_ONLY.add('admin-mod1.ts'); // PANEL-yaptirim
TR_ONLY.add('admin-mod2.ts'); // PANEL-icerik-denetimi
TR_ONLY.add('admin-icerik.ts'); // PANEL-akademik-icerik
TR_ONLY.add('admin-insan.ts'); // PANEL-insanlar
TR_ONLY.add('admin-topluluk.ts'); // PANEL-topluluk
TR_ONLY.add('admin-sys2.ts'); // PANEL-sistem-saglik
const problems = [];

for (const f of readdirSync(join(root, 'tr')).filter((x) => x.endsWith('.ts') && !TR_ONLY.has(x))) {
  const maps = {};
  for (const l of langs) {
    try {
      maps[l] = parseEntries(readFileSync(join(root, l, f), 'utf8'));
    } catch {
      problems.push(`${l}/${f}: dosya yok`);
      maps[l] = new Map();
    }
  }
  for (const l of ['en', 'ar']) {
    for (const k of maps.tr.keys()) {
      if (!maps[l].has(k)) problems.push(`${l}/${f}: eksik anahtar ${k}`);
      else if (ph(maps[l].get(k)) !== ph(maps.tr.get(k))) problems.push(`${l}/${f}: yer tutucu uyumsuz ${k}`);
      else if (/^(''|""|``)$/.test(maps[l].get(k).trim())) problems.push(`${l}/${f}: bos deger ${k}`);
    }
    for (const k of maps[l].keys()) if (!maps.tr.has(k)) problems.push(`${l}/${f}: fazla anahtar ${k}`);
  }
}

if (problems.length) {
  console.error(problems.join('\n'));
  console.error(`\ni18n denetimi BASARISIZ: ${problems.length} sorun`);
  process.exit(1);
}
console.log('i18n denetimi tamam: tr/en/ar anahtarlari esit');
