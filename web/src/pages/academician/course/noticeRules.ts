// Duyuru türü başına izinli alanlar ve dosya ön kontrolü. Sunucudaki `NoticeRules` / `NoticeFileService` ile AYNI tablo
// (sunucu asıl denetimi yapar; bu yalnız hızlı geri bildirim içindir). Kural dışı dolu alan sunucuda 400 AC_FIELD_INVALID verir.
import type { NoticeType } from '../../../api/academician';

export type EventRule = 'none' | 'optional' | 'required';

export interface NoticeSpec {
  /** null: alan yasak (gösterilmez). */
  title: { max: number; required: true } | null;
  event: EventRule;
  note: { max: number } | null;
  files: boolean;
}

export const NOTICE_SPECS: Record<NoticeType, NoticeSpec> = {
  LESSON_STARTED: { title: null, event: 'none', note: null, files: false },
  ATTENDANCE_STARTED: { title: null, event: 'none', note: null, files: false },
  EXAM: { title: { max: 120, required: true }, event: 'required', note: { max: 500 }, files: true },
  ASSIGNMENT: { title: { max: 120, required: true }, event: 'required', note: { max: 1000 }, files: true },
  MATERIAL: { title: { max: 120, required: true }, event: 'none', note: { max: 1000 }, files: true },
  LESSON_CANCELLED: { title: null, event: 'required', note: { max: 300 }, files: false },
  ROOM_CHANGED: { title: { max: 100, required: true }, event: 'optional', note: { max: 300 }, files: false },
};

export const MAX_FILES = 5;
export const MAX_FILE_BYTES = 20 * 1024 * 1024;
/** Sunucunun izin listesi (içerik imzası da orada doğrulanır). docm/xlsm/pptm, html, svg, arşiv ve çalıştırılabilirler YOKTUR. */
export const ALLOWED_EXTENSIONS = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'png', 'jpg', 'jpeg'] as const;
export const ACCEPT_ATTR = ALLOWED_EXTENSIONS.map((e) => `.${e}`).join(',');

export const extensionOf = (name: string): string => {
  const i = name.lastIndexOf('.');
  return i < 0 ? '' : name.slice(i + 1).toLowerCase();
};

export type FileCheck = 'type' | 'size' | 'limit' | 'empty';

/** Dosya eklemeden önce yerel kontrol. `count` zaten listedeki dosya sayısıdır. */
export function checkFile(file: Pick<File, 'name' | 'size'>, count: number): FileCheck | null {
  if (count >= MAX_FILES) return 'limit';
  if (!(ALLOWED_EXTENSIONS as readonly string[]).includes(extensionOf(file.name))) return 'type';
  if (file.size <= 0) return 'empty';
  if (file.size > MAX_FILE_BYTES) return 'size';
  return null;
}

/** Alan değerleri duyuru türünün kurallarına uyuyor mu: eksik/fazla alan listesi (boş = geçerli). */
export function validateNotice(type: NoticeType, v: { title: string; note: string; eventAt: string }): ('title' | 'eventAt' | 'note')[] {
  const s = NOTICE_SPECS[type];
  const bad: ('title' | 'eventAt' | 'note')[] = [];
  if (s.title && (!v.title.trim() || v.title.trim().length > s.title.max)) bad.push('title');
  if (s.event === 'required' && !v.eventAt) bad.push('eventAt');
  if (s.note && v.note.trim().length > s.note.max) bad.push('note');
  return bad;
}
