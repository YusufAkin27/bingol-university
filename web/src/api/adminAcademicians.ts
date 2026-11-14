// Akademisyen başvuruları ve akademisyen derslerinin salt okunur yönetici görünümü.
// Uçlar (backend: academician/AcademicianAdminController): GET /admin/academicians?status=&approvalMode=&cursor=&size=,
// GET /admin/academicians/{userId}, POST .../{userId}/approve | reject {reason} | revoke {reason},
// GET .../{userId}/courses, GET .../courses/{id}, .../courses/{id}/attendance, .../courses/{id}/notices?cursor&size,
// GET .../notices/{noticeId}/files/{fileId} (denetimli indirme). Okuma users.read, yazma users.write.
// E-posta, users.pii izni olmayan profillerde sunucuda MASKELİ gelir; istemci maskeyi açmaz.
import { api, apiBlob } from './client';
import { idempotencyHeaders } from '../components/admin/guard';
import type { CursorPage } from './types';

export type AcademicianStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'REVOKED';
export type ApprovalMode = 'AUTO' | 'ADMIN';

export interface AdminAcademician {
  userId: number;
  /** Sunucunun döndürdüğü gibi (maskeli olabilir). */
  email: string | null;
  displayName: string | null;
  title: string | null;
  firstName: string | null;
  lastName: string | null;
  unit: string | null;
  status: AcademicianStatus;
  approvalMode: ApprovalMode | null;
  rejectReason: string | null;
  reviewedBy: number | null;
  reviewedAt: string | null;
  createdAt: string;
}

export interface AcademicianListParams {
  /** Boş = hepsi. Birden çok durum virgülle gönderilir. */
  status?: AcademicianStatus[];
  approvalMode?: ApprovalMode;
  cursor?: number | null;
  size?: number;
}

export type AbsenceLimitType = 'COUNT' | 'PERCENT';

export interface CourseSlot {
  id: number;
  /** 1 = Pazartesi ... 7 = Pazar */
  dayOfWeek: number;
  startTime: string;
  endTime: string;
  room: string | null;
}

export interface CourseLimit {
  type: AbsenceLimitType;
  value: number | null;
}

export interface AcademicianCourse {
  id: number;
  code: string | null;
  name: string;
  term: string;
  faculty: string | null;
  department: string;
  grade: string | null;
  limit: CourseLimit | null;
  status: 'ACTIVE' | 'ARCHIVED' | string;
  slots: CourseSlot[];
  enrolledCount: number | null;
  sessionCount: number | null;
  createdAt: string;
}

export type AttendanceMark = 'PRESENT_QR' | 'PRESENT_MANUAL' | 'REVOKED' | 'ABSENT';

export interface AttendanceSession {
  id: number;
  lessonDate: string;
}

export interface AttendanceStudent {
  studentId: number;
  displayName: string | null;
  studentNo: string | null;
  /** Anahtar: oturum kimliği (metin). */
  marks: Record<string, AttendanceMark>;
  absentCount: number;
  atRisk: boolean;
  overLimit: boolean;
}

export interface AttendanceMatrix {
  sessions: AttendanceSession[];
  students: AttendanceStudent[];
  limit: CourseLimit | null;
}

export interface NoticeFile {
  id: number;
  name: string;
  contentType: string;
  sizeBytes: number;
}

export interface CourseNotice {
  id: number;
  type: string;
  title: string | null;
  note: string | null;
  eventAt: string | null;
  createdAt: string;
  files: NoticeFile[];
}

export const acadKeys = {
  all: ['admin', 'academicians'] as const,
  list: (status: string, approvalMode: string) => ['admin', 'academicians', 'list', status, approvalMode] as const,
  detail: (id: number) => ['admin', 'academicians', 'detail', id] as const,
  courses: (id: number) => ['admin', 'academicians', 'courses', id] as const,
  course: (id: number) => ['admin', 'academicians', 'course', id] as const,
  attendance: (id: number) => ['admin', 'academicians', 'attendance', id] as const,
  notices: (id: number) => ['admin', 'academicians', 'notices', id] as const,
};

export const listAcademicians = (p: AcademicianListParams = {}) =>
  api.get<CursorPage<AdminAcademician>>('/admin/academicians', {
    status: p.status && p.status.length ? p.status.join(',') : undefined,
    approvalMode: p.approvalMode,
    cursor: p.cursor,
    size: p.size,
  });

export const getAcademician = (userId: number) => api.get<AdminAcademician>(`/admin/academicians/${userId}`);

export const approveAcademician = (userId: number, idempotencyKey?: string) =>
  api.post<AdminAcademician>(
    `/admin/academicians/${userId}/approve`,
    undefined,
    idempotencyKey ? idempotencyHeaders(idempotencyKey) : undefined,
  );

export const rejectAcademician = (userId: number, reason: string, idempotencyKey?: string) =>
  api.post<AdminAcademician>(
    `/admin/academicians/${userId}/reject`,
    { reason },
    idempotencyKey ? idempotencyHeaders(idempotencyKey) : undefined,
  );

export const revokeAcademician = (userId: number, reason: string, idempotencyKey?: string) =>
  api.post<AdminAcademician>(
    `/admin/academicians/${userId}/revoke`,
    { reason },
    idempotencyKey ? idempotencyHeaders(idempotencyKey) : undefined,
  );

export const listAcademicianCourses = (userId: number) =>
  api.get<AcademicianCourse[]>(`/admin/academicians/${userId}/courses`);

export const getAcademicianCourse = (courseId: number) =>
  api.get<AcademicianCourse>(`/admin/academicians/courses/${courseId}`);

export const getCourseAttendance = (courseId: number) =>
  api.get<AttendanceMatrix>(`/admin/academicians/courses/${courseId}/attendance`);

export const listCourseNotices = (courseId: number, p: { cursor?: number | null; size?: number } = {}) =>
  api.get<CursorPage<CourseNotice>>(`/admin/academicians/courses/${courseId}/notices`, {
    cursor: p.cursor,
    size: p.size,
  });

/** Denetimli indirme: Authorization başlığı gerektiğinden `<a href>` yerine blob olarak alınır. */
export const downloadNoticeFile = (noticeId: number, fileId: number) =>
  apiBlob(`/admin/academicians/notices/${noticeId}/files/${fileId}`);
