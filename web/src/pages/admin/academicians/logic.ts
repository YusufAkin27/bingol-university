// Akademisyen yönetimi: saf yardımcılar (sekme -> sunucu süzgeci, yerel süzme, sınır durumu, dosya boyutu).
import type {
  AcademicianListParams,
  AcademicianStatus,
  AdminAcademician,
  AttendanceMark,
  AttendanceStudent,
  CourseLimit,
} from '../../../api/adminAcademicians';

export type AcadTab = 'pending' | 'approved' | 'auto' | 'rejected';
export const ACAD_TABS: AcadTab[] = ['pending', 'approved', 'auto', 'rejected'];
export const ACAD_MARKS: AttendanceMark[] = ['PRESENT_QR', 'PRESENT_MANUAL', 'REVOKED', 'ABSENT'];

/** Sekmenin sunucuya gönderdiği süzgeç. Otomatik sekme: kuralla onaylanmış ve hâlen onaylı olanlar. */
export function paramsForTab(tab: AcadTab): Pick<AcademicianListParams, 'status' | 'approvalMode'> {
  switch (tab) {
    case 'pending':
      return { status: ['PENDING'] };
    case 'approved':
      return { status: ['APPROVED'] };
    case 'auto':
      return { status: ['APPROVED'], approvalMode: 'AUTO' };
    case 'rejected':
      return { status: ['REJECTED', 'REVOKED'] };
  }
}

export const canApprove = (s: AcademicianStatus): boolean => s === 'PENDING' || s === 'REJECTED' || s === 'REVOKED';
export const canReject = (s: AcademicianStatus): boolean => s === 'PENDING';
export const canRevoke = (s: AcademicianStatus): boolean => s === 'APPROVED';

/** Görünen ad: sunucu displayName yoksa ad + soyad. */
export function nameOf(a: Pick<AdminAcademician, 'displayName' | 'firstName' | 'lastName'>): string {
  const full = [a.firstName, a.lastName].filter(Boolean).join(' ').trim();
  return (a.displayName?.trim() || full).trim();
}

/** Yerel süzme (yalnız yüklenmiş kayıtlar): ad, e-posta (sunucunun verdiği hâliyle) ve birim. */
export function matchesFilter(a: AdminAcademician, q: string): boolean {
  const needle = q.trim().toLocaleLowerCase('tr');
  if (!needle) return true;
  return [nameOf(a), a.title, a.email, a.unit].some((v) => (v ?? '').toLocaleLowerCase('tr').includes(needle));
}

export type LimitStatus = 'none' | 'ok' | 'atRisk' | 'over';

export function limitStatus(limit: CourseLimit | null, s: Pick<AttendanceStudent, 'atRisk' | 'overLimit'>): LimitStatus {
  if (!limit) return 'none';
  if (s.overLimit) return 'over';
  if (s.atRisk) return 'atRisk';
  return 'ok';
}

export const isPresent = (m: AttendanceMark | undefined): boolean => m === 'PRESENT_QR' || m === 'PRESENT_MANUAL';

/** Oturum özeti: matristen türetilir (yönetici uçları ayrı bir oturum listesi sunmaz). */
export function sessionSummary(sessionId: number, students: AttendanceStudent[]) {
  let present = 0;
  let revoked = 0;
  let absent = 0;
  for (const s of students) {
    const m = s.marks[String(sessionId)] ?? 'ABSENT';
    if (isPresent(m)) present++;
    else if (m === 'REVOKED') revoked++;
    else absent++;
  }
  return { present, revoked, absent, total: students.length };
}

export function formatBytes(n: number): { key: 'admin.acad.size.b' | 'admin.acad.size.kb' | 'admin.acad.size.mb'; n: string } {
  if (n >= 1024 * 1024) return { key: 'admin.acad.size.mb', n: (n / (1024 * 1024)).toFixed(1) };
  if (n >= 1024) return { key: 'admin.acad.size.kb', n: String(Math.round(n / 1024)) };
  return { key: 'admin.acad.size.b', n: String(n) };
}

/** "HH:mm:ss" gelirse saniyeyi atar. */
export const hhmm = (t: string): string => (t ?? '').slice(0, 5);
