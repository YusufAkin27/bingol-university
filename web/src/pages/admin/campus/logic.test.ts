import { describe, expect, it } from 'vitest';
import type { CampusPlace, LatLng } from '../../../api/adminCampus';
import {
  EMPTY_FILTERS,
  EMPTY_PLACE_FORM,
  addUnits,
  categoryCounts,
  configToForm,
  filterPlaces,
  isPublicOsmTiles,
  latestUpdate,
  osmLink,
  parseCoord,
  parseLatLngPair,
  parsePoints,
  pointInPolygon,
  selfIntersects,
  sortPlaces,
  validateConfigForm,
  validatePlaceForm,
  validateTileUrl,
  validateWebUrl,
  resolveCategories,
  categoryLabel,
  boundarySourceKind,
  boundsToSend,
  type PlaceFormState,
} from './logic';

const BOUNDARY: LatLng[] = [
  [38.87, 40.48],
  [38.87, 40.52],
  [38.9, 40.52],
  [38.9, 40.48],
];

const CTX = { photoUrl: null as string | null };

const OK_FORM: PlaceFormState = {
  ...EMPTY_PLACE_FORM,
  name: 'Mühendislik Fakültesi',
  category: 'faculty',
  lat: '38.8847',
  lng: '40.4981',
};

describe('koordinat sayıları', () => {
  it('nokta ve virgül ondalığını okur, boş/geçersizde NaN verir', () => {
    expect(parseCoord('38.8847')).toBe(38.8847);
    expect(parseCoord(' 40,4981 ')).toBe(40.4981);
    expect(parseCoord('-12')).toBe(-12);
    expect(parseCoord('')).toBeNaN();
    expect(parseCoord('12abc')).toBeNaN();
    expect(parseCoord('1.2.3')).toBeNaN();
  });

  it('panodan gelen çifti çözer ve aralık dışını reddeder', () => {
    expect(parseLatLngPair('38.8847, 40.4981')).toEqual({ lat: 38.8847, lng: 40.4981 });
    expect(parseLatLngPair('38.8847 40.4981')).toEqual({ lat: 38.8847, lng: 40.4981 });
    expect(parseLatLngPair('91, 40')).toBeNull();
    expect(parseLatLngPair('38.88, 181')).toBeNull();
    expect(parseLatLngPair('yalnız-bir')).toBeNull();
    expect(parseLatLngPair('1, 2, 3')).toBeNull();
  });
});

describe('poligon çözümleme', () => {
  it('boş metin geçerlidir (nokta yok)', () => {
    expect(parsePoints('  ')).toEqual({ points: [], error: null });
  });

  it('satır satır "enlem, boylam" okur', () => {
    const r = parsePoints('38.87, 40.48\n38.87, 40.52\n38.90 40.52');
    expect(r.error).toBeNull();
    expect(r.points).toEqual([
      [38.87, 40.48],
      [38.87, 40.52],
      [38.9, 40.52],
    ]);
  });

  it('JSON dizisini [enlem, boylam] sırasında okur ve kapanış noktasını atar', () => {
    const r = parsePoints('[[38.87,40.48],[38.87,40.52],[38.9,40.52],[38.87,40.48]]');
    expect(r.error).toBeNull();
    expect(r.points).toHaveLength(3);
  });

  it('GeoJSON Polygon / Feature: [boylam, enlem] sırasını çevirir', () => {
    const geo = {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [
          [
            [40.48, 38.87],
            [40.52, 38.87],
            [40.52, 38.9],
            [40.48, 38.87],
          ],
        ],
      },
    };
    const r = parsePoints(JSON.stringify(geo));
    expect(r.error).toBeNull();
    expect(r.points[0]).toEqual([38.87, 40.48]);
    expect(r.points).toHaveLength(3);
  });

  it('GeoJSON FeatureCollection ve MultiPolygon ilk halkayı alır', () => {
    const ring = [
      [40.48, 38.87],
      [40.52, 38.87],
      [40.5, 38.9],
    ];
    const fc = { type: 'FeatureCollection', features: [{ type: 'Feature', geometry: { type: 'MultiPolygon', coordinates: [[ring]] } }] };
    expect(parsePoints(JSON.stringify(fc)).points).toHaveLength(3);
  });

  it('hata kodları: biçim, aralık, az nokta, çok nokta, kendini kesen', () => {
    expect(parsePoints('abc')).toMatchObject({ error: { code: 'format', index: 1 } });
    expect(parsePoints('38.87, 40.48\nbozuk satır')).toMatchObject({ error: { code: 'format', index: 2 } });
    expect(parsePoints('{ bozuk json')).toMatchObject({ error: { code: 'format' } });
    expect(parsePoints('{"type":"Point","coordinates":[1,2]}')).toMatchObject({ error: { code: 'format' } });
    expect(parsePoints('38.87, 40.48\n95, 40.52\n38.9, 40.5')).toMatchObject({ error: { code: 'range', index: 2 } });
    expect(parsePoints('38.87, 40.48\n38.87, 40.52')).toMatchObject({ error: { code: 'tooFew' } });
    const many = Array.from({ length: 501 }, (_, i) => `${38 + i / 10000}, ${40 + (i % 7) / 1000}`).join('\n');
    expect(parsePoints(many)).toMatchObject({ error: { code: 'tooMany' } });
    // kelebek (8 şekli): kenarlar kesişir
    expect(parsePoints('38.87, 40.48\n38.9, 40.52\n38.9, 40.48\n38.87, 40.52')).toMatchObject({ error: { code: 'selfIntersect' } });
  });

  it('selfIntersects: düzgün dörtgen kesişmez', () => {
    expect(selfIntersects(BOUNDARY)).toBe(false);
  });

  it('pointInPolygon: içeri/dışarı', () => {
    expect(pointInPolygon(38.8847, 40.4981, BOUNDARY)).toBe(true);
    expect(pointInPolygon(39.5, 40.4981, BOUNDARY)).toBe(false);
    expect(pointInPolygon(38.88, 41, BOUNDARY)).toBe(false);
  });
});

describe('karo adresi', () => {
  it('geçerli adresleri kabul eder', () => {
    expect(validateTileUrl('https://tile.openstreetmap.org/{z}/{x}/{y}.png')).toBeNull();
    expect(validateTileUrl('https://{s}.tile.example.com/{z}/{x}/{y}{r}.png')).toBeNull();
    expect(validateTileUrl('https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=abc')).toBeNull();
  });

  it('hata kodları: boş, http, yer tutucu eksik, boşluk, alan adı yok', () => {
    expect(validateTileUrl('')).toBe('required');
    expect(validateTileUrl('http://tile.example.com/{z}/{x}/{y}.png')).toBe('notHttps');
    expect(validateTileUrl('https://tile.example.com/{z}/{x}.png')).toBe('placeholders');
    expect(validateTileUrl('https://tile.example.com/{z}/{x}/{y}.png ?a')).toBe('invalid');
    expect(validateTileUrl('https://localhost/{z}/{x}/{y}.png')).toBe('invalid');
    expect(validateTileUrl(`https://a.example.com/${'x'.repeat(500)}/{z}/{x}/{y}`)).toBe('tooLong');
  });

  it('herkese açık OSM sunucusunu tanır', () => {
    expect(isPublicOsmTiles('https://tile.openstreetmap.org/{z}/{x}/{y}.png')).toBe(true);
    expect(isPublicOsmTiles('https://a.tile.openstreetmap.org/{z}/{x}/{y}.png')).toBe(true);
    expect(isPublicOsmTiles('https://tiles.example.com/{z}/{x}/{y}.png')).toBe(false);
  });

  it('OSM bağlantısı mlat/mlon taşır', () => {
    expect(osmLink(38.8847, 40.4981)).toBe(
      'https://www.openstreetmap.org/?mlat=38.8847&mlon=40.4981#map=18/38.8847/40.4981',
    );
  });
});

describe('yer formu doğrulaması', () => {
  it('geçerli formdan gövde üretir', () => {
    const v = validatePlaceForm({ ...OK_FORM, summary: ' Kitaplık ', units: ['A'] }, BOUNDARY, { ...CTX, photoUrl: 'https://x/p.jpg', unitSourceCode: 'mmf' });
    expect(v.errors).toEqual({});
    expect(v.warnings).toEqual([]);
    expect(v.input).toEqual({
      name: 'Mühendislik Fakültesi',
      category: 'faculty',
      lat: 38.8847,
      lng: 40.4981,
      summary: 'Kitaplık',
      photoUrl: 'https://x/p.jpg',
      units: ['A'],
      footprint: null,
      sortKey: 0,
      active: true,
      webUrl: null,
      remote: false,
      unitSourceCode: 'mmf',
    });
  });

  it('zorunlu alanlar ve aralıklar', () => {
    const v = validatePlaceForm(EMPTY_PLACE_FORM, [], CTX);
    expect(v.input).toBeNull();
    expect(v.errors.name?.code).toBe('required');
    expect(v.errors.category?.code).toBe('required');
    expect(v.errors.lat?.code).toBe('required');
    expect(v.errors.lng?.code).toBe('required');

    expect(validatePlaceForm({ ...OK_FORM, lat: '91' }, [], CTX).errors.lat?.code).toBe('latRange');
    expect(validatePlaceForm({ ...OK_FORM, lat: '-90.5' }, [], CTX).errors.lat?.code).toBe('latRange');
    expect(validatePlaceForm({ ...OK_FORM, lng: '180.1' }, [], CTX).errors.lng?.code).toBe('lngRange');
    expect(validatePlaceForm({ ...OK_FORM, lng: 'x' }, [], CTX).errors.lng?.code).toBe('invalid');
    expect(validatePlaceForm({ ...OK_FORM, lat: '90', lng: '-180' }, [], CTX).input).not.toBeNull();
    expect(validatePlaceForm({ ...OK_FORM, sortKey: '1.5' }, [], CTX).errors.sortKey?.code).toBe('sortKey');
    expect(validatePlaceForm({ ...OK_FORM, sortKey: '10000' }, [], CTX).errors.sortKey?.code).toBe('sortKey');
    expect(validatePlaceForm({ ...OK_FORM, name: 'x'.repeat(121) }, [], CTX).errors.name?.code).toBe('tooLong');
    expect(validatePlaceForm({ ...OK_FORM, summary: 'x'.repeat(501) }, [], CTX).errors.summary?.code).toBe('tooLong');
  });

  it('kampüs sınırı dışındaki nokta UYARI verir ama kaydı engellemez', () => {
    const v = validatePlaceForm({ ...OK_FORM, lat: '39.5' }, BOUNDARY, CTX);
    expect(v.warnings).toContain('outsideBoundary');
    expect(v.input).not.toBeNull();
    // sınır tanımsızsa uyarı yok
    expect(validatePlaceForm({ ...OK_FORM, lat: '39.5' }, [], CTX).warnings).toEqual([]);
  });

  it('bina izi: geçerli iz gövdeye girer, bozuk iz hata, sınır dışı köşe uyarı', () => {
    const fp = '38.880, 40.490\n38.880, 40.495\n38.885, 40.495';
    const ok = validatePlaceForm({ ...OK_FORM, footprintText: fp }, BOUNDARY, CTX);
    expect(ok.input?.footprint).toHaveLength(3);
    const bad = validatePlaceForm({ ...OK_FORM, footprintText: '38.88, 40.49\n38.88, 40.495' }, BOUNDARY, CTX);
    expect(bad.errors.footprint?.code).toBe('poly.tooFew');
    expect(bad.input).toBeNull();
    const out = validatePlaceForm({ ...OK_FORM, footprintText: '38.88, 40.49\n38.88, 40.60\n38.885, 40.60' }, BOUNDARY, CTX);
    expect(out.warnings).toContain('footprintOutside');
  });
});

describe('harita ayarı doğrulaması', () => {
  const base = configToForm({
    center: { lat: 38.8847, lng: 40.4981 },
    zoom: { initial: 16, min: 14, max: 19 },
    boundary: BOUNDARY,
    tiles: { urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', attribution: '© OpenStreetMap', maxNativeZoom: 19 },
  });

  it('geçerli ayarı gövdeye çevirir ve OSM uyarısı verir', () => {
    const v = validateConfigForm(base);
    expect(v.errors).toEqual({});
    expect(v.warnings).toEqual(['osmPublic']);
    expect(v.config?.zoom).toEqual({ initial: 16, min: 14, max: 19 });
    expect(v.config?.boundary).toHaveLength(4);
  });

  it('yakınlaştırma sırası ve aralığı', () => {
    expect(validateConfigForm({ ...base, zoomMin: '20', zoomMax: '18' }).errors.zoomMax?.code).toBe('zoomOrder');
    expect(validateConfigForm({ ...base, zoomInitial: '10' }).errors.zoomInitial?.code).toBe('zoomInitialRange');
    expect(validateConfigForm({ ...base, zoomMax: '23' }).errors.zoomMax?.code).toBe('zoomInvalid');
    expect(validateConfigForm({ ...base, zoomMin: '1.5' }).errors.zoomMin?.code).toBe('zoomInvalid');
    expect(validateConfigForm({ ...base, maxNativeZoom: '' }).errors.maxNativeZoom?.code).toBe('zoomInvalid');
  });

  it('karo adresi, atıf, sınır ve merkez hataları', () => {
    expect(validateConfigForm({ ...base, tileUrl: 'http://x.example.com/{z}/{x}/{y}.png' }).errors.tileUrl?.code).toBe('tile.notHttps');
    expect(validateConfigForm({ ...base, tileUrl: 'https://x.example.com/tile.png' }).errors.tileUrl?.code).toBe('tile.placeholders');
    expect(validateConfigForm({ ...base, attribution: ' ' }).errors.attribution?.code).toBe('required');
    expect(validateConfigForm({ ...base, boundaryText: '38.87, 40.48' }).errors.boundary?.code).toBe('poly.tooFew');
    expect(validateConfigForm({ ...base, lat: '95' }).errors.lat?.code).toBe('latRange');
  });

  it('kendi sunucusunda OSM uyarısı çıkmaz; merkez sınır dışında ise uyarı', () => {
    const own = validateConfigForm({ ...base, tileUrl: 'https://tiles.bu-kampus.example/{z}/{x}/{y}.png' });
    expect(own.warnings).toEqual([]);
    expect(validateConfigForm({ ...base, lat: '39.5' }).warnings).toContain('centerOutside');
  });

  it('sınırı boş bırakmak geçerlidir', () => {
    const v = validateConfigForm({ ...base, boundaryText: '' });
    expect(v.errors.boundary).toBeUndefined();
    expect(v.config?.boundary).toEqual([]);
  });
});

const place = (over: Partial<CampusPlace>): CampusPlace => ({
  id: 1,
  name: 'Yer',
  category: 'faculty',
  lat: 38.88,
  lng: 40.49,
  summary: null,
  photoUrl: null,
  units: [],
  footprint: null,
  sortKey: 0,
  active: true,
  ...over,
});

describe('liste mantığı', () => {
  const list = [
    place({ id: 1, name: 'Mühendislik Fakültesi', units: ['Bilgisayar Mühendisliği'], sortKey: 20, updatedAt: '2026-10-01T10:00:00Z' }),
    place({ id: 2, name: 'Merkez Kütüphane', category: 'library', sortKey: 10, active: false, updatedAt: '2026-10-05T10:00:00Z' }),
    place({ id: 3, name: 'Çınar Yemekhanesi', category: 'dining', summary: 'Öğle yemeği', sortKey: 10 }),
  ];

  it('arama Türkçe/aksan duyarsızdır ve birim adlarına bakar', () => {
    expect(filterPlaces(list, { ...EMPTY_FILTERS, q: 'cinar' }).map((p) => p.id)).toEqual([3]);
    expect(filterPlaces(list, { ...EMPTY_FILTERS, q: 'bilgisayar' }).map((p) => p.id)).toEqual([1]);
    expect(filterPlaces(list, { ...EMPTY_FILTERS, q: 'OGLE' }).map((p) => p.id)).toEqual([3]);
  });

  it('kategori ve durum süzgeci', () => {
    expect(filterPlaces(list, { ...EMPTY_FILTERS, category: 'library' }).map((p) => p.id)).toEqual([2]);
    expect(filterPlaces(list, { ...EMPTY_FILTERS, status: 'inactive' }).map((p) => p.id)).toEqual([2]);
    expect(filterPlaces(list, { ...EMPTY_FILTERS, status: 'active' }).map((p) => p.id)).toEqual([1, 3]);
  });

  it('sıralama', () => {
    expect(sortPlaces(list, 'sortKey').map((p) => p.id)).toEqual([3, 2, 1]); // eşitlikte ada göre (Ç < M)
    expect(sortPlaces(list, 'name').map((p) => p.id)).toEqual([3, 2, 1]);
    expect(sortPlaces(list, 'updated').map((p) => p.id)).toEqual([2, 1, 3]);
  });

  it('kategori sayımı ve son güncelleme', () => {
    expect(categoryCounts([...list, place({ id: 4 })])).toEqual([
      { category: 'faculty', count: 2 },
      { category: 'library', count: 1 },
      { category: 'dining', count: 1 },
    ]);
    expect(latestUpdate(null, '2026-10-01T10:00:00Z', undefined, '2026-10-05T10:00:00Z')).toBe('2026-10-05T10:00:00Z');
    expect(latestUpdate(null, undefined)).toBeNull();
  });

  it('birim etiketi: tekrar ve boşluk temizliği, üst sınır', () => {
    expect(addUnits(['Bilgisayar'], ' bilgisayar ,  Elektrik ; ')).toEqual(['Bilgisayar', 'Elektrik']);
    const full = Array.from({ length: 30 }, (_, i) => `B${i}`);
    expect(addUnits(full, 'Yeni')).toHaveLength(30);
  });
});

describe('birim web adresi', () => {
  it('boş geçerli; yalnız https + bingol.edu.tr (alt alan dahil)', () => {
    expect(validateWebUrl('')).toBeNull();
    expect(validateWebUrl('https://fef.bingol.edu.tr')).toBeNull();
    expect(validateWebUrl('https://www.bingol.edu.tr/tr/universitemiz/yonetim/rektor')).toBeNull();
    expect(validateWebUrl('https://bingol.edu.tr')).toBeNull();
    expect(validateWebUrl('http://fef.bingol.edu.tr')).toBe('notHttps');
    expect(validateWebUrl('https://bingol.edu.tr.evil.com')).toBe('host');
    expect(validateWebUrl('https://evilbingol.edu.tr')).toBe('host');
    expect(validateWebUrl('https://user:pw@fef.bingol.edu.tr')).toBe('invalid');
    expect(validateWebUrl('https://fef.bingol.edu.tr/a b')).toBe('invalid');
    expect(validateWebUrl(`https://fef.bingol.edu.tr/${'x'.repeat(300)}`)).toBe('tooLong');
  });

  it('formda web adresi hatası kaydı engeller; geçerli adres gövdeye girer', () => {
    expect(validatePlaceForm({ ...OK_FORM, webUrl: 'https://example.com' }, [], CTX).errors.webUrl?.code).toBe('web.host');
    expect(validatePlaceForm({ ...OK_FORM, webUrl: ' https://fef.bingol.edu.tr ' }, [], CTX).input?.webUrl).toBe(
      'https://fef.bingol.edu.tr',
    );
  });
});

describe('uzak birim ve dinamik kategori', () => {
  it('uzak birimde sınır dışı uyarısı çıkmaz', () => {
    const far = { ...OK_FORM, lat: '38.987914', lng: '40.672833' }; // Ilıcalar Termal Tesis
    expect(validatePlaceForm(far, BOUNDARY, CTX).warnings).toContain('outsideBoundary');
    const remote = validatePlaceForm({ ...far, remote: true }, BOUNDARY, CTX);
    expect(remote.warnings).toEqual([]);
    expect(remote.input?.remote).toBe(true);
  });

  it('kategori sunucu listesine göre doğrulanır; liste yoksa yalnız seçilmiş olması yeter', () => {
    expect(validatePlaceForm({ ...OK_FORM, category: 'bilinmez' }, [], { ...CTX, categories: ['faculty'] }).errors.category?.code).toBe(
      'categoryUnknown',
    );
    expect(validatePlaceForm({ ...OK_FORM, category: 'bilinmez' }, [], CTX).errors.category).toBeUndefined();
  });

  it('kategori listesi: sunucu önceliklidir, yoksa 12 yedek; kayıttaki bilinmeyen anahtar eklenir', () => {
    const server = [{ key: 'faculty', label: 'Fakülteler' }];
    expect(resolveCategories(server).map((c) => c.key)).toEqual(['faculty']);
    expect(resolveCategories(undefined)).toHaveLength(12);
    expect(resolveCategories(undefined).map((c) => c.label)).toEqual(
      expect.arrayContaining(['Fakülte', 'Enstitü', 'Yüksekokul', 'Meslek yüksekokulu', 'Merkezi birim', 'Sağlık', 'Sosyal yaşam', 'Yurt ve konaklama', 'Hizmet', 'Yemekhane', 'Spor', 'Kütüphane']),
    );
    const withUnknown = resolveCategories(server, ['faculty', 'eski']);
    expect(withUnknown.map((c) => c.key)).toEqual(['faculty', 'eski']);
    expect(categoryLabel(withUnknown, 'faculty')).toBe('Fakülteler');
    expect(categoryLabel(withUnknown, 'eski')).toBe('eski');
  });
});

describe('sınır kaynağı ve kaydırma sınırı', () => {
  it('kaynak türünü tanır', () => {
    expect(boundarySourceKind('OSM')).toBe('osm');
    expect(boundarySourceKind('openstreetmap')).toBe('osm');
    expect(boundarySourceKind('yaklaşık')).toBe('approx');
    expect(boundarySourceKind('APPROXIMATE')).toBe('approx');
    expect(boundarySourceKind(null)).toBe('unknown');
    expect(boundarySourceKind('elle')).toBe('unknown');
  });

  it('bounds yalnız merkez ve sınır değişmediyse geri gönderilir', () => {
    const cfg = {
      center: { lat: 38.9, lng: 40.48 },
      zoom: { initial: 16, min: 14, max: 19 },
      boundary: BOUNDARY,
      bounds: { south: 38.86, west: 40.47, north: 38.91, east: 40.53 },
      tiles: { urlTemplate: 'https://t.example.com/{z}/{x}/{y}.png', attribution: 'x', maxNativeZoom: 19 },
    };
    expect(boundsToSend(cfg, { ...cfg, zoom: { initial: 17, min: 14, max: 19 } })).toEqual(cfg.bounds);
    expect(boundsToSend(cfg, { ...cfg, center: { lat: 38.91, lng: 40.48 } })).toBeUndefined();
    expect(boundsToSend(cfg, { ...cfg, boundary: [...BOUNDARY, [38.88, 40.5]] })).toBeUndefined();
  });
});
