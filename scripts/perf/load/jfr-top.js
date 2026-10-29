#!/usr/bin/env node
// JFR ornek dokumunu ("jfr print --events jdk.ExecutionSample x.jfr > samples.txt") ozetler: en sicak yaprak ve kapsayici
// (inclusive) yontemler. CPU darbogazinin hangi kodda oldugunu bulmak icin. Kullanim: node jfr-top.js samples.txt [filtre-regex] [HH:MM:SS bas] [HH:MM:SS son]  (jfr print --stack-depth 40 ile uretin)
'use strict';
const fs = require('node:fs');
const file = process.argv[2];
const from = process.argv[4] || '00:00:00'; const to = process.argv[5] || '99:99:99'; // HH:MM:SS (yalniz yuk penceresi)
const filter = new RegExp(process.argv[3] || 'bingol|hibernate|jackson|tomcat|catalina|zip|logback|lettuce|springframework|jdk\\.internal|java\\.util\\.regex');
const t = fs.readFileSync(file, 'utf8');
const ev = t.split('jdk.ExecutionSample').slice(1);
const top = {}; const incl = {}; let n = 0;
for (const e of ev) {
  const tm = /startTime = (\d\d:\d\d:\d\d)/.exec(e);
  if (tm && (tm[1] < from || tm[1] > to)) continue;
  const fr = [...e.matchAll(/^\s+([\w.$<>]+)\(.*?\)\s+line:/gm)].map((m) => m[1]);
  if (!fr.length) continue;
  n++;
  top[fr[0]] = (top[fr[0]] || 0) + 1;
  const seen = new Set();
  for (const f of fr) if (!seen.has(f)) { seen.add(f); incl[f] = (incl[f] || 0) + 1; }
}
const fmt = (o, k) => Object.entries(o).sort((a, b) => b[1] - a[1]).slice(0, k).map(([name, v]) => `${(v / n * 100).toFixed(1).padStart(5)}% ${name}`).join('\n');
console.log(`ornek sayisi: ${n}`);
console.log('--- en sicak yaprak (self)');
console.log(fmt(top, 25));
console.log('--- kapsayici (filtreli)');
console.log(fmt(Object.fromEntries(Object.entries(incl).filter(([k]) => filter.test(k))), 45));
