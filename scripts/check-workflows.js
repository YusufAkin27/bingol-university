#!/usr/bin/env node
// GitHub Actions iş akışlarının ve izleme YAML dosyalarının sözdizimi/yapı denetimi (actionlint yoksa).
// Kullanım (repo kökünden): node scripts/check-workflows.js
// js-yaml bulunamazsa: npm install --no-save --no-package-lock --prefix .ci-tools js-yaml@4.1.0
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..');

function loadYaml() {
  const candidates = ['js-yaml', path.join(ROOT, '.ci-tools/node_modules/js-yaml'), path.join(ROOT, 'web/node_modules/js-yaml')];
  for (const c of candidates) {
    try { return require(c); } catch { /* sonraki aday */ }
  }
  console.error('js-yaml bulunamadi. Kurulum: npm install --no-save --no-package-lock --prefix .ci-tools js-yaml@4.1.0');
  process.exit(2);
}
const yaml = loadYaml();

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (/\.ya?ml$/.test(e.name)) out.push(p);
  }
  return out;
}

const errors = [];
const warns = [];
const rel = (p) => path.relative(ROOT, p).replace(/\\/g, '/');

// 1) Tüm YAML dosyaları ayrıştırılabilmeli
const yamlFiles = [
  ...walk(path.join(ROOT, '.github')),
  ...walk(path.join(ROOT, 'monitoring')),
  ...walk(path.join(ROOT, '.zap')),
];
const gitleaks = path.join(ROOT, '.gitleaks.toml');
const parsed = new Map();
for (const f of yamlFiles) {
  try {
    parsed.set(f, yaml.load(fs.readFileSync(f, 'utf8')));
  } catch (e) {
    errors.push(`${rel(f)}: YAML hatası: ${String(e.message).split('\n')[0]}`);
  }
}

// 2) İş akışı yapısı
const SECRET_LITERAL = /(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{30,}|xox[bp]-[A-Za-z0-9-]{20,})/;
for (const [f, doc] of parsed) {
  if (!rel(f).startsWith('.github/workflows/')) continue;
  const name = rel(f);
  if (!doc || typeof doc !== 'object') { errors.push(`${name}: boş ya da geçersiz`); continue; }
  const on = doc.on !== undefined ? doc.on : doc[true];
  if (on === undefined) errors.push(`${name}: 'on' tetikleyicisi yok`);
  if (!doc.name) warns.push(`${name}: 'name' yok`);
  if (!doc.permissions) warns.push(`${name}: üst düzey 'permissions' yok (en az yetki önerilir)`);
  const jobs = doc.jobs;
  if (!jobs || typeof jobs !== 'object' || Object.keys(jobs).length === 0) { errors.push(`${name}: 'jobs' yok`); continue; }
  for (const [jid, job] of Object.entries(jobs)) {
    if (!job['runs-on'] && !job.uses) errors.push(`${name}: iş '${jid}' runs-on/uses içermiyor`);
    const needs = [].concat(job.needs || []);
    for (const n of needs) if (!jobs[n]) errors.push(`${name}: iş '${jid}' bilinmeyen işe 'needs' diyor: ${n}`);
    if (job.steps !== undefined) {
      if (!Array.isArray(job.steps) || job.steps.length === 0) errors.push(`${name}: iş '${jid}' adımları geçersiz`);
      (job.steps || []).forEach((s, i) => {
        if (!s.uses && !s.run) errors.push(`${name}: iş '${jid}' adım ${i + 1} 'uses' ya da 'run' içermiyor`);
        if (s.uses && !/^\.\/|^docker:\/\//.test(s.uses) && !/@[^@\s]+$/.test(s.uses)) errors.push(`${name}: '${s.uses}' sürümü sabitlenmemiş`);
        if (s.uses && /@(main|master|latest)$/.test(s.uses)) errors.push(`${name}: '${s.uses}' hareketli referans`);
      });
    }
  }
  const raw = fs.readFileSync(f, 'utf8');
  if (SECRET_LITERAL.test(raw)) errors.push(`${name}: sır benzeri sabit değer var`);
  // ${{ ... }} ifadeleri dengeli olmalı
  const open = (raw.match(/\$\{\{/g) || []).length;
  const close = (raw.match(/\}\}/g) || []).length;
  if (open > close) errors.push(`${name}: kapanmamış \${{ ifadesi`);
}

// 3) Dependabot ekosistemleri
const dep = parsed.get(path.join(ROOT, '.github/dependabot.yml'));
if (dep) {
  if (dep.version !== 2) errors.push('dependabot.yml: version 2 olmalı');
  for (const u of dep.updates || []) {
    if (!u['package-ecosystem'] || !u.directory || !u.schedule) errors.push(`dependabot.yml: eksik alan: ${JSON.stringify(u).slice(0, 80)}`);
  }
}

if (!fs.existsSync(gitleaks)) warns.push('.gitleaks.toml yok');

for (const w of warns) console.warn('UYARI  ' + w);
for (const e of errors) console.error('HATA   ' + e);
console.log(`${yamlFiles.length} YAML dosyası denetlendi: ${errors.length} hata, ${warns.length} uyarı`);
process.exit(errors.length ? 1 : 0);
