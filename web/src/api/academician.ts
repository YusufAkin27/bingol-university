// Akademisyen paneli API'si (/api/academician/**). Sözleşme: backend `academician/AcademicianController` + `AcademicianDtos`.
// Tüm çağrılar `area: 'acad'` ile gider: Bearer ve refresh `bu.acad.*` token'larıyla, oturum sonu `/akademisyen/giris`e.
import { ApiError, apiBlob, apiFetch, buildUrl, refreshAccessToken, type Query } from './client';
import { getCurrentLang } from '../i18n/lang';
import { getDeviceId } from '../lib/deviceId';
import { tokensFor } from '../auth/tokens';

// ---------- türler ----------
export type AcademicianStatus = 'NONE' | 'PENDING' | 'APPROVED' | 'REJECTED' | 'REVOKED';

export interface AcademicianMe {
  status: AcademicianStatus;
  approvalMode: 'AUTO' | 'ADMIN' | null;
  title: string | null;
  firstName: string | null;
  lastName: string | null;
  unit: string | null;
  rejectReason: string | null;
  limits?: AcademicianLimits | null;
}

/** Sunucunun dosya sınırları (`GET /me`); yoksa varsayılan 20 MB / 5 dosya. */
export interface AcademicianLimits {
  noticeFileMaxBytes: number;
  noticeFilesPerNotice: number;
}

export interface ApplyBody {
  title: string;
  firstName: string;
  lastName: string;
  unit?: string;
}

export type LimitType = 'COUNT' | 'PERCENT';
export interface Limit {
  type: LimitType | null;
  value: number | null;
  /** İzin verilen en çok devamsızlık (COUNT: değer; PERCENT: planlanan ders sayısına uygulanır); yoksa null. */
  allowedAbsences?: number | null;
}

export interface Slot {
  id?: number;
  dayOfWeek: number; // 1 = Pazartesi
  startTime: string; // HH:mm
  endTime: string;
  room: string | null;
}

export interface Course {
  id: number;
  code: string | null;
  name: string;
  term: string;
  faculty: string | null;
  department: string;
  grade: string | null;
  /** Dönemdeki toplam planlanan ders sayısı (yüzde sınırı bunun üstünden); yoksa null. */
  plannedSessions?: number | null;
  limit: Limit;
  absenceLimitType: LimitType | null;
  absenceLimitValue: number | null;
  status: 'ACTIVE' | 'ARCHIVED';
  slots: Slot[];
  /** Liste ucunda null (yalnız ayrıntıda dolu). */
  enrolledCount: number | null;
  sessionCount: number | null;
  createdAt: string;
}

export interface CourseBody {
  code?: string;
  name: string;
  term: string;
  faculty?: string;
  department: string;
  grade?: string;
  plannedSessions?: number | null;
}

/** `absenceLimitType: 'NONE'` sınırı kaldırır. */
export interface CoursePatch extends Partial<CourseBody> {
  absenceLimitType?: LimitType | 'NONE';
  absenceLimitValue?: number;
  status?: 'ACTIVE' | 'ARCHIVED';
}

export interface DirectoryStudent {
  id: number;
  displayName: string;
  studentNo: string | null;
  faculty: string | null;
  department: string | null;
  grade: string | null;
}

export interface Enrollment {
  studentId: number;
  displayName: string;
  studentNo: string | null;
  faculty: string | null;
  department: string | null;
  grade: string | null;
  addedAt: string;
}

export interface CursorPage<T> {
  items: T[];
  nextCursor: number | null;
}

export interface PendingScan {
  studentId: number;
  displayName: string;
  studentNo: string | null;
  faculty: string | null;
  department: string | null;
  grade: string | null;
  scannedAt: string;
}

export interface AcSession {
  id: number;
  courseId: number;
  slotId: number | null;
  lessonDate: string; // yyyy-MM-dd
  /** false: bu yoklama devamsızlık hesabına katılmıyor. */
  counted?: boolean;
  openedAt: string;
  expiresAt: string;
  closedAt: string | null;
  status: 'OPEN' | 'CLOSED';
  presentCount: number;
  enrolledCount: number;
  /** Liste ucunda yok; tek oturum yanıtlarında dolu. */
  pendingScans?: PendingScan[] | null;
  /** Liste ucunda: karar bekleyen "kayıtlı değil" istek sayısı. */
  pendingCount?: number;
  /** Açma yanıtında: aynı ders için var olan oturum yeniden açıldı. */
  reused?: boolean;
  /** Açma yanıtında: `notify` işaretliydi ve bildirim gerçekten gitti mi. */
  notified?: boolean;
}

export interface LiveCode {
  code: string;
  fromMs: number;
  untilMs: number;
}

export interface AttendanceRecord {
  id: number;
  studentId: number;
  displayName: string | null;
  studentNo: string | null;
  method: 'QR' | 'MANUAL';
  markedAt: string;
  revoked: boolean;
  /** İzinli: yoklamada "var" sayılmaz, devamsızlığa da yazılmaz. */
  excused?: boolean;
}

export interface LiveView {
  status: 'OPEN' | 'CLOSED';
  serverNowMs: number;
  stepSeconds: number;
  codes: LiveCode[];
  presentCount: number;
  enrolledCount: number;
  /** Backend oturumun TÜM satırlarını verir (kaldırılanlar `revoked`); istemci id ile birleştirir. */
  newRecords: AttendanceRecord[];
  pendingScans: PendingScan[];
}

/** NOT_ENROLLED_YET: oturum yapıldığında öğrenci henüz derse kayıtlı değildi (devamsızlık sayılmaz). */
export type Mark = 'PRESENT_QR' | 'PRESENT_MANUAL' | 'EXCUSED' | 'REVOKED' | 'ABSENT' | 'NOT_ENROLLED_YET';

export interface MatrixStudent {
  studentId: number;
  displayName: string;
  studentNo: string | null;
  marks: Record<string, Mark>;
  absentCount: number;
  atRisk: boolean;
  overLimit: boolean;
}

export interface AttendanceMatrix {
  /** `live`: açık oturum; sütunu geçicidir (yok = henüz okutmadı; toplamlara girmez). */
  sessions: { id: number; lessonDate: string; live?: boolean; counted?: boolean }[];
  students: MatrixStudent[];
  limit: Limit;
}

export const NOTICE_TYPES = [
  'LESSON_STARTED',
  'ATTENDANCE_STARTED',
  'EXAM',
  'ASSIGNMENT',
  'MATERIAL',
  'LESSON_CANCELLED',
  'ROOM_CHANGED',
] as const;
export type NoticeType = (typeof NOTICE_TYPES)[number];

export interface NoticeFile {
  id: number;
  name: string;
  contentType: string;
  sizeBytes: number;
}

export interface Notice {
  id: number;
  type: NoticeType;
  title: string | null;
  note: string | null;
  eventAt: string | null;
  createdAt: string;
  files: NoticeFile[];
}

export interface NoticeBody {
  type: NoticeType;
  title?: string;
  note?: string;
  eventAt?: string;
  fileIds?: number[];
}

export interface CatalogDepartment {
  id: string;
  name: string;
}
export interface CatalogFaculty {
  id: string;
  name: string;
  departments: CatalogDepartment[];
}
export interface CatalogGrade {
  id: string;
  name: string;
}
export interface Catalog {
  faculties: CatalogFaculty[];
  grades: CatalogGrade[];
}

// ---------- istek yardımcıları ----------
const area = 'acad' as const;
/** Yönetim `api` nesnesiyle aynı biçim, ama her çağrı akademisyen oturumuyla gider (sözleşme denetimi yol sabitlerini buradan okur). */
const api = {
  get: <T>(path: string, query?: Query, signal?: AbortSignal) => apiFetch<T>(path, { query, signal, area }),
  post: <T = void>(path: string, body?: unknown) => apiFetch<T>(path, { method: 'POST', body: body ?? undefined, area }),
  put: <T = void>(path: string, body?: unknown) => apiFetch<T>(path, { method: 'PUT', body: body ?? undefined, area }),
  patch: <T = void>(path: string, body?: unknown) => apiFetch<T>(path, { method: 'PATCH', body: body ?? undefined, area }),
  del: <T = void>(path: string) => apiFetch<T>(path, { method: 'DELETE', area }),
};

// ---------- kimlik ----------
export const getMe = () => api.get<AcademicianMe>(`/academician/me`);
export const apply = (b: ApplyBody) => api.post<{ status: AcademicianStatus }>(`/academician/apply`, b);
export const updateMe = (b: ApplyBody) => api.put<AcademicianMe>(`/academician/me`, b);

// ---------- dersler ----------
export const listCourses = () => api.get<Course[]>(`/academician/courses`);
export const getCourse = (id: number) => api.get<Course>(`/academician/courses/${id}`);
export const createCourse = (b: CourseBody) => api.post<Course>(`/academician/courses`, b);
export const patchCourse = (id: number, b: CoursePatch) => api.patch<Course>(`/academician/courses/${id}`, b);
export const deleteCourse = (id: number) => api.del(`/academician/courses/${id}`);
export const replaceSlots = (id: number, slots: Slot[]) =>
  api.put<Slot[]>(`/academician/courses/${id}/slots`,
    slots.map((s) => ({ dayOfWeek: s.dayOfWeek, startTime: s.startTime, endTime: s.endTime, room: s.room || undefined })),
  );

// ---------- öğrenci rehberi / kayıt ----------
export interface DirectoryQuery {
  q?: string;
  faculty?: string;
  department?: string;
  grade?: string;
  cursor?: number | null;
  size?: number;
}
export const searchStudents = (p: DirectoryQuery) =>
  api.get<CursorPage<DirectoryStudent>>(`/academician/students`, {
    q: p.q || undefined,
    faculty: p.faculty || undefined,
    department: p.department || undefined,
    grade: p.grade || undefined,
    cursor: p.cursor ?? undefined,
    size: p.size ?? 20,
  });

/** Sunucu bir istekte en çok 100 öğrenci kabul eder. */
export const ENROLL_CHUNK = 100;
export const listEnrollments = (courseId: number) => api.get<Enrollment[]>(`/academician/courses/${courseId}/enrollments`);
export const addEnrollments = (courseId: number, studentIds: number[]) =>
  api.post<{ added: number }>(`/academician/courses/${courseId}/enrollments`, { studentIds });
export const bulkEnroll = (courseId: number, department: string, grade?: string) =>
  api.post<{ added: number }>(`/academician/courses/${courseId}/enrollments/bulk`, { department, grade: grade || undefined });
/** Eklemeden eşleşen öğrenci sayısını verir (`dryRun`); onay penceresindeki sayı budur. */
export const bulkEnrollCount = (courseId: number, department: string, grade?: string) =>
  api.post<{ wouldAdd: number }>(`/academician/courses/${courseId}/enrollments/bulk`, { department, grade: grade || undefined, dryRun: true });
export const removeEnrollment = (courseId: number, studentId: number) =>
  api.del(`/academician/courses/${courseId}/enrollments/${studentId}`);

/** Parça parça eklemede bir parça başarısız olursa: o ana dek eklenen sayı `added`da, asıl hata `cause`dadır. */
export class PartialEnrollError extends Error {
  readonly added: number;
  readonly cause: unknown;
  constructor(added: number, cause: unknown) {
    super('partial enrollment');
    this.name = 'PartialEnrollError';
    this.added = added;
    this.cause = cause;
  }
}

/** Seçilen öğrencileri 100'lük parçalarla ekler; toplam eklenen sayıyı döndürür. Parça hatasında PartialEnrollError (eklenen sayıyla) fırlatır. */
export async function addEnrollmentsChunked(
  courseId: number,
  studentIds: number[],
  onProgress?: (done: number, total: number) => void,
): Promise<number> {
  let added = 0;
  for (let i = 0; i < studentIds.length; i += ENROLL_CHUNK) {
    let r: { added: number };
    try {
      r = await addEnrollments(courseId, studentIds.slice(i, i + ENROLL_CHUNK));
    } catch (e) {
      throw new PartialEnrollError(added, e);
    }
    added += r.added;
    onProgress?.(Math.min(i + ENROLL_CHUNK, studentIds.length), studentIds.length);
  }
  return added;
}

// ---------- oturumlar ----------
export const openSession = (courseId: number, b: { lessonDate?: string; slotId?: number; notify?: boolean }) =>
  api.post<AcSession>(`/academician/courses/${courseId}/sessions`, b);
export const listSessions = (courseId: number) => api.get<AcSession[]>(`/academician/courses/${courseId}/sessions`);
export const getSession = (id: number) => api.get<AcSession>(`/academician/sessions/${id}`);
export const getLive = (id: number, signal?: AbortSignal) => api.get<LiveView>(`/academician/sessions/${id}/live`, undefined, signal);
/** Oturumu ve tüm yoklama kayıtlarını siler (yanlışlıkla açılan oturum için). */
export const deleteSession = (id: number) => api.del(`/academician/sessions/${id}`);
export const closeSession = (id: number) => api.post<AcSession>(`/academician/sessions/${id}/close`);
export const reopenSession = (id: number) => api.post<AcSession>(`/academician/sessions/${id}/reopen`);
export const markPresent = (sessionId: number, studentId: number) =>
  api.put<AttendanceRecord>(`/academician/sessions/${sessionId}/records/${studentId}`);
/** İzinli işaretler (gövde `{excused:true}`). */
export const markExcused = (sessionId: number, studentId: number) =>
  api.put<AttendanceRecord>(`/academician/sessions/${sessionId}/records/${studentId}`, { excused: true });
/** Oturumu devamsızlık hesabına kat/katma (geri alınabilir). */
export const patchSession = (id: number, b: { counted: boolean }) => api.patch<AcSession>(`/academician/sessions/${id}`, b);
export const removeRecord = (sessionId: number, studentId: number) =>
  api.del(`/academician/sessions/${sessionId}/records/${studentId}`);
export const acceptPending = (sessionId: number, studentId: number) =>
  api.post<AttendanceRecord>(`/academician/sessions/${sessionId}/pending/${studentId}/accept`);
export const dismissPending = (sessionId: number, studentId: number) =>
  api.post(`/academician/sessions/${sessionId}/pending/${studentId}/dismiss`);

// ---------- devamsızlık ----------
export const getAttendance = (courseId: number) => api.get<AttendanceMatrix>(`/academician/courses/${courseId}/attendance`);
export const attendanceCsv = (courseId: number) =>
  apiBlob(`/academician/courses/${courseId}/attendance.csv`, { area });

// ---------- duyurular ----------
export const listNotices = (courseId: number, cursor?: number | null, size = 20) =>
  api.get<CursorPage<Notice>>(`/academician/courses/${courseId}/notices`, { cursor: cursor ?? undefined, size });
export const createNotice = (courseId: number, b: NoticeBody) =>
  api.post<Notice>(`/academician/courses/${courseId}/notices`, b);
export const deleteNotice = (noticeId: number) => api.del(`/academician/notices/${noticeId}`);
export const deletePendingFile = (fileId: number) => api.del(`/academician/notice-files/${fileId}`);
export const downloadNoticeFile = (noticeId: number, fileId: number) =>
  apiBlob(`/academician/notices/${noticeId}/files/${fileId}`, { area });

/**
 * Duyuru dosyası yükler: `POST /courses/{id}/notice-files` (multipart, tek parça "file", çağrı başına TEK dosya);
 * dönen id duyuru oluşturulurken `fileIds` ile bağlanır. İlerleme için XMLHttpRequest (fetch yükleme ilerlemesi vermez).
 * 401'de bir kez refresh edilip yeniden denenir (client.ts ile aynı kural).
 */
export function uploadNoticeFile(
  courseId: number,
  file: File,
  onProgress?: (fraction: number) => void,
  signal?: AbortSignal,
): Promise<NoticeFile> {
  const attempt = (token: string | null) =>
    new Promise<{ status: number; body: unknown; retryAfter?: number }>((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('POST', buildUrl(`/academician/courses/${courseId}/notice-files`));
      xhr.setRequestHeader('Accept', 'application/json');
      xhr.setRequestHeader('Accept-Language', getCurrentLang());
      xhr.setRequestHeader('X-Device-Id', getDeviceId());
      if (token) xhr.setRequestHeader('Authorization', `Bearer ${token}`);
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable && e.total > 0) onProgress?.(e.loaded / e.total);
      };
      xhr.onerror = () => reject(new ApiError(0, 'NETWORK_ERROR', 'Network error'));
      xhr.onabort = () => reject(new DOMException('Aborted', 'AbortError'));
      xhr.onload = () => {
        let body: unknown = null;
        try {
          body = xhr.responseText ? JSON.parse(xhr.responseText) : null;
        } catch {
          body = null;
        }
        const ra = Number(xhr.getResponseHeader('Retry-After'));
        resolve({ status: xhr.status, body, retryAfter: Number.isFinite(ra) && ra > 0 ? Math.ceil(ra) : undefined });
      };
      signal?.addEventListener('abort', () => xhr.abort(), { once: true });
      const form = new FormData();
      form.append('file', file);
      xhr.send(form);
    });

  const toError = (r: { status: number; body: unknown; retryAfter?: number }) => {
    const b = r.body as { code?: string; message?: string } | null;
    return b && typeof b.code === 'string'
      ? new ApiError(r.status, b.code, b.message ?? b.code, r.retryAfter)
      : new ApiError(r.status, r.status >= 500 ? 'SERVER_ERROR' : `HTTP_${r.status}`, `HTTP ${r.status}`, r.retryAfter);
  };

  return (async () => {
    const store = tokensFor(area);
    let r = await attempt(store.getAccessToken());
    if (r.status === 401) {
      const fresh = await refreshAccessToken(area);
      r = await attempt(fresh);
    }
    if (r.status < 200 || r.status >= 300) throw toError(r);
    return r.body as NoticeFile;
  })();
}

// ---------- herkese açık katalog (fakülte/bölüm/sınıf süzgeçleri) ----------
export const getCatalog = () => apiFetch<Catalog>('/catalog/academic', { auth: false });

// ---------- sorgu anahtarları ----------
export const acadKeys = {
  all: ['academician'] as const,
  me: () => ['academician', 'me'] as const,
  courses: () => ['academician', 'courses'] as const,
  course: (id: number) => ['academician', 'course', id] as const,
  enrollments: (id: number) => ['academician', 'course', id, 'enrollments'] as const,
  sessions: (id: number) => ['academician', 'course', id, 'sessions'] as const,
  session: (id: number) => ['academician', 'session', id] as const,
  attendance: (id: number) => ['academician', 'course', id, 'attendance'] as const,
  notices: (id: number) => ['academician', 'course', id, 'notices'] as const,
  students: (p: Omit<DirectoryQuery, 'cursor'>) => ['academician', 'students', p] as const,
  catalog: () => ['academician', 'catalog'] as const,
};
