// Kampüs haritası yönetimi: GET/POST /api/admin/campus/places, PUT/DELETE /api/admin/campus/places/{id} (silme gerekçeli),
// GET/PUT /api/admin/campus/config. İzinler: campus.read / campus.write (FULL ve EDITOR yazar).
// Sözleşme backend dalıyla paralel yazıldı; alan adları göreli sözleşmeye göredir (docs/openapi.json gelince yenilenir).
import { api } from './client';
import { guardHeaders, adminSeg, type GuardOpts } from './guard';

export const CAMPUS_CATEGORIES = [
  'faculty',
  'dining',
  'library',
  'sports',
  'health',
  'admin',
  'dormitory',
  'gate',
  'parking',
  'social',
] as const;
export type CampusCategory = (typeof CAMPUS_CATEGORIES)[number];

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
}

export interface CampusConfig {
  center: { lat: number; lng: number };
  zoom: { initial: number; min: number; max: number };
  boundary: LatLng[];
  tiles: { urlTemplate: string; attribution: string; maxNativeZoom: number };
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
}

const PAGE_SIZE = 100; // sunucu üst sınırı (ADMIN_API: size ≤ 100)
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
    const totalPages = res.totalPages ?? 1;
    if (page + 1 >= totalPages || batch.length === 0) break;
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

export const getCampusConfig = () => api.get<CampusConfig>(`${BASE}/config`);

/** Ayar değişikliği gerekçelidir (X-Admin-Reason + Idempotency-Key). */
export const updateCampusConfig = (config: CampusConfig, g: GuardOpts & { reason: string }) =>
  api.put<CampusConfig>(`${BASE}/config`, config, guardHeaders(g));
