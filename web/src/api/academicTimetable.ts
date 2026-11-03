// Resmî ders programı yönetimi (Excel yükleme). Uçlar: /api/admin/academic/timetable/* (docs/ADMIN_API.md "Resmî ders programı").
import { api } from './client';
import type { AdminPage, Grade } from './academic';

export interface TimetableIssue {
  /** Excel satır numarası (1 tabanlı) */
  row: number;
  message: string;
}

export interface TimetableProgram {
  unit: string;
  program: string;
  department: string;
  faculty: string | null;
  catalogMatched: boolean;
  grades: Grade[];
  sessions: number;
  published: boolean;
}

export interface TimetableImportResult {
  dryRun: boolean;
  term: string | null;
  rows: number;
  programs: number;
  inserted: number;
  replacedPrograms: number;
  batchId: number | null;
  items: TimetableProgram[];
  errors: TimetableIssue[];
  warnings: TimetableIssue[];
}

export interface TimetableTerm {
  term: string;
  sessions: number;
  programs: number;
}

export interface TimetableProgramsView {
  terms: TimetableTerm[];
  term: string | null;
  items: TimetableProgram[];
}

export interface TimetableEntry {
  id: number;
  term: string;
  unit: string;
  faculty: string | null;
  department: string;
  program: string;
  grade: Grade;
  group: string | null;
  /** 1 = Pazartesi … 7 = Pazar */
  day: number;
  start: string;
  end: string;
  code: string | null;
  name: string;
  instructor: string | null;
  room: string | null;
  note: string | null;
  sourceUrl: string | null;
  published: boolean;
}

const TT = '/admin/academic/timetable';

export const ttKeys = {
  programs: (term: string) => ['academic', 'timetable', 'programs', term] as const,
  entries: (p: object) => ['academic', 'timetable', 'entries', p] as const,
};

/** dryRun=true: yalnız doğrula ve önizleme getir; false: yaz (hata varsa 422 TIMETABLE_IMPORT_INVALID). */
export function importTimetable(file: File, dryRun: boolean, term?: string): Promise<TimetableImportResult> {
  const form = new FormData();
  form.append('file', file);
  form.append('dryRun', String(dryRun));
  if (term) form.append('term', term);
  return api.postForm<TimetableImportResult>(`${TT}/import`, form);
}

export const listTimetablePrograms = (term: string) =>
  api.get<TimetableProgramsView>(`${TT}/programs`, { term: term || undefined });

export const listTimetableEntries = (p: {
  term: string;
  unit: string;
  program: string;
  grade?: string;
  page: number;
  size: number;
}) => api.get<AdminPage<TimetableEntry>>(`${TT}/entries`, p);

export const deleteTimetableProgram = (term: string, unit: string, program: string) =>
  api.del<{ deleted: number }>(`${TT}/programs?${new URLSearchParams({ term, unit, program }).toString()}`);

export const setTimetablePublished = (term: string, unit: string, program: string, published: boolean) =>
  api.post<{ updated: number }>(`${TT}/publish`, { term, unit, program, published });
