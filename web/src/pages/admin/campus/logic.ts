// Kampüs haritası sayfasının saf mantığı: koordinat/poligon/karo adresi doğrulaması, süzgeç ve sıralama.
// Arayüzden bağımsızdır (test edilebilir); hata kodları `admin.campus.err.*` çevirilerine karşılık gelir.
import {
  FALLBACK_CATEGORIES,
  type CampusCategory,
  type CampusCategoryInfo,
  type CampusConfig,
  type CampusPlace,
  type CampusPlaceInput,
  type LatLng,
} from '../../../api/adminCampus';
import { fold } from '../../../search/fold';

/* ------------------------------------------------------------------ sayılar */

/** "38.88", "38,88", " 40.5 " -> sayı; boş ya da geçersiz ise NaN. */
export function parseCoord(raw: string): number {
  const s = raw.trim().replace(/\s+/g, '');
  if (!s) return NaN;
  const n = /^[+-]?\d+,\d+$/.test(s) ? s.replace(',', '.') : s;
  return /^[+-]?(\d+\.?\d*|\.\d+)$/.test(n) ? Number(n) : NaN;
}

export function inLat(n: number): boolean {
  return Number.isFinite(n) && n >= -90 && n <= 90;
}
export function inLng(n: number): boolean {
  return Number.isFinite(n) && n >= -180 && n <= 180;
}

/** "38.8847, 40.4981" ya da "38.8847 40.4981" (panodan yapıştırma) -> {lat,lng}; geçersizse null. */
export function parseLatLngPair(text: string): { lat: number; lng: number } | null {
  const parts = text.trim().split(/\s*[,;]\s*|\s+/).filter(Boolean);
  if (parts.length !== 2) return null;
  const lat = parseCoord(parts[0]!);
  const lng = parseCoord(parts[1]!);
  return inLat(lat) && inLng(lng) ? { lat, lng } : null;
}

/** Koordinatı yazıya çevirir (en çok 6 hane ≈ 10 cm). */
export function fmtCoord(n: number): string {
  return String(Math.round(n * 1e6) / 1e6);
}

/* ---------------------------------------------------------------- poligonlar */

export type PointsErrorCode = 'format' | 'range' | 'tooFew' | 'tooMany' | 'selfIntersect';
export interface PointsError {
  code: PointsErrorCode;
  /** Hatalı satır/nokta numarası (1 tabanlı), biliniyorsa. */
  index?: number;
}
export interface PointsResult {
  points: LatLng[];
  error: PointsError | null;
}

export const MAX_POLYGON_POINTS = 500;

type Pair = [number, number];

function isNum(v: unknown): v is number {
  return typeof v === 'number' && Number.isFinite(v);
}
function isPair(v: unknown): v is Pair {
  return Array.isArray(v) && v.length >= 2 && isNum(v[0]) && isNum(v[1]);
}

/** GeoJSON (Polygon/MultiPolygon/Feature/FeatureCollection) -> dış halka [boylam, enlem] çiftleri; bulunamazsa null. */
function geoJsonRing(value: unknown): unknown[] | null {
  if (!value || typeof value !== 'object') return null;
  const o = value as { type?: unknown; coordinates?: unknown; geometry?: unknown; features?: unknown };
  if (o.type === 'FeatureCollection' && Array.isArray(o.features)) return geoJsonRing(o.features[0]);
  if (o.type === 'Feature') return geoJsonRing(o.geometry);
  if (o.type === 'Polygon' && Array.isArray(o.coordinates)) return (o.coordinates[0] as unknown[]) ?? null;
  if (o.type === 'MultiPolygon' && Array.isArray(o.coordinates)) {
    const first = o.coordinates[0] as unknown[] | undefined;
    return (first?.[0] as unknown[]) ?? null;
  }
  return null;
}

function dropClosing(points: LatLng[]): LatLng[] {
  if (points.length > 3) {
    const a = points[0]!;
    const b = points[points.length - 1]!;
    if (a[0] === b[0] && a[1] === b[1]) return points.slice(0, -1);
  }
  return points;
}

function orient(a: LatLng, b: LatLng, c: LatLng): number {
  const v = (b[1] - a[1]) * (c[0] - b[0]) - (b[0] - a[0]) * (c[1] - b[1]);
  return v === 0 ? 0 : v > 0 ? 1 : 2;
}
function onSegment(a: LatLng, b: LatLng, c: LatLng): boolean {
  return (
    b[0] <= Math.max(a[0], c[0]) &&
    b[0] >= Math.min(a[0], c[0]) &&
    b[1] <= Math.max(a[1], c[1]) &&
    b[1] >= Math.min(a[1], c[1])
  );
}
function segmentsCross(p1: LatLng, q1: LatLng, p2: LatLng, q2: LatLng): boolean {
  const o1 = orient(p1, q1, p2);
  const o2 = orient(p1, q1, q2);
  const o3 = orient(p2, q2, p1);
  const o4 = orient(p2, q2, q1);
  if (o1 !== o2 && o3 !== o4) return true;
  return (
    (o1 === 0 && onSegment(p1, p2, q1)) ||
    (o2 === 0 && onSegment(p1, q2, q1)) ||
    (o3 === 0 && onSegment(p2, p1, q2)) ||
    (o4 === 0 && onSegment(p2, q1, q2))
  );
}

/** Poligon kendi kendini kesiyor mu (bitişik kenarlar yalnız ortak köşede buluşur). */
export function selfIntersects(poly: LatLng[]): boolean {
  const n = poly.length;
  if (n < 4) return false;
  for (let i = 0; i < n; i++) {
    const a1 = poly[i]!;
    const a2 = poly[(i + 1) % n]!;
    for (let j = i + 1; j < n; j++) {
      // bitişik kenarlar (ve son-ilk) atlanır
      if (j === i + 1 || (i === 0 && j === n - 1)) continue;
      if (segmentsCross(a1, a2, poly[j]!, poly[(j + 1) % n]!)) return true;
    }
  }
  return false;
}

/**
 * Koordinat listesini çözer. Kabul edilen biçimler:
 *  - satır satır "enlem, boylam" (ya da boşluk/noktalı virgül ayraçlı),
 *  - JSON dizisi `[[enlem, boylam], ...]`,
 *  - GeoJSON (Polygon/MultiPolygon/Feature/FeatureCollection; GeoJSON [boylam, enlem] sırasındadır, çevrilir).
 * Boş metin geçerlidir (nokta yok). Kapanış noktası (ilk = son) atılır.
 */
export function parsePoints(text: string, minPoints = 3): PointsResult {
  const src = text.trim();
  if (!src) return { points: [], error: null };
  let raw: LatLng[] = [];
  let failIndex: number | undefined;

  if (src.startsWith('{') || src.startsWith('[')) {
    let json: unknown;
    try {
      json = JSON.parse(src);
    } catch {
      return { points: [], error: { code: 'format' } };
    }
    let list: unknown[] | null = null;
    let lngFirst = false;
    if (Array.isArray(json)) {
      // [[[boylam,enlem],...]] (GeoJSON halka listesi) ya da [[enlem,boylam],...]
      if (json.length > 0 && Array.isArray(json[0]) && Array.isArray((json[0] as unknown[])[0])) {
        list = json[0] as unknown[];
        lngFirst = true;
      } else list = json;
    } else {
      list = geoJsonRing(json);
      lngFirst = true;
    }
    if (!list) return { points: [], error: { code: 'format' } };
    for (let i = 0; i < list.length; i++) {
      const p = list[i];
      if (!isPair(p)) return { points: [], error: { code: 'format', index: i + 1 } };
      raw.push(lngFirst ? [p[1], p[0]] : [p[0], p[1]]);
    }
  } else {
    const lines = src.split(/\r?\n/).filter((l) => l.trim() !== '');
    raw = [];
    for (let i = 0; i < lines.length; i++) {
      const pair = parseLatLngPairLoose(lines[i]!);
      if (!pair) {
        failIndex = i + 1;
        break;
      }
      raw.push(pair);
    }
    if (failIndex !== undefined) return { points: [], error: { code: 'format', index: failIndex } };
  }

  for (let i = 0; i < raw.length; i++) {
    const [lat, lng] = raw[i]!;
    if (!inLat(lat) || !inLng(lng)) return { points: [], error: { code: 'range', index: i + 1 } };
  }
  const points = dropClosing(raw);
  if (points.length > MAX_POLYGON_POINTS) return { points, error: { code: 'tooMany' } };
  if (points.length < minPoints) return { points, error: { code: 'tooFew' } };
  if (selfIntersects(points)) return { points, error: { code: 'selfIntersect' } };
  return { points, error: null };
}

/** Satır için: aralıksız sayı çifti (parseLatLngPair, ama aralık denetimi sonra yapılır ve hatası "range" olur). */
function parseLatLngPairLoose(line: string): LatLng | null {
  const parts = line.trim().split(/\s*[,;]\s*|\s+/).filter(Boolean);
  if (parts.length !== 2) return null;
  const a = parseCoord(parts[0]!);
  const b = parseCoord(parts[1]!);
  return Number.isFinite(a) && Number.isFinite(b) ? [a, b] : null;
}

export function pointsToText(points: LatLng[] | null | undefined): string {
  return (points ?? []).map(([a, b]) => `${fmtCoord(a)}, ${fmtCoord(b)}`).join('\n');
}

/** Işın atma yöntemi: nokta çokgenin içinde mi (kenar üstü "içeride" sayılabilir). */
export function pointInPolygon(lat: number, lng: number, poly: LatLng[]): boolean {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [yi, xi] = poly[i]!;
    const [yj, xj] = poly[j]!;
    if (yi > lat !== yj > lat && lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

/** Sınır tanımlıysa (≥3 nokta) içeride mi; tanımsızsa null (bilinmiyor, uyarı verilmez). */
export function insideBoundary(lat: number, lng: number, boundary: LatLng[]): boolean | null {
  return boundary.length >= 3 ? pointInPolygon(lat, lng, boundary) : null;
}

/* --------------------------------------------------------------- karo adresi */

export type TileErrorCode = 'required' | 'tooLong' | 'notHttps' | 'placeholders' | 'invalid';

/** Karo adresi: https + `{z}` `{x}` `{y}` zorunlu (`{s}`, `{r}` isteğe bağlı); boşluk/kontrol karakteri yok. */
export function validateTileUrl(url: string): TileErrorCode | null {
  const u = url.trim();
  if (!u) return 'required';
  if (u.length > 500) return 'tooLong';
  if (/\s/.test(u)) return 'invalid';
  if (!/^https:\/\//i.test(u)) return 'notHttps';
  if (!u.includes('{z}') || !u.includes('{x}') || !u.includes('{y}')) return 'placeholders';
  try {
    const probe = new URL(u.replace(/\{(z|x|y)\}/g, '1').replace(/\{(s|r)\}/g, 'a'));
    if (!probe.hostname || !probe.hostname.includes('.')) return 'invalid';
  } catch {
    return 'invalid';
  }
  return null;
}

/** Herkese açık OpenStreetMap karo sunucusu mu (yoğun kullanıma izin vermez). */
export function isPublicOsmTiles(url: string): boolean {
  return /^https:\/\/([a-c]\.|\{s\}\.)?tile\.openstreetmap\.org\//i.test(url.trim());
}

/** Yeri OpenStreetMap'te gösteren bağlantı (yeni sekmede açılır). */
export function osmLink(lat: number, lng: number, zoom = 18): string {
  const la = fmtCoord(lat);
  const ln = fmtCoord(lng);
  return `https://www.openstreetmap.org/?mlat=${la}&mlon=${ln}#map=${zoom}/${la}/${ln}`;
}

/* ------------------------------------------------------------------- yer formu */

export interface PlaceFormState {
  name: string;
  category: CampusCategory;
  lat: string;
  lng: string;
  summary: string;
  units: string[];
  footprintText: string;
  sortKey: string;
  active: boolean;
  webUrl: string;
  /** Ana yerleşke dışındaki birim. */
  remote: boolean;
}

export const EMPTY_PLACE_FORM: PlaceFormState = {
  name: '',
  category: '',
  lat: '',
  lng: '',
  summary: '',
  units: [],
  footprintText: '',
  sortKey: '0',
  active: true,
  webUrl: '',
  remote: false,
};

export const NAME_MAX = 120;
export const SUMMARY_MAX = 500;
export const UNIT_MAX = 80;
export const UNITS_MAX = 30;
export const SORT_KEY_MAX = 9999;
export const WEB_URL_MAX = 300;

export type WebUrlError = 'notHttps' | 'host' | 'invalid' | 'tooLong';

/** Birim web adresi: boş geçerli; https ve bingol.edu.tr (ya da alt alanı), kullanıcı bilgisi/boşluk yok. */
export function validateWebUrl(raw: string): WebUrlError | null {
  const u = raw.trim();
  if (!u) return null;
  if (u.length > WEB_URL_MAX) return 'tooLong';
  if (/\s/.test(u)) return 'invalid';
  if (!/^https:\/\//i.test(u)) return 'notHttps';
  let url: URL;
  try {
    url = new URL(u);
  } catch {
    return 'invalid';
  }
  if (url.username || url.password) return 'invalid';
  const host = url.hostname.toLowerCase();
  return host === 'bingol.edu.tr' || host.endsWith('.bingol.edu.tr') ? null : 'host';
}

export type PlaceField = 'name' | 'category' | 'lat' | 'lng' | 'summary' | 'footprint' | 'sortKey' | 'unit' | 'webUrl';
export type PlaceWarning = 'outsideBoundary' | 'footprintOutside';

export interface PlaceValidation {
  /** Alan -> hata kodu (`admin.campus.err.<kod>`; poligon hatasında kod + sıra numarası). */
  errors: Partial<Record<PlaceField, { code: string; index?: number }>>;
  warnings: PlaceWarning[];
  /** Hata yoksa gönderilecek gövde. */
  input: CampusPlaceInput | null;
  /** Çözülmüş sayısal değerler (önizleme için); geçersizse null. */
  point: { lat: number; lng: number } | null;
  footprint: LatLng[];
}

export function placeToForm(p: CampusPlace): PlaceFormState {
  return {
    name: p.name,
    category: p.category,
    lat: fmtCoord(p.lat),
    lng: fmtCoord(p.lng),
    summary: p.summary ?? '',
    units: [...p.units],
    footprintText: pointsToText(p.footprint),
    sortKey: String(p.sortKey),
    active: p.active,
    webUrl: p.webUrl ?? '',
    remote: p.remote ?? false,
  };
}

/** Mevcut yerin gövdesi (aktif/pasif gibi tek alanlık değişikliklerde geri kalan her şey aynen gönderilir). */
export function placeToInput(p: CampusPlace): CampusPlaceInput {
  return {
    name: p.name,
    category: p.category,
    lat: p.lat,
    lng: p.lng,
    summary: p.summary,
    photoUrl: p.photoUrl,
    units: p.units,
    footprint: p.footprint,
    sortKey: p.sortKey,
    active: p.active,
    webUrl: p.webUrl ?? null,
    remote: p.remote ?? false,
    unitSourceCode: p.unitSourceCode ?? null,
  };
}

/** Birim etiketini sadeleştirir: boşlukları birleştirir; boşsa/çok uzunsa null. */
export function normalizeUnit(raw: string): string | null {
  const u = raw.replace(/\s+/g, ' ').trim();
  return u && u.length <= UNIT_MAX ? u : null;
}

/** Etiket ekler: aynı ad (büyük/küçük harf, Türkçe katlama) iki kez girilmez, en çok UNITS_MAX. */
export function addUnits(current: string[], raw: string): string[] {
  const out = [...current];
  for (const piece of raw.split(/[,;\n]/)) {
    const u = normalizeUnit(piece);
    if (!u || out.length >= UNITS_MAX) continue;
    if (!out.some((x) => fold(x) === fold(u))) out.push(u);
  }
  return out;
}

export interface PlaceContext {
  photoUrl: string | null;
  /** Geçerli kategori anahtarları (sunucu listesi); boş/yok ise yalnız "seçilmiş mi" denetlenir. */
  categories?: string[];
  /** Formda düzenlenmeyen, korunan birim haberleri bağı. */
  unitSourceCode?: string | null;
}

export function validatePlaceForm(f: PlaceFormState, boundary: LatLng[], ctx: PlaceContext): PlaceValidation {
  const errors: PlaceValidation['errors'] = {};
  const warnings: PlaceWarning[] = [];

  const name = f.name.trim();
  if (!name) errors.name = { code: 'required' };
  else if (name.length > NAME_MAX) errors.name = { code: 'tooLong' };

  if (!f.category) errors.category = { code: 'required' };
  else if (ctx.categories && ctx.categories.length > 0 && !ctx.categories.includes(f.category)) {
    errors.category = { code: 'categoryUnknown' };
  }

  const webErr = validateWebUrl(f.webUrl);
  if (webErr) errors.webUrl = { code: `web.${webErr}` };

  const lat = parseCoord(f.lat);
  const lng = parseCoord(f.lng);
  if (!f.lat.trim()) errors.lat = { code: 'required' };
  else if (Number.isNaN(lat)) errors.lat = { code: 'invalid' };
  else if (!inLat(lat)) errors.lat = { code: 'latRange' };
  if (!f.lng.trim()) errors.lng = { code: 'required' };
  else if (Number.isNaN(lng)) errors.lng = { code: 'invalid' };
  else if (!inLng(lng)) errors.lng = { code: 'lngRange' };

  if (f.summary.trim().length > SUMMARY_MAX) errors.summary = { code: 'tooLong' };

  const sortKey = f.sortKey.trim() === '' ? 0 : Number(f.sortKey);
  if (!Number.isInteger(sortKey) || sortKey < 0 || sortKey > SORT_KEY_MAX) errors.sortKey = { code: 'sortKey' };

  const fp = parsePoints(f.footprintText, 3);
  if (fp.error) errors.footprint = { code: `poly.${fp.error.code}`, index: fp.error.index };

  const point = !errors.lat && !errors.lng ? { lat, lng } : null;
  // uzak birimler ana yerleşke sınırının dışındadır: sınır uyarısı verilmez
  if (!f.remote && point && insideBoundary(point.lat, point.lng, boundary) === false) warnings.push('outsideBoundary');
  if (!f.remote && !errors.footprint && fp.points.length >= 3 && boundary.length >= 3) {
    if (fp.points.some(([a, b]) => !pointInPolygon(a, b, boundary))) warnings.push('footprintOutside');
  }

  const ok = Object.keys(errors).length === 0 && point !== null;
  const input: CampusPlaceInput | null = ok
    ? {
        name,
        category: f.category,
        lat: point.lat,
        lng: point.lng,
        summary: f.summary.trim() || null,
        photoUrl: ctx.photoUrl,
        units: f.units,
        footprint: fp.points.length >= 3 ? fp.points : null,
        sortKey,
        active: f.active,
        webUrl: f.webUrl.trim() || null,
        remote: f.remote,
        unitSourceCode: ctx.unitSourceCode ?? null,
      }
    : null;
  return { errors, warnings, input, point, footprint: errors.footprint ? [] : fp.points };
}

/* ----------------------------------------------------------------- ayar formu */

export interface ConfigFormState {
  lat: string;
  lng: string;
  zoomInitial: string;
  zoomMin: string;
  zoomMax: string;
  boundaryText: string;
  tileUrl: string;
  attribution: string;
  maxNativeZoom: string;
}

export const ZOOM_LIMIT = 22;
export const ATTRIBUTION_MAX = 300;

export type ConfigField =
  | 'lat'
  | 'lng'
  | 'zoomInitial'
  | 'zoomMin'
  | 'zoomMax'
  | 'boundary'
  | 'tileUrl'
  | 'attribution'
  | 'maxNativeZoom';
export type ConfigWarning = 'centerOutside' | 'osmPublic';

export interface ConfigValidation {
  errors: Partial<Record<ConfigField, { code: string; index?: number }>>;
  warnings: ConfigWarning[];
  config: CampusConfig | null;
  boundary: LatLng[];
  center: { lat: number; lng: number } | null;
}

export function configToForm(c: CampusConfig): ConfigFormState {
  return {
    lat: fmtCoord(c.center.lat),
    lng: fmtCoord(c.center.lng),
    zoomInitial: String(c.zoom.initial),
    zoomMin: String(c.zoom.min),
    zoomMax: String(c.zoom.max),
    boundaryText: pointsToText(c.boundary),
    tileUrl: c.tiles.urlTemplate,
    attribution: c.tiles.attribution,
    maxNativeZoom: String(c.tiles.maxNativeZoom),
  };
}

function zoomValue(raw: string): number {
  return raw.trim() === '' ? NaN : Number(raw);
}
const validZoom = (n: number) => Number.isInteger(n) && n >= 0 && n <= ZOOM_LIMIT;

export function validateConfigForm(f: ConfigFormState): ConfigValidation {
  const errors: ConfigValidation['errors'] = {};
  const warnings: ConfigWarning[] = [];

  const lat = parseCoord(f.lat);
  const lng = parseCoord(f.lng);
  if (!f.lat.trim()) errors.lat = { code: 'required' };
  else if (Number.isNaN(lat)) errors.lat = { code: 'invalid' };
  else if (!inLat(lat)) errors.lat = { code: 'latRange' };
  if (!f.lng.trim()) errors.lng = { code: 'required' };
  else if (Number.isNaN(lng)) errors.lng = { code: 'invalid' };
  else if (!inLng(lng)) errors.lng = { code: 'lngRange' };

  const zi = zoomValue(f.zoomInitial);
  const zmin = zoomValue(f.zoomMin);
  const zmax = zoomValue(f.zoomMax);
  if (!validZoom(zi)) errors.zoomInitial = { code: 'zoomInvalid' };
  if (!validZoom(zmin)) errors.zoomMin = { code: 'zoomInvalid' };
  if (!validZoom(zmax)) errors.zoomMax = { code: 'zoomInvalid' };
  if (!errors.zoomMin && !errors.zoomMax && zmin > zmax) errors.zoomMax = { code: 'zoomOrder' };
  if (!errors.zoomInitial && !errors.zoomMin && !errors.zoomMax && (zi < zmin || zi > zmax)) {
    errors.zoomInitial = { code: 'zoomInitialRange' };
  }

  const native = zoomValue(f.maxNativeZoom);
  if (!validZoom(native)) errors.maxNativeZoom = { code: 'zoomInvalid' };

  const poly = parsePoints(f.boundaryText, 3);
  if (poly.error) errors.boundary = { code: `poly.${poly.error.code}`, index: poly.error.index };

  const tileErr = validateTileUrl(f.tileUrl);
  if (tileErr) errors.tileUrl = { code: `tile.${tileErr}` };

  const attribution = f.attribution.trim();
  if (!attribution) errors.attribution = { code: 'required' };
  else if (attribution.length > ATTRIBUTION_MAX) errors.attribution = { code: 'tooLong' };

  const boundary = errors.boundary ? [] : poly.points;
  const center = !errors.lat && !errors.lng ? { lat, lng } : null;
  if (center && insideBoundary(center.lat, center.lng, boundary) === false) warnings.push('centerOutside');
  if (!tileErr && isPublicOsmTiles(f.tileUrl)) warnings.push('osmPublic');

  const ok = Object.keys(errors).length === 0 && center !== null;
  const config: CampusConfig | null = ok
    ? {
        center,
        zoom: { initial: zi, min: zmin, max: zmax },
        boundary,
        tiles: { urlTemplate: f.tileUrl.trim(), attribution, maxNativeZoom: native },
      }
    : null;
  return { errors, warnings, config, boundary, center };
}

/* --------------------------------------------------------------- liste mantığı */

/** Kategori listesi: sunucudan (ayar yanıtı) ya da yedek; kayıtlarda geçen ama listede olmayan anahtarlar da eklenir. */
export function resolveCategories(
  fromServer: CampusCategoryInfo[] | undefined,
  placeKeys: string[] = [],
): CampusCategoryInfo[] {
  const base = fromServer && fromServer.length > 0 ? [...fromServer] : [...FALLBACK_CATEGORIES];
  for (const k of placeKeys) if (k && !base.some((c) => c.key === k)) base.push({ key: k, label: k });
  return base;
}

export function categoryLabel(list: CampusCategoryInfo[], key: string): string {
  return list.find((c) => c.key === key)?.label ?? key;
}

export type PlaceSort = 'sortKey' | 'name' | 'category' | 'updated';
export type StatusFilter = '' | 'active' | 'inactive';

export interface PlaceFilters {
  q: string;
  category: CampusCategory | '';
  status: StatusFilter;
  sort: PlaceSort;
}

export const EMPTY_FILTERS: PlaceFilters = { q: '', category: '', status: '', sort: 'sortKey' };

/** Arama: ad, özet ve birim adları; Türkçe/aksan duyarsız. */
export function filterPlaces(places: CampusPlace[], f: PlaceFilters): CampusPlace[] {
  const q = fold(f.q.trim());
  return places.filter((p) => {
    if (f.category && p.category !== f.category) return false;
    if (f.status === 'active' && !p.active) return false;
    if (f.status === 'inactive' && p.active) return false;
    if (!q) return true;
    return fold([p.name, p.summary ?? '', ...p.units].join(' ')).includes(q);
  });
}

export function sortPlaces(places: CampusPlace[], sort: PlaceSort): CampusPlace[] {
  const byName = (a: CampusPlace, b: CampusPlace) => a.name.localeCompare(b.name, 'tr');
  const list = [...places];
  list.sort((a, b) => {
    if (sort === 'name') return byName(a, b);
    if (sort === 'category') return a.category.localeCompare(b.category) || byName(a, b);
    if (sort === 'updated') {
      const ta = a.updatedAt ? Date.parse(a.updatedAt) : 0;
      const tb = b.updatedAt ? Date.parse(b.updatedAt) : 0;
      return tb - ta || byName(a, b);
    }
    return a.sortKey - b.sortKey || byName(a, b);
  });
  return list;
}

export function categoryCounts(places: CampusPlace[]): { category: CampusCategory; count: number }[] {
  const map = new Map<CampusCategory, number>();
  for (const p of places) map.set(p.category, (map.get(p.category) ?? 0) + 1);
  return [...map.entries()].map(([category, count]) => ({ category, count })).sort((a, b) => b.count - a.count);
}

/** En yeni `updatedAt` (yer ya da ayar); hiçbirinde yoksa null. */
export function latestUpdate(...stamps: (string | null | undefined)[]): string | null {
  let best: string | null = null;
  let bestT = -Infinity;
  for (const s of stamps) {
    if (!s) continue;
    const t = Date.parse(s);
    if (Number.isFinite(t) && t > bestT) {
      best = s;
      bestT = t;
    }
  }
  return best;
}

/* ------------------------------------------- sınır kaynağı ve kaydırma sınırı */

export type BoundarySourceKind = 'osm' | 'approx' | 'unknown';

/** Sunucunun bildirdiği sınır kaynağı: "OSM"/"openstreetmap" ya da "yaklaşık"/"approx..." ; yoksa bilinmiyor. */
export function boundarySourceKind(src: string | null | undefined): BoundarySourceKind {
  const v = fold(src ?? '');
  if (!v) return 'unknown';
  if (v.includes('yaklas') || v.includes('approx') || v.includes('estimat')) return 'approx';
  if (v.includes('osm') || v.includes('openstreetmap')) return 'osm';
  return 'unknown';
}

/**
 * Kaydırma sınırı (`bounds`): merkez ve sınır poligonu değişmediyse aynen geri gönderilir; değiştiyse
 * gönderilmez (sunucu poligondan yeniden hesaplar; eski kutu yeni sınırı kapsamayıp 400 verirdi).
 */
export function boundsToSend(config: CampusConfig, next: CampusConfig): CampusConfig['bounds'] {
  const same =
    config.center.lat === next.center.lat &&
    config.center.lng === next.center.lng &&
    JSON.stringify(config.boundary) === JSON.stringify(next.boundary);
  return same ? (config.bounds ?? undefined) : undefined;
}
