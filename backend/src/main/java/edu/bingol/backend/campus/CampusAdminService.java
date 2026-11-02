package edu.bingol.backend.campus;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.campus.CampusDtos.AdminPlace;
import edu.bingol.backend.campus.CampusDtos.AdminPlacePage;
import edu.bingol.backend.campus.CampusDtos.BoundsRequest;
import edu.bingol.backend.campus.CampusDtos.ConfigRequest;
import edu.bingol.backend.campus.CampusDtos.DeleteResult;
import edu.bingol.backend.campus.CampusDtos.MapConfig;
import edu.bingol.backend.campus.CampusDtos.PlaceRequest;
import edu.bingol.backend.campus.CampusDtos.TilesRequest;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaService;
import java.net.URI;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * Kampus haritasi yonetimi: yer CRUD (yumusak silme), harita ayari, fotograf (mevcut medya hatti). Her yazma
 * {@code data_version} sayacini artirir; varlik olaylari sunucu onbellegini gecersiz kilar. Sunucu dogrulamasi
 * burada yapilir (koordinat araliklari, poligon, https karo adresi, boyut sinirlari).
 */
@Service
public class CampusAdminService {

    static final int MAX_PLACES = 2000;
    static final int MAX_BOUNDARY_POINTS = 500;
    static final int MAX_FOOTPRINT_POINTS = 200;
    static final int MAX_UNITS = 20;
    /** Harita sinir kutusu en fazla bu kadar derece (dunya olcekli kutuyu engeller). */
    static final double MAX_BOUNDS_SPAN_DEG = 2.0;
    private static final Pattern PLACEHOLDER = Pattern.compile("\\{([^{}]*)}");
    private static final Set<String> TILE_PLACEHOLDERS = Set.of("z", "x", "y", "s", "r");

    private final CampusPlaceRepository places;
    private final CampusConfigRepository configs;
    private final CampusService service;
    private final MediaService media;

    public CampusAdminService(CampusPlaceRepository places, CampusConfigRepository configs, CampusService service,
                              MediaService media) {
        this.places = places;
        this.configs = configs;
        this.service = service;
        this.media = media;
    }

    // ---------------- yerler ----------------

    @Transactional(readOnly = true)
    public AdminPlacePage list(String category, String q, int page, int size) {
        String cat = "";
        if (category != null && !category.isBlank()) {
            CampusCategory c = CampusCategory.parse(category);
            if (c == null) {
                throw invalidCategory();
            }
            cat = c.key();
        }
        int p = Math.max(page, 0);
        int s = Math.min(Math.max(size, 1), 100);
        String nq = CampusText.normalize(q == null ? "" : q);
        if (nq.length() > CampusService.MAX_QUERY_CHARS) {
            nq = nq.substring(0, CampusService.MAX_QUERY_CHARS).trim();
        }
        String contains = nq.isEmpty() ? "%" : "%" + CampusText.escapeLike(nq) + "%";
        Page<CampusPlace> r = places.adminSearch(cat, contains, PageRequest.of(p, s));
        Map<String, String> hosts = service.unitHosts();
        return new AdminPlacePage(r.getContent().stream()
                .map(x -> view(x, CampusService.unitCode(x, hosts), null)).toList(), p, s, r.getTotalElements());
    }

    @Transactional(readOnly = true)
    public AdminPlace get(Long id) {
        CampusPlace p = load(id);
        String code = CampusService.unitCode(p, service.unitHosts());
        return view(p, code, service.departments(code));
    }

    @Transactional
    public AdminPlace create(PlaceRequest r) {
        if (places.countByDeletedAtIsNull() >= MAX_PLACES) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_PLACE_LIMIT", "Kampüs yeri sınırına ulaşıldı.",
                    String.valueOf(MAX_PLACES));
        }
        CampusPlace p = new CampusPlace();
        CampusConfig cfg = service.config();
        apply(p, r, cfg);
        p.setActive(r.active() == null || r.active());
        p = places.saveAndFlush(p);
        bump(cfg);
        AuditContext.target("CAMPUS_PLACE", p.getId()).summary("kampüs yeri eklendi: " + p.getName());
        return view(p, null, null);
    }

    @Transactional
    public AdminPlace update(Long id, PlaceRequest r) {
        CampusPlace p = load(id);
        CampusConfig cfg = service.config();
        apply(p, r, cfg);
        if (r.active() != null) {
            p.setActive(r.active());
        }
        p.setUpdatedAt(Instant.now());
        p = places.saveAndFlush(p);
        bump(cfg);
        AuditContext.target("CAMPUS_PLACE", p.getId()).summary("kampüs yeri düzenlendi: " + p.getName());
        return view(p, CampusService.unitCode(p, service.unitHosts()), null);
    }

    /** Yumusak silme: kayit korunur (osm_ref tohumu yeniden eklemez), hicbir uctan gorunmez. Gerekce denetim kaydindadir. */
    @Transactional
    public DeleteResult delete(Long id) {
        CampusPlace p = load(id);
        p.setActive(false);
        p.setDeletedAt(Instant.now());
        p.setUpdatedAt(Instant.now());
        places.saveAndFlush(p);
        bump(service.config());
        AuditContext.target("CAMPUS_PLACE", p.getId()).summary("kampüs yeri silindi: " + p.getName());
        return new DeleteResult(p.getId(), true);
    }

    /** Fotograf: dogrulama + yeniden kodlama + EXIF temizligi mevcut medya hattinda (ImageKind.COVER). */
    @Transactional
    public AdminPlace setPhoto(Long id, MultipartFile file) {
        CampusPlace p = load(id);
        String url = media.storeImage(file, ImageKind.COVER).url();
        String old = p.getPhotoKey();
        p.setPhotoKey(url);
        p.setUpdatedAt(Instant.now());
        places.saveAndFlush(p);
        bump(service.config());
        if (old != null && !old.equals(url)) {
            media.release(old);
        }
        AuditContext.target("CAMPUS_PLACE", p.getId()).summary("fotoğraf değiştirildi: " + p.getName());
        return view(p, null, null);
    }

    @Transactional
    public AdminPlace removePhoto(Long id) {
        CampusPlace p = load(id);
        String old = p.getPhotoKey();
        if (old != null) {
            p.setPhotoKey(null);
            p.setUpdatedAt(Instant.now());
            places.saveAndFlush(p);
            bump(service.config());
            media.release(old);
        }
        AuditContext.target("CAMPUS_PLACE", p.getId())
                .summary(old == null ? "fotoğraf zaten yok" : "fotoğraf kaldırıldı: " + p.getName());
        return view(p, null, null);
    }

    // ---------------- ayar ----------------

    /** Yonetici ayar gorunumu: kullanici /map ile ayni sekil, etiketler Turkce. */
    @Transactional(readOnly = true)
    public MapConfig config() {
        return service.map(Lang.TR);
    }

    @Transactional
    public MapConfig updateConfig(ConfigRequest r) {
        CampusConfig c = service.config();
        double clat = coord(r.center().lat(), 90);
        double clng = coord(r.center().lng(), 180);
        int zi = r.zoom().initial(), zmin = r.zoom().min(), zmax = r.zoom().max();
        if (zmin < 1 || zmax > 22 || zmin > zi || zi > zmax) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_ZOOM_INVALID",
                    "Yakınlaştırma sınırları geçersiz: 1 ≤ en az ≤ başlangıç ≤ en çok ≤ 22 olmalı.");
        }
        List<double[]> boundary = points(r.boundary(), MAX_BOUNDARY_POINTS, "CAMPUS_POLYGON_INVALID");
        double[] bb = bbox(boundary);
        double s;
        double w;
        double n;
        double e;
        BoundsRequest br = r.bounds();
        if (br == null) {
            double dLat = Math.max((bb[2] - bb[0]) * 0.15, 0.003);
            double dLng = Math.max((bb[3] - bb[1]) * 0.10, 0.003);
            s = Math.max(bb[0] - dLat, -90);
            n = Math.min(bb[2] + dLat, 90);
            w = Math.max(bb[1] - dLng, -180);
            e = Math.min(bb[3] + dLng, 180);
        } else {
            s = coord(br.south(), 90);
            n = coord(br.north(), 90);
            w = coord(br.west(), 180);
            e = coord(br.east(), 180);
        }
        if (s >= n || w >= e || n - s > MAX_BOUNDS_SPAN_DEG || e - w > MAX_BOUNDS_SPAN_DEG
                || bb[0] < s || bb[2] > n || bb[1] < w || bb[3] > e || !inside(clat, clng, s, w, n, e)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_BOUNDS_INVALID",
                    "Harita sınırları geçersiz: merkez ve kampüs poligonunu kapsamalı, en çok "
                            + (int) MAX_BOUNDS_SPAN_DEG + " derece olmalı.");
        }
        TilesRequest t = r.tiles();
        String url = t.urlTemplate().trim();
        validateTileUrl(url);
        String attribution = t.attribution().trim();
        if (attribution.isEmpty() || attribution.indexOf('<') >= 0 || attribution.indexOf('>') >= 0
                || hasControl(attribution)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_TILE_URL_INVALID",
                    "Karo atfı düz metin olmalı (HTML etiketi içeremez).");
        }
        int nativeZoom = t.maxNativeZoom();
        if (nativeZoom < 1 || nativeZoom > 22) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_ZOOM_INVALID",
                    "Yerel yakınlaştırma sınırı 1-22 arasında olmalı.");
        }
        String hint = t.userAgentHint() == null || t.userAgentHint().isBlank() ? CampusDefaults.USER_AGENT_HINT
                : t.userAgentHint().trim();
        if (hasControl(hint)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_TILE_URL_INVALID",
                    "Kullanıcı aracısı ipucu geçersiz karakter içeriyor.");
        }
        c.setCenterLat(clat);
        c.setCenterLng(clng);
        c.setZoomInitial((short) zi);
        c.setZoomMin((short) zmin);
        c.setZoomMax((short) zmax);
        c.setBoundSouth(s);
        c.setBoundWest(w);
        c.setBoundNorth(n);
        c.setBoundEast(e);
        c.setBoundaryJson(CampusJson.writePoints(boundary));
        c.setTileUrl(url);
        c.setTileAttribution(attribution);
        c.setTileMaxNativeZoom((short) nativeZoom);
        c.setUserAgentHint(hint);
        bump(c);
        AuditContext.target("CAMPUS_CONFIG", 1).summary("harita ayarı güncellendi: " + boundary.size()
                + " nokta, karo " + hostOf(url));
        return service.loadMap(Lang.TR);
    }

    // ---------------- yardimcilar ----------------

    private CampusPlace load(Long id) {
        return places.findByIdAndDeletedAtIsNull(id).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                "CAMPUS_PLACE_NOT_FOUND", "Kampüs yeri bulunamadı."));
    }

    private void bump(CampusConfig c) {
        c.setDataVersion(c.getDataVersion() + 1);
        c.setUpdatedAt(Instant.now());
        // varlik olayi (PostUpdate) onbellegi gecersiz kilar; sayac degisimi flush ile yazilir
        configs.saveAndFlush(c);
    }

    private void apply(CampusPlace p, PlaceRequest r, CampusConfig cfg) {
        CampusCategory cat = CampusCategory.parse(r.category());
        if (cat == null) {
            throw invalidCategory();
        }
        String name = clean(r.name());
        if (name.isEmpty() || name.length() > 120) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Ad 1-120 karakter olmalı.");
        }
        double lat = coord(r.lat(), 90);
        double lng = coord(r.lng(), 180);
        // ana yerleske disi birimler (remote) harita sinirlarinin disinda olabilir; yalniz aralik denetlenir
        boolean remote = r.remote() == null ? p.isRemote() : r.remote();
        if (!remote && !inside(lat, lng, cfg.getBoundSouth(), cfg.getBoundWest(), cfg.getBoundNorth(), cfg.getBoundEast())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_OUT_OF_BOUNDS",
                    "Konum harita sınırlarının dışında.");
        }
        String summary = r.summary() == null ? "" : clean(r.summary());
        if (summary.length() > 300) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Özet en çok 300 karakter olmalı.");
        }
        Set<String> units = new LinkedHashSet<>();
        if (r.units() != null) {
            for (String u : r.units()) {
                String cu = u == null ? "" : clean(u);
                if (!cu.isEmpty()) {
                    if (cu.length() > 80) {
                        throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                                "Birim adı en çok 80 karakter olmalı.");
                    }
                    units.add(cu);
                }
            }
        }
        if (units.size() > MAX_UNITS) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                    "En çok " + MAX_UNITS + " birim girilebilir.");
        }
        String footprintJson = null;
        if (r.footprint() != null && !r.footprint().isEmpty()) {
            List<double[]> fp = points(r.footprint(), MAX_FOOTPRINT_POINTS, "CAMPUS_POLYGON_INVALID");
            for (double[] pt : fp) {
                if (!remote && !inside(pt[0], pt[1], cfg.getBoundSouth(), cfg.getBoundWest(), cfg.getBoundNorth(),
                        cfg.getBoundEast())) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_OUT_OF_BOUNDS",
                            "Bina ana hattı harita sınırlarının dışında.");
                }
            }
            footprintJson = CampusJson.writePoints(fp);
        }
        List<String> unitList = new ArrayList<>(units);
        p.setName(name);
        p.setNameKey(CampusText.normalize(name));
        p.setCategory(cat.key());
        p.setLat(lat);
        p.setLng(lng);
        p.setSummary(summary.isEmpty() ? null : summary);
        p.setUnitsJson(CampusJson.write(unitList));
        p.setUnitsKey(clip(CampusText.unitsKey(unitList), 2000));
        p.setFootprintJson(footprintJson);
        p.setRemote(remote);
        p.setWebUrl(webUrl(r.webUrl()));
        p.setSortKey(r.sortKey() == null ? p.getSortKey() : Math.max(-100000, Math.min(100000, r.sortKey())));
    }

    private static String clip(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max);
    }

    /** Bosluk birlestirme + kontrol karakteri temizligi. */
    private static String clean(String s) {
        StringBuilder b = new StringBuilder(s.length());
        boolean space = false;
        for (int i = 0; i < s.length(); i++) {
            char ch = s.charAt(i);
            if (Character.isWhitespace(ch) || Character.isISOControl(ch)) {
                space = b.length() > 0;
            } else {
                if (space) {
                    b.append(' ');
                    space = false;
                }
                b.append(ch);
            }
        }
        return b.toString();
    }

    private static boolean hasControl(String s) {
        for (int i = 0; i < s.length(); i++) {
            if (Character.isISOControl(s.charAt(i))) {
                return true;
            }
        }
        return false;
    }

    private static double coord(Double v, double limit) {
        if (v == null || v.isNaN() || v.isInfinite() || Math.abs(v) > limit) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_COORD_INVALID",
                    "Koordinat geçersiz: enlem -90..90, boylam -180..180 olmalı.");
        }
        return v;
    }

    private static boolean inside(double lat, double lng, double s, double w, double n, double e) {
        return lat >= s && lat <= n && lng >= w && lng <= e;
    }

    /** {@code [[lat,lng],...]} -> noktalar; kapanis noktasi (ilk = son) atilir, en az 3 ayri nokta, alan sifir olamaz. */
    static List<double[]> points(List<List<Double>> raw, int max, String code) {
        if (raw == null || raw.size() > max + 1) {
            throw polygonInvalid(code, max);
        }
        List<double[]> out = new ArrayList<>(raw.size());
        for (List<Double> p : raw) {
            if (p == null || p.size() != 2) {
                throw polygonInvalid(code, max);
            }
            out.add(new double[] {coord(p.get(0), 90), coord(p.get(1), 180)});
        }
        if (out.size() > 1 && out.get(0)[0] == out.get(out.size() - 1)[0] && out.get(0)[1] == out.get(out.size() - 1)[1]) {
            out.remove(out.size() - 1);
        }
        if (out.size() < 3 || out.size() > max || Math.abs(area(out)) < 1e-12) {
            throw polygonInvalid(code, max);
        }
        return out;
    }

    private static ApiException polygonInvalid(String code, int max) {
        return new ApiException(HttpStatus.BAD_REQUEST, code,
                "Poligon geçersiz: en az 3 farklı nokta, en çok " + max + " nokta ve sıfırdan büyük alan gerekir.",
                String.valueOf(max));
    }

    /** Ayakkabi baglama alani (derece^2, ilk noktaya gore oteleme: yuvarlama hatasi kucuk); dogrusal poligonu elemek icin. */
    private static double area(List<double[]> pts) {
        double[] o = pts.get(0);
        double a = 0;
        for (int i = 0; i < pts.size(); i++) {
            double[] p = pts.get(i);
            double[] q = pts.get((i + 1) % pts.size());
            a += (p[1] - o[1]) * (q[0] - o[0]) - (q[1] - o[1]) * (p[0] - o[0]);
        }
        return a / 2;
    }

    /** [south, west, north, east]. */
    private static double[] bbox(List<double[]> pts) {
        double s = 90;
        double w = 180;
        double n = -90;
        double e = -180;
        for (double[] p : pts) {
            s = Math.min(s, p[0]);
            n = Math.max(n, p[0]);
            w = Math.min(w, p[1]);
            e = Math.max(e, p[1]);
        }
        return new double[] {s, w, n, e};
    }

    /** Yalniz https, konak adi var, kullanici bilgisi yok, yer tutucular {z}{x}{y} (+ {s}{r}); z, x, y zorunlu. */
    static void validateTileUrl(String url) {
        ApiException bad = new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_TILE_URL_INVALID",
                "Karo adresi geçersiz: https:// ile başlamalı ve {z}/{x}/{y} içermeli.");
        if (url.length() > 300 || !url.regionMatches(true, 0, "https://", 0, 8) || hasControl(url)
                || url.chars().anyMatch(Character::isWhitespace)) {
            throw bad;
        }
        boolean z = false;
        boolean x = false;
        boolean y = false;
        Matcher m = PLACEHOLDER.matcher(url);
        while (m.find()) {
            String k = m.group(1);
            if (!TILE_PLACEHOLDERS.contains(k)) {
                throw bad;
            }
            z |= k.equals("z");
            x |= k.equals("x");
            y |= k.equals("y");
        }
        // kalan suslu parantez (eslesmeyen)
        String stripped = PLACEHOLDER.matcher(url).replaceAll("0");
        if (!z || !x || !y || stripped.indexOf('{') >= 0 || stripped.indexOf('}') >= 0) {
            throw bad;
        }
        try {
            URI u = new URI(stripped);
            if (u.getHost() == null || u.getUserInfo() != null || !"https".equalsIgnoreCase(u.getScheme())) {
                throw bad;
            }
        } catch (java.net.URISyntaxException ex) {
            throw bad;
        }
    }

    private static String hostOf(String url) {
        try {
            String h = new URI(PLACEHOLDER.matcher(url).replaceAll("0")).getHost();
            return h == null ? "?" : h;
        } catch (java.net.URISyntaxException e) {
            return "?";
        }
    }

    /** Bos = null; aksi halde yalniz https, konak bingol.edu.tr ya da alt alani, kullanici bilgisi/bosluk yok, en cok 300. */
    static String webUrl(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String url = raw.trim();
        ApiException bad = new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_WEB_URL_INVALID",
                "Web adresi geçersiz: https:// ile başlamalı ve bingol.edu.tr alan adında olmalı.");
        if (url.length() > 300 || hasControl(url) || url.chars().anyMatch(Character::isWhitespace)) {
            throw bad;
        }
        try {
            URI u = new URI(url);
            String host = u.getHost() == null ? null : u.getHost().toLowerCase(java.util.Locale.ROOT);
            if (!"https".equalsIgnoreCase(u.getScheme()) || host == null || u.getUserInfo() != null
                    || !(host.equals("bingol.edu.tr") || host.endsWith(".bingol.edu.tr"))) {
                throw bad;
            }
        } catch (java.net.URISyntaxException e) {
            throw bad;
        }
        return url;
    }

    private static ApiException invalidCategory() {
        return new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_CATEGORY_INVALID", "Geçersiz kampüs kategorisi.");
    }

    static AdminPlace view(CampusPlace p, String unitSourceCode, List<String> departments) {
        List<double[]> fp = CampusJson.points(p.getFootprintJson());
        return new AdminPlace(p.getId(), p.getName(), p.getCategory(), p.getLat(), p.getLng(), p.getSummary(),
                p.getPhotoKey(), CampusJson.units(p.getUnitsJson()), fp.isEmpty() ? null : fp, p.getSortKey(),
                p.isActive(), p.getWebUrl(), p.isRemote(), unitSourceCode, departments, p.getSourceRef(),
                p.getCreatedAt(), p.getUpdatedAt());
    }
}
