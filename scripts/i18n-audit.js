#!/usr/bin/env node
// Mobil: sabit (yerellestirilmemis) kullanici dizelerini tarar. Kullanim: node scripts/i18n-audit.js [--files]
// Olcut: yorum disi satirlarda (a) Turkce ozel harf iceren dize degiskenleri, (b) Text('...')/label:/title:/hint:/
// tooltip:/subtitle:/content: ile verilen harf iceren sabit dizeler. lib/l10n ve uretilmis dosyalar haric.
// Cikis kodu her zaman 0 (rapor amaclidir); --max N verilirse sayi N'i asarsa 1.
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', 'mobile', 'lib');
const TR = /'[^'\n]*[çğıöşüÇĞİÖŞÜ][^'\n]*'/;
const UI = /(?:Text\(|label:|title:|subtitle:|hint:|hintText:|tooltip:|content:|labelText:|message:)\s*(?:const\s+)?'[^'$\n]*[A-Za-zÀ-ɏ]{3,}[^'\n]*'/;

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name === 'l10n') continue;
      walk(p, out);
    } else if (e.name.endsWith('.dart')) out.push(p);
  }
  return out;
}

const per = [];
let total = 0;
for (const f of walk(root)) {
  let n = 0;
  for (const raw of fs.readFileSync(f, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (line.startsWith('//') || line.startsWith('import ') || line.startsWith('///')) continue;
    if (line.includes('context.l10n') || line.includes('l10n.')) continue;
    if (TR.test(line) || UI.test(line)) n++;
  }
  if (n) per.push([path.relative(path.join(__dirname, '..'), f).replace(/\\/g, '/'), n]);
  total += n;
}
per.sort((a, b) => b[1] - a[1]);
if (process.argv.includes('--files')) for (const [f, n] of per) console.log(String(n).padStart(4), f);
console.log(`Yerellestirilmemis dize satiri: ${total} (${per.length} dosya)`);
const mi = process.argv.indexOf('--max');
if (mi > 0 && total > Number(process.argv[mi + 1])) process.exit(1);
