// Akademik yönetim (yönetici). Sözleşme: docs/API_CONTRACTS_V2.md "Akademik" C) ve D).
// Uçlar: /api/admin/academic/events (+import, publish/unpublish).
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

export type Grade = 'PREP' | '1' | '2' | '3' | '4' | '5' | '6' | 'MASTER' | 'PHD';

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

export const acdKeys = {
  all: ['academic'] as const,
  events: (p: object) => ['academic', 'events', p] as const,
};

const EV = '/admin/academic/events';

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

