// Sözlük tutarlılığı: kaynakta kullanılan her `ac.*` anahtarı tr.ts'te var; dinamik aileler eksiksiz; panel ortak admin sözlüğüne yazmaz.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import tr from './tr';

const DIR = join(process.cwd(), 'src', 'pages', 'academician');
const walk = (d: string): string[] => readdirSync(d).flatMap((n) => (statSync(join(d, n)).isDirectory() ? walk(join(d, n)) : [join(d, n)]));
const sources = walk(DIR).filter((f) => /\.tsx?$/.test(f) && !/\.test\.tsx?$/.test(f) && !/testUtils|tr\.ts$/.test(f));
const text = sources.map((f) => readFileSync(f, 'utf-8')).join('\n');

describe('akademisyen sözlüğü', () => {
  it("kaynaktaki her sabit 'ac.*' anahtarı tanımlı", () => {
    const used = new Set([...text.matchAll(/['"`](ac\.[A-Za-z0-9_.]+)['"`]/g)].map((m) => m[1]));
    const missing = [...used].filter((k) => !(k in tr) && !k.endsWith('.'));
    expect(missing).toEqual([]);
  });

  it('dinamik anahtar aileleri tam', () => {
    const fam: Record<string, string[]> = {
      'ac.day.': ['1', '2', '3', '4', '5', '6', '7', '1.short', '2.short', '3.short', '4.short', '5.short', '6.short', '7.short'],
      'ac.notice.type.': ['LESSON_STARTED', 'ATTENDANCE_STARTED', 'EXAM', 'ASSIGNMENT', 'MATERIAL', 'LESSON_CANCELLED', 'ROOM_CHANGED'],
      'ac.notices.typeHint.': ['LESSON_STARTED', 'ATTENDANCE_STARTED', 'EXAM', 'ASSIGNMENT', 'MATERIAL', 'LESSON_CANCELLED', 'ROOM_CHANGED'],
      'ac.notices.event.': ['EXAM', 'ASSIGNMENT', 'LESSON_CANCELLED', 'ROOM_CHANGED'],
      'ac.status.': ['NONE', 'PENDING', 'APPROVED', 'REJECTED', 'REVOKED'],
      'ac.approval.': ['AUTO', 'ADMIN'],
      'ac.mark.': ['PRESENT_QR', 'PRESENT_MANUAL', 'REVOKED', 'ABSENT'],
      'ac.pending.': ['PENDING.title', 'PENDING.text', 'REJECTED.title', 'REJECTED.text', 'REVOKED.title', 'REVOKED.text'],
    };
    const missing = Object.entries(fam).flatMap(([p, ks]) => ks.map((k) => p + k)).filter((k) => !(k in tr));
    expect(missing).toEqual([]);
  });

  it('arka uç hata kodlarının Türkçe karşılığı var', () => {
    for (const c of ['ACADEMICIAN_NOT_APPROVED', 'NOTICE_TOO_FREQUENT', 'NOTICE_FILE_TYPE_NOT_ALLOWED', 'NOTICE_FILE_TOO_LARGE', 'NOTICE_FILE_LIMIT', 'NOTICE_STORAGE_CAP', 'AC_BULK_TOO_LARGE', 'AC_COURSE_ARCHIVED']) {
      expect(tr).toHaveProperty(`ac.err.${c}`);
    }
  });

  it('değerler boş değil', () => {
    expect(Object.entries(tr).filter(([, v]) => !v.trim())).toEqual([]);
  });
});
