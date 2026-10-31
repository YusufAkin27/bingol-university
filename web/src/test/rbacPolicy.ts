/**
 * Backend `AdminPermissionPolicy` + `PermissionMatrix` kaynağını okuyup (yol, yöntem) -> gereken izin ve profil -> izin
 * kümesi çözer. Menü izni uyum testi (layouts/navPolicy.test.ts) ve rol gezinti taraması (e2e/w2k-rbac.spec.ts) paylaşır;
 * böylece web tarafında ikinci bir izin tablosu elle tutulmaz. Backend kaynağı yoksa (`haveBackend` false) çağıranlar atlar.
 * Yalnız test/e2e içindir; uygulama paketine girmez.
 */
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const RBAC_DIR = join(process.cwd(), '..', 'backend', 'src', 'main', 'java', 'edu', 'bingol', 'backend', 'admin', 'rbac');
export const POLICY_FILE = join(RBAC_DIR, 'AdminPermissionPolicy.java');
export const MATRIX_FILE = join(RBAC_DIR, 'PermissionMatrix.java');
export const haveBackend = existsSync(POLICY_FILE) && existsSync(MATRIX_FILE);

export interface PolicyRule {
  re: RegExp;
  methods: string[] | null;
  read: string;
  write: string;
}

/** PermissionMatrix.java: SABIT_AD -> "izin.anahtari". */
export function parseConstants(src: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const m of src.matchAll(/public static final String (\w+) = "([^"]+)";/g)) out[m[1]] = m[2];
  return out;
}

/** PermissionMatrix.java: profil -> izin kümesi (`grant(IZIN, F, M...)` satırlarından). */
export function parseProfilePerms(src: string, consts: Record<string, string>): Record<string, string[]> {
  const letter: Record<string, string> = { F: 'FULL', M: 'MODERATOR', S: 'SUPPORT', E: 'EDITOR', V: 'VIEWER' };
  const out: Record<string, string[]> = { FULL: [], MODERATOR: [], SUPPORT: [], EDITOR: [], VIEWER: [] };
  for (const m of src.matchAll(/grant\((\w+),\s*([^)]*)\);/g)) {
    for (const p of m[2].split(',')) out[letter[p.trim()]]?.push(consts[m[1]]);
  }
  return out;
}

/** AdminPermissionPolicy.java kurallarını sırasıyla okur (one/area). Java düzenli ifadesi JS ile uyumludur. */
export function parseRules(src: string, consts: Record<string, string>): PolicyRule[] {
  const rules: PolicyRule[] = [];
  const body = src.slice(src.indexOf('static {'));
  // birleştirilmiş dize: "a" + ID + "b" (satır sonu ve + ile bölünmüş olabilir)
  // yalnız tırnaklı değişmezler ve ID sabiti alınır (dize İÇİNDEKİ "+" karakteri korunur: ör. [^/]+)
  const strExpr = (raw: string) =>
    [...raw.matchAll(/"((?:[^"\\]|\\.)*)"|\bID\b/g)].map((m) => (m[1] !== undefined ? m[1] : '[^/]+')).join('');
  for (const m of body.matchAll(/\b(one|area)\(([\s\S]*?)\);/g)) {
    const kind = m[1];
    let rest = m[2];
    let methods: string[] | null = null;
    if (kind === 'one') {
      const mm = /^\s*(null|Set\.of\(([^)]*)\))\s*,/.exec(rest);
      if (!mm) continue;
      methods = mm[2] ? mm[2].split(',').map((x) => x.trim().replace(/"/g, '')) : null;
      rest = rest.slice(mm[0].length);
    }
    const tail = /,\s*([A-Z_]+)(?:\s*,\s*([A-Z_]+))?\s*$/.exec(rest);
    if (!tail) continue;
    const regex = strExpr(rest.slice(0, tail.index).trim());
    const read = consts[tail[1]];
    const write = kind === 'area' ? consts[tail[2]] : read;
    rules.push({ re: new RegExp(`^${regex}$`), methods, read, write });
  }
  return rules;
}

/** Gereken izin (eşlenmemiş yol: admin.full). `path` `/api/admin/...` biçiminde, sorgu dizesiz. */
export function requiredPerm(rules: PolicyRule[], method: string, path: string): string {
  const m = method.toUpperCase() === 'HEAD' ? 'GET' : method.toUpperCase();
  const p = path.split('?')[0].replace(/\/+$/, '') || '/';
  for (const r of rules) {
    if ((r.methods === null || r.methods.includes(m)) && r.re.test(p)) return m === 'GET' ? r.read : r.write;
  }
  return 'admin.full';
}

export function loadPolicy() {
  const matrixSrc = readFileSync(MATRIX_FILE, 'utf-8');
  const consts = parseConstants(matrixSrc);
  return {
    consts,
    rules: parseRules(readFileSync(POLICY_FILE, 'utf-8'), consts),
    profilePerms: parseProfilePerms(matrixSrc, consts),
  };
}
