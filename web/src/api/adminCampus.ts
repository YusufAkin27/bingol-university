// Kampüs haritası yönetimi: GET/POST /api/admin/campus/places, PUT/DELETE /api/admin/campus/places/{id} (silme gerekçeli),
// GET/PUT /api/admin/campus/config. İzinler: campus.read / campus.write (FULL ve EDITOR yazar).
// Sözleşme backend dalıyla paralel yazıldı; alan adları göreli sözleşmeye göredir (docs/openapi.json gelince yenilenir).
import { api, apiFetch } from './client';
import { guardHeaders, adminSeg, type GuardOpts } from './guard';

/** Kategori anahtarı sunucudan gelir (`GET /admin/campus/config`.categories); sabit liste yalnız yedektir. */
export type CampusCategory = string;

export interface CampusCategoryInfo {
  key: string;
  label: string;
  icon?: string;
  color?: string;
}

/** Sunucu kategori listesi vermezse kullanılan yedek (anahtarlar docs/CAMPUS_MAP.md ile değişebilir; sunucu listesi önceliklidir). */
export const FALLBACK_CATEGORIES: CampusCategoryInfo[] = [
  { key: 'faculty', label: 'Fakülte' },
  { key: 'institute', label: 'Enstitü' },
  { key: 'college', label: 'Yüksekokul' },
  { key: 'vocational', label: 'Meslek yüksekokulu' },
  { key: 'central', label: 'Merkezi birim' },
  { key: 'health', label: 'Sağlık' },
  { key: 'social', label: 'Sosyal yaşam' },
  { key: 'dorm', label: 'Yurt ve konaklama' },
  { key: 'service', label: 'Hizmet' },
  { key: 'dining', label: 'Yemekhane' },
  { key: 'sports', label: 'Spor' },
  { key: 'library', label: 'Kütüphane' },
];

/** Koordinat çifti [enlem, boylam]. */
export type LatLng = [number, number];

export interface CampusPlace {
  id: number;
  name: string;
  category: CampusCategory;
  lat: number;
  lng: number;
  summary: string | null;
  photoUrl: string | null;
  units: string[];
  footprint: LatLng[] | null;
  sortKey: number;
  active: boolean;
  /** Birimin web sayfası (https, bingol.edu.tr alt alanı). */
  webUrl?: string | null;
  /** Ana yerleşke dışındaki birim (sınır uyarısı verilmez). */
  remote?: boolean;
  /** Salt okunur: Birim haberleri bölümlerinden gelir, formda düzenlenmez. */
  departments?: string[];
  /** Birim haberleri kaynağı kodu (bağ korunur, formda düzenlenmez). */
  unitSourceCode?: string | null;
  /** Sözleşmede zorunlu değil; sunucu verirse "son güncelleme" göstergesi kullanır. */
  updatedAt?: string | null;
}

export interface CampusPlaceInput {
  name: string;
  category: CampusCategory;
  lat: number;
  lng: number;
  summary: string | null;
  photoUrl: string | null;
  units: string[];
  footprint: LatLng[] | null;
  sortKey: number;
  active: boolean;
  webUrl?: string | null;
  remote?: boolean;
  unitSourceCode?: string | null;
}

export interface CampusConfig {
  center: { lat: number; lng: number };
  zoom: { initial: number; min: number; max: number };
  boundary: LatLng[];
  tiles: { urlTemplate: string; attribution: string; maxNativeZoom: number; userAgentHint?: string };
  /** Kaydırma sınırı: değiştirilmeden geri gönderilir (sunucu boşsa poligondan hesaplar). */
  bounds?: { south: number; west: number; north: number; east: number } | null;
  /** Sunucudaki kategori listesi (sıra = sekme sırası). */
  categories?: CampusCategoryInfo[];
  /** Sınırın kaynağı: "OSM" ya da "yaklaşık" (APPROXIMATE) gibi; yoksa bilinmiyor. */
  boundarySource?: string | null;
  version?: number;
  updatedAt?: string | null;
}

export const campusKeys = {
  all: ['admin', 'campus'] as const,
  places: ['admin', 'campus', 'places'] as const,
  config: ['admin', 'campus', 'config'] as const,
};

const BASE = '/admin/campus';

interface PlacesPage {
  items?: CampusPlace[];
  content?: CampusPlace[];
  totalPages?: number;
  /** Yönetici ucu `total` döner (docs/CAMPUS_MAP.md); diğer biçimler `totalItems`/`totalElements`. */
  total?: number;
  totalItems?: number;
  totalElements?: number;
}

const PAGE_SIZE = 100; // ADMIN_API: size <= 100
const MAX_PAGES = 10; // 1000 yer: harita için fazlasıyla yeter, sonsuz döngüye karşı sigorta

/**
 * Tüm yerleri çeker (sayfa sayfa). Süzgeç/sıralama istemcide yapılır: yer sayısı küçüktür ve gösterge kartları
 * (toplam, kategori dağılımı) tüm kümeyi ister. Yanıt `{items,...}`, `{content,...}` ya da düz dizi olabilir.
 */
export async function listAllCampusPlaces(signal?: AbortSignal): Promise<CampusPlace[]> {
  const out: CampusPlace[] = [];
  for (let page = 0; page < MAX_PAGES; page++) {
    const res = await api.get<PlacesPage | CampusPlace[]>(`${BASE}/places`, { page, size: PAGE_SIZE }, signal);
    if (Array.isArray(res)) {
      out.push(...res);
      break;
    }
    const batch = res.items ?? res.content ?? [];
    out.push(...batch);
    const total = res.total ?? res.totalItems ?? res.totalElements;
    const more = res.totalPages !== undefined ? page + 1 < res.totalPages : total !== undefined && out.length < total;
    if (!more || batch.length === 0) break;
  }
  return out;
}

export const createCampusPlace = (input: CampusPlaceInput, g?: GuardOpts) =>
  api.post<CampusPlace>(`${BASE}/places`, input, guardHeaders(g));

export const updateCampusPlace = (id: number, input: CampusPlaceInput, g?: GuardOpts) =>
  api.put<CampusPlace>(`${BASE}/places/${adminSeg(id)}`, input, guardHeaders(g));

/** Silme gerekçelidir (X-Admin-Reason). */
export const deleteCampusPlace = (id: number, g: GuardOpts & { reason: string }) =>
  api.del<void>(`${BASE}/places/${adminSeg(id)}`, guardHeaders(g));

/** Fotoğraf: `POST /places/{id}/photo` (multipart `file`; sunucu yeniden kodlar, EXIF siler) ve `DELETE`. */
export const uploadCampusPhoto = (id: number, file: File) => {
  const form = new FormData();
  form.append('file', file);
  return apiFetch<CampusPlace>(`${BASE}/places/${adminSeg(id)}/photo`, { method: 'POST', body: form });
};
export const deleteCampusPhoto = (id: number) => api.del<void>(`${BASE}/places/${adminSeg(id)}/photo`);

export const getCampusConfig = () => api.get<CampusConfig>(`${BASE}/config`);

/** Ayar değişikliği gerekçelidir (X-Admin-Reason + Idempotency-Key). */
export const updateCampusConfig = (config: CampusConfig, g: GuardOpts & { reason: string }) => {
  // salt okunur alanlar (sürüm, kategori listesi, kaynak, zaman) gövdeye girmez
  const { center, zoom, bounds, boundary, tiles } = config;
  return api.put<CampusConfig>(`${BASE}/config`, { center, zoom, bounds: bounds ?? undefined, boundary, tiles }, guardHeaders(g));
};
