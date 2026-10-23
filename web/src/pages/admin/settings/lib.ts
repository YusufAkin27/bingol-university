/** Ayarlar sayfasının saf mantığı: sunucuyla uyumlu doğrulamalar ve fakülte listesi (`;`) dönüşümleri. */

export const FACULTY_MAX = 120;
export const FACULTIES_TOTAL_MAX = 1000;

/** `;` ile ayrılmış değeri listeye çevirir: kırpar, boşları ve tekrarları atar (sunucu ile aynı). */
export function parseFaculties(raw: string | undefined | null): string[] {
  if (!raw) return [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const part of raw.split(';')) {
    const v = part.trim();
    if (v && !seen.has(v)) {
      seen.add(v);
      out.push(v);
    }
  }
  return out;
}

export function serializeFaculties(list: string[]): string {
  return parseFaculties(list.join(';')).join(';');
}

/** Çipe girilen/yapıştırılan metni ad(lar)a böler (`;`, satır sonu veya virgül ayırıcı). */
export function splitFacultyInput(text: string): string[] {
  return text
    .split(/[;\n\r]+/)
    .map((s) => s.trim())
    .filter(Boolean);
}

export type FacultyError = 'TOO_LONG' | 'TOTAL_TOO_LONG';
export function facultiesError(list: string[]): FacultyError | null {
  if (list.some((f) => f.length > FACULTY_MAX)) return 'TOO_LONG';
  if (serializeFaculties(list).length > FACULTIES_TOTAL_MAX) return 'TOTAL_TOO_LONG';
  return null;
}

/** Listede öğeyi bir konum kaydırır (sınırda aynı listeyi döndürür). */
export function moveItem<T>(list: T[], index: number, delta: -1 | 1): T[] {
  const to = index + delta;
  if (index < 0 || index >= list.length || to < 0 || to >= list.length) return list;
  const next = list.slice();
  [next[index], next[to]] = [next[to], next[index]];
  return next;
}

const VERSION = /^\d+(\.\d+){0,3}$/;

export type SettingError = 'HTTPS' | 'VERSION' | 'BOOL' | 'EMAIL' | 'TOO_LONG';

/** Anahtara göre istemci doğrulaması (sunucu kurallarıyla aynı + e-posta biçimi). Hata yoksa null. */
export function validateSetting(key: string, value: string): SettingError | null {
  const v = value.trim();
  if (key.startsWith('min_version_') || key.startsWith('latest_version_')) {
    return VERSION.test(v) ? null : 'VERSION';
  }
  if (key === 'maintenance_mode') return v === 'true' || v === 'false' ? null : 'BOOL';
  if ((key.startsWith('store_url_') || key === 'banner_url' || key === 'website') && v) {
    return /^https:\/\/\S+$/i.test(v) ? null : 'HTTPS';
  }
  if ((key === 'contact_email' || key === 'support_email') && v) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v) ? null : 'EMAIL';
  }
  if (key === 'faculties') {
    return facultiesError(parseFaculties(v)) ? 'TOO_LONG' : null;
  }
  return null;
}

/** Sayısal sürüm karşılaştırması: "1.10.0" > "1.9.3"; eksik parçalar 0. */
export function compareVersions(a: string, b: string): number {
  const x = a.split('.').map(Number);
  const y = b.split('.').map(Number);
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    const d = (x[i] ?? 0) - (y[i] ?? 0);
    if (d !== 0) return d < 0 ? -1 : 1;
  }
  return 0;
}

export type SettingGroup = 'general' | 'stores' | 'banner' | 'maintenance' | 'faculties';
export const GROUP_KEYS: Record<SettingGroup, string[]> = {
  general: [
    'app_name',
    'website',
    'contact_email',
    'support_email',
    'phone',
    'address',
    'instagram',
    'twitter',
    'youtube',
  ],
  stores: [
    'min_version_android',
    'latest_version_android',
    'store_url_android',
    'min_version_ios',
    'latest_version_ios',
    'store_url_ios',
  ],
  banner: ['banner_text_tr', 'banner_text_en', 'banner_text_ar', 'banner_url'],
  maintenance: ['maintenance_mode', 'maintenance_message_tr', 'maintenance_message_en', 'maintenance_message_ar'],
  faculties: ['faculties'],
};
