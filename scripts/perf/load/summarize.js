#!/usr/bin/env node
// Sonuc klasorundeki senaryo JSON'larini tek bir SUMMARY.md + results.json'a toplar.
// Kullanim: node summarize.js <sonuc-klasoru>
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const dir = process.argv[2];
if (!dir) { console.error('kullanim: node summarize.js <sonuc-klasoru>'); process.exit(2); }
const rd = (f) => { try { return JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')); } catch { return null; } };
const txt = (f) => { try { return fs.readFileSync(path.join(dir, f), 'utf8'); } catch { return null; } };
const files = fs.readdirSync(dir).sort();
const n0 = (v) => (v === null || v === undefined ? '-' : Math.round(v));
const out = ['# Yuk testi ozeti', '', `Uretim: ${new Date().toISOString()} (klasor: ${path.basename(dir)})`, ''];
const all = {};

const scen = files.filter((f) => /^(A-|B-|C1-|C2-|E-|G-|H-)[^.]*\.json$/.test(f) && !f.includes('.res.'));
for (const f of scen) {
  const j = rd(f);
  if (!j || !j.endpoints) continue;
  all[j.scenario || f] = j;
  const res = rd(f.replace(/\.json$/, '.res.json'));
  out.push(`## ${j.scenario} (${f})`, '');
  out.push(`istek(olcum)=${j.totalRequestsMain}, hata orani=${j.failRateMain === null ? '-' : (j.failRateMain * 100).toFixed(2) + '%'}, 429=${j.c429}, beklenmeyen hata=${j.errors}, 503=${j.c503}, sure=${n0(j.runSeconds)} sn`);
  if (j.overall) out.push(`genel: p50=${n0(j.overall.p50)} p95=${n0(j.overall.p95)} p99=${n0(j.overall.p99)} ms`);
  out.push('', '| uc | n | p50 | p95 | p99 | max | hata | 429 |' + (j.endpoints && Object.values(j.endpoints)[0] && Object.values(j.endpoints)[0].rps !== undefined ? ' RPS |' : ''), '|---|---:|---:|---:|---:|---:|---:|---:|' + (Object.values(j.endpoints)[0] && Object.values(j.endpoints)[0].rps !== undefined ? '---:|' : ''));
  for (const [name, r] of Object.entries(j.endpoints).sort()) {
    out.push(`| ${name} | ${r.n} | ${n0(r.p50)} | ${n0(r.p95)} | ${n0(r.p99)} | ${n0(r.max)} | ${r.errors} | ${r.c429} |` + (r.rps !== undefined ? ` ${r.rps} |` : ''));
  }
  if (j.extra && j.extra.csv) out.push('', `CSV disa aktarma: p50=${n0(j.extra.csv.ms_p50)} ms, p95=${n0(j.extra.csv.ms_p95)} ms, max=${n0(j.extra.csv.ms_max)} ms, ort. ${n0(j.extra.csv.bytes_avg)} bayt, ~${n0(j.extra.csv.rows_avg)} satir, hata=${j.extra.csv.fail}`);
  if (j.extra && !j.extra.csv && Object.keys(j.extra).length) out.push('', 'ek: `' + JSON.stringify(j.extra) + '`');
  const rs = rd(f.replace(/\.json$/, '.res.summary.json'));
  if (rs) out.push('', 'Kaynaklar: ' + resLine(rs));
  out.push('');
}
function resLine(r) {
  const c = r.containers || {};
  const cn = Object.entries(c).map(([k, v]) => `${k} cpu ort ${n0(v.cpuAvgPct)}% maks ${n0(v.cpuMaxPct)}% bellek ${n0(v.memMaxMb)} MB`).join('; ');
  return `JVM CPU ort ${n0(r.appCpuAvgPct)}% maks ${n0(r.appCpuMaxPct)}%, heap maks ${n0(r.heapMaxMb)} MB, GC duraklama ${r.gcPauses} (${(r.gcPauseSec || 0).toFixed(2)} sn), is parcacigi maks ${r.threadsMax}, Hikari aktif maks ${r.hikActiveMax}/${r.hikMax}, bekleyen maks ${r.hikPendingMax}, Hikari zaman asimi ${r.hikTimeoutsEnd}; ${cn}`;
}

for (const f of ['D-ws.json']) {
  const j = rd(f);
  if (!j) continue;
  all[j.scenario] = j;
  out.push(`## ${j.scenario}`, '', '```json', JSON.stringify(j, null, 1), '```', '');
}
for (const f of ['integrity.txt', 'F-chaos.log']) {
  const t = txt(f);
  if (t) out.push(`## ${f}`, '', '```', t.trim(), '```', '');
}
const ress = files.filter((f) => f.endsWith('.res.summary.json'));
if (ress.length) {
  out.push('## Kaynak ozetleri (tum kosular)', '', '| kosu | JVM CPU ort/maks % | heap maks MB | Hikari aktif/bekleyen maks | pg CPU ort % (2 CPU=200) | app CPU ort % (200) |', '|---|---:|---:|---:|---:|---:|');
  for (const f of ress) {
    const r = rd(f);
    if (!r) continue;
    const c = r.containers || {};
    const pg = Object.entries(c).find(([k]) => /pg/.test(k));
    const ap = Object.entries(c).find(([k]) => /app/.test(k));
    out.push(`| ${f.replace('.res.summary.json', '')} | ${n0(r.appCpuAvgPct)}/${n0(r.appCpuMaxPct)} | ${n0(r.heapMaxMb)} | ${r.hikActiveMax}/${r.hikPendingMax} | ${pg ? n0(pg[1].cpuAvgPct) : '-'} | ${ap ? n0(ap[1].cpuAvgPct) : '-'} |`);
  }
  out.push('');
}
fs.writeFileSync(path.join(dir, 'SUMMARY.md'), out.join('\n'));
fs.writeFileSync(path.join(dir, 'results.json'), JSON.stringify(all, null, 1));
console.log(path.join(dir, 'SUMMARY.md'));
