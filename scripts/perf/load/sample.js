#!/usr/bin/env node
// Kaynak ornekleyici: yuk sirasinda her 5 sn'de uygulama (actuator: CPU, heap, GC, Hikari, is parcacigi) ve konteyner
// (docker stats: CPU %, bellek) olcer; bitince ozet JSON yazar. SIGTERM/SIGINT ile durur.
// Ortam: BASE (http://localhost:18480), TOKEN (ADMIN JWT; fixtures.json adminToken), OUT (cikti oneki), EVERY_S (5),
//        CONTAINERS ("bu_ld_app,bu_ld_pg,bu_ld_redis"; docker yoksa bos birakin)
'use strict';
const fs = require('node:fs');
const { execFile } = require('node:child_process');
const BASE = (process.env.BASE || 'http://localhost:18480').replace(/\/+$/, '');
const TOKEN = process.env.TOKEN || '';
const OUT = process.env.OUT || 'sample';
const EVERY = Number(process.env.EVERY_S || 5) * 1000;
const CONT = (process.env.CONTAINERS === undefined ? 'bu_ld_app,bu_ld_pg,bu_ld_redis' : process.env.CONTAINERS).split(',').filter(Boolean);
const rows = [];

async function mv(name, tag) {
  try {
    const r = await fetch(`${BASE}/actuator/metrics/${name}${tag ? '?tag=' + tag : ''}`, { headers: { Authorization: 'Bearer ' + TOKEN }, signal: AbortSignal.timeout(4000) });
    if (!r.ok) return null;
    const j = await r.json();
    const m = j.measurements.find((x) => x.statistic === 'VALUE' || x.statistic === 'COUNT') || j.measurements[0];
    const tot = j.measurements.find((x) => x.statistic === 'TOTAL_TIME');
    return { v: m.value, t: tot ? tot.value : null };
  } catch { return null; }
}

function dstats() {
  return new Promise((res) => {
    if (!CONT.length) return res({});
    execFile('docker', ['stats', '--no-stream', '--format', '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}', ...CONT], (e, out) => {
      const o = {};
      for (const l of String(out || '').split('\n').filter(Boolean)) {
        const [n, cpu, mem] = l.split('|');
        const s = mem.split('/')[0].trim();
        const v = parseFloat(s);
        o[n] = { cpu: parseFloat(cpu), memMb: /GiB/.test(s) ? v * 1024 : /KiB/.test(s) ? v / 1024 : v };
      }
      res(o);
    });
  });
}

async function tick() {
  if (fs.existsSync(OUT + '.stop')) { fs.unlinkSync(OUT + '.stop'); done(); return; }
  const t0 = Date.now();
  const [cpu, heap, act, pend, mx, thr, gc, tmo, ds] = await Promise.all([
    mv('process.cpu.usage'), mv('jvm.memory.used', 'area:heap'), mv('hikaricp.connections.active'), mv('hikaricp.connections.pending'),
    mv('hikaricp.connections.max'), mv('jvm.threads.live'), mv('jvm.gc.pause'), mv('hikaricp.connections.timeout'), dstats(),
  ]);
  rows.push({ t: Math.round(t0 / 1000), cpu: cpu && cpu.v, heapMb: heap && heap.v / 1048576, hikActive: act && act.v, hikPending: pend && pend.v, hikMax: mx && mx.v,
    threads: thr && thr.v, gcCount: gc && gc.v, gcSec: gc && gc.t, hikTimeouts: tmo && tmo.v, docker: ds });
}

const timer = setInterval(tick, EVERY);
function done() {
  clearInterval(timer);
  const col = (f) => rows.map(f).filter((x) => typeof x === 'number' && !Number.isNaN(x));
  const mx = (a) => (a.length ? Math.max(...a) : null);
  const av = (a) => (a.length ? a.reduce((s, x) => s + x, 0) / a.length : null);
  const dk = (n, k) => col((r) => r.docker && r.docker[n] && r.docker[n][k]);
  const gcs = col((r) => r.gcCount);
  const gct = col((r) => r.gcSec);
  const sum = {
    samples: rows.length,
    appCpuAvgPct: av(col((r) => r.cpu * 100)), appCpuMaxPct: mx(col((r) => r.cpu * 100)),
    heapMaxMb: mx(col((r) => r.heapMb)), threadsMax: mx(col((r) => r.threads)),
    hikActiveMax: mx(col((r) => r.hikActive)), hikPendingMax: mx(col((r) => r.hikPending)), hikMax: mx(col((r) => r.hikMax)),
    hikTimeoutsEnd: rows.length ? rows[rows.length - 1].hikTimeouts : null,
    gcPauses: gcs.length ? gcs[gcs.length - 1] - gcs[0] : null, gcPauseSec: gct.length ? gct[gct.length - 1] - gct[0] : null,
    containers: Object.fromEntries(CONT.map((n) => [n, { cpuAvgPct: av(dk(n, 'cpu')), cpuMaxPct: mx(dk(n, 'cpu')), memMaxMb: mx(dk(n, 'memMb')) }])),
  };
  fs.writeFileSync(OUT + '.json', JSON.stringify({ summary: sum, rows }, null, 1));
  console.log(JSON.stringify(sum));
  process.exit(0);
}
process.on('SIGTERM', done);
process.on('SIGINT', done);
tick();
