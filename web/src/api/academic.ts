// Akademik yönetim (yönetici). Sözleşme: docs/API_CONTRACTS_V2.md "Akademik" C) ve D).
// Uçlar: /api/admin/academic/events (+import, publish/unpublish), /api/admin/academic/exams, /api/admin/announcements (+audience-count).
import { api } from './client';

export type CalendarKind =
  'DONEM_BASLANGIC' | 'DERS_KAYIT' | 'VIZE' | 'FINAL' | 'BUT' | 'TATIL' | 'RESMI_TATIL' | 'DIGER';
export const CALENDAR_KINDS: CalendarKind[] = [
  'DONEM_BASLANGIC',
  'DERS_KAYIT',
  'VIZE',
  'FINAL',
  'BUT',
  'TATIL',
  'RESMI_TATIL',
  'DIGER',
];

export type ExamType = 'VIZE' | 'FINAL' | 'BUT' | 'QUIZ' | 'ODEV' | 'DIGER';
export const EXAM_TYPES: ExamType[] = ['VIZE', 'FINAL', 'BUT', 'QUIZ', 'ODEV', 'DIGER'];

export type Grade = 'PREP' | '1' | '2' | '3' | '4' | '5' | '6' | 'MASTER' | 'PHD';
export const GRADES: Grade[] = ['PREP', '1', '2', '3', '4', '5', '6', 'MASTER', 'PHD'];

export interface AdminPage<T> {
  items: T[];
  page: number;
  size: number;
  total: number;
}

export interface AcademicEvent {
  id: number;
  kind: CalendarKind;
  title: string;
  startsAt: string;
  endsAt: string | null;
  allDay: boolean;
  scopeDepartment: string | null;
  note: string | null;
  published: boolean;
}
export interface AcademicEventInput {
  kind: CalendarKind;
  title: string;
  startsAt: string;
  endsAt?: string | null;
  allDay: boolean;
  scopeDepartment?: string | null;
  note?: string | null;
  published: boolean;
}
export interface EventImportResult {
  created: number;
  errors: { line: number; message: string }[];
}

export interface ExamSchedule {
  id: number;
  title: string;
  type: ExamType;
  term: string;
  courseCode: string | null;
  faculty: string | null;
  department: string | null;
  grade: Grade | null;
  startsAt: string;
  endsAt: string | null;
  room: string | null;
  note: string | null;
  published: boolean;
}
export interface ExamScheduleInput {
  title: string;
  type: ExamType;
  term: string;
  courseCode?: string | null;
  faculty?: string | null;
  department?: string | null;
  grade?: Grade | null;
  startsAt: string;
  endsAt?: string | null;
  room?: string | null;
  note?: string | null;
  published: boolean;
}

export type AnnouncementStatus = 'all' | 'draft' | 'scheduled' | 'active' | 'expired';
export interface AdminAnnouncement {
  id: number;
  title: string;
  body: string;
  department: string | null;
  faculty: string | null;
  grade: Grade | null;
  pinned: boolean;
  publishAt: string | null;
  expiresAt: string | null;
  attachmentUrl: string | null;
  published: boolean;
  notify: boolean;
  notifiedAt: string | null;
  createdBy: number | null;
  readCount: number;
  createdAt: string;
}
export interface AnnouncementInput {
  title: string;
  body: string;
  department?: string | null;
  faculty?: string | null;
  grade?: Grade | null;
  pinned: boolean;
  publishAt?: string | null;
  expiresAt?: string | null;
  attachmentUrl?: string | null;
  published: boolean;
  notify: boolean;
}
export interface Audience {
  department?: string;
  faculty?: string;
  grade?: string;
}

export const acdKeys = {
  all: ['academic'] as const,
  events: (p: object) => ['academic', 'events', p] as const,
  exams: (p: object) => ['academic', 'exams', p] as const,
  announcements: (p: object) => ['academic', 'announcements', p] as const,
  audience: (a: Audience) => ['academic', 'audience', a] as const,
};

const EV = '/admin/academic/events';
const EX = '/admin/academic/exams';
const AN = '/admin/announcements';

export interface ListParams {
  page?: number;
  size?: number;
  q?: string;
  published?: boolean;
  kind?: string;
  type?: string;
  department?: string;
  grade?: string;
  status?: string;
}
const clean = (p: ListParams) => ({
  ...p,
  q: p.q || undefined,
  kind: p.kind || undefined,
  type: p.type || undefined,
  department: p.department || undefined,
  grade: p.grade || undefined,
  status: p.status && p.status !== 'all' ? p.status : undefined,
});

export const listEvents = (p: ListParams) => api.get<AdminPage<AcademicEvent>>(EV, clean(p));
export const createEvent = (b: AcademicEventInput) => api.post<AcademicEvent>(EV, b);
export const updateEvent = (id: number, b: Partial<AcademicEventInput>) =>
  api.patch<AcademicEvent>(`${EV}/${id}`, b);
export const deleteEvent = (id: number) => api.del(`${EV}/${id}`);
export const setEventPublished = (id: number, on: boolean) =>
  api.post<AcademicEvent>(`${EV}/${id}/${on ? 'publish' : 'unpublish'}`);
export const importEvents = (b: { text: string; publish: boolean }) =>
  api.post<EventImportResult>(`${EV}/import`, b);

export const listExams = (p: ListParams) => api.get<AdminPage<ExamSchedule>>(EX, clean(p));
export const createExam = (b: ExamScheduleInput) => api.post<ExamSchedule>(EX, b);
export const updateExam = (id: number, b: Partial<ExamScheduleInput>) =>
  api.patch<ExamSchedule>(`${EX}/${id}`, b);
export const deleteExam = (id: number) => api.del(`${EX}/${id}`);
export const setExamPublished = (id: number, on: boolean) =>
  api.post<ExamSchedule>(`${EX}/${id}/${on ? 'publish' : 'unpublish'}`);

export const listAnnouncements = (p: ListParams) => api.get<AdminPage<AdminAnnouncement>>(AN, clean(p));
export const createAnnouncement = (b: AnnouncementInput) => api.post<AdminAnnouncement>(AN, b);
export const updateAnnouncement = (id: number, b: Partial<AnnouncementInput>) =>
  api.patch<AdminAnnouncement>(`${AN}/${id}`, b);
export const deleteAnnouncement = (id: number) => api.del(`${AN}/${id}`);
export const setAnnouncementPublished = (id: number, on: boolean) =>
  api.post<AdminAnnouncement>(`${AN}/${id}/${on ? 'publish' : 'unpublish'}`);
export const audienceCount = (a: Audience) =>
  api.get<{ count: number }>(`${AN}/audience-count`, {
    department: a.department || undefined,
    faculty: a.faculty || undefined,
    grade: a.grade || undefined,
  });
