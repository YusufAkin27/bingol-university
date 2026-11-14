/** Akademisyen paneli yolları (yalnız bu klasör ve oturum katmanı kullanır; paths.ts'e dokunulmaz). */
export const ACAD_BASE = '/akademisyen';

/** Yol, akademisyen panelinin altında mı (`/akademisyenx` gibi benzer önekler sayılmaz). */
export const isAcadPath = (path: string): boolean => path === ACAD_BASE || path.startsWith(`${ACAD_BASE}/`);

export const acadPaths = {
  home: ACAD_BASE,
  register: `${ACAD_BASE}/kayit`,
  login: `${ACAD_BASE}/giris`,
  pending: `${ACAD_BASE}/beklemede`,
  courses: `${ACAD_BASE}/dersler`,
  course: (id: number | string, tab?: string) => `${ACAD_BASE}/dersler/${id}${tab ? `?sekme=${tab}` : ''}`,
  enroll: (id: number | string) => `${ACAD_BASE}/dersler/${id}/ogrenciler/ekle`,
  live: (sessionId: number | string) => `${ACAD_BASE}/yoklama/${sessionId}`,
  profile: `${ACAD_BASE}/profil`,
} as const;
