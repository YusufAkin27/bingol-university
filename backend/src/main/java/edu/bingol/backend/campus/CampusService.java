package edu.bingol.backend.campus;

import edu.bingol.backend.campus.CampusDtos.Bounds;
import edu.bingol.backend.campus.CampusDtos.CategoryView;
import edu.bingol.backend.campus.CampusDtos.Coord;
import edu.bingol.backend.campus.CampusDtos.MapConfig;
import edu.bingol.backend.campus.CampusDtos.PlaceList;
import edu.bingol.backend.campus.CampusDtos.PlaceView;
import edu.bingol.backend.campus.CampusDtos.Tiles;
import edu.bingol.backend.campus.CampusDtos.Zoom;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.unitnews.UnitDepartment;
import edu.bingol.backend.unitnews.UnitDepartmentRepository;
import edu.bingol.backend.unitnews.UnitSource;
import edu.bingol.backend.unitnews.UnitSourceRepository;
import java.net.URI;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;

/**
 * Kampus haritasi okuma servisi (kullanici). Cevaplar "herkese ayni" oldugundan sunucu onbellegine girer
 * (`campus` ad alani; {@link CampusPlace}/{@link CampusConfig} varlik olaylari gecersiz kilar). Arama (`q`) onbelleklenmez
 * (serbest girdi anahtar patlatir); kategori ve limit beyaz listeli/sinirlidir. Yalniz campus_place kayitlari doner.
 */
@Service
public class CampusService {

    public static final int DEFAULT_LIMIT = 100;
    public static final int MAX_LIMIT = 200;
    static final int MAX_QUERY_CHARS = 60;
    static final String NS = "campus";

    private static final TypeReference<MapConfig> MAP_T = new TypeReference<>() { };
    private static final TypeReference<PlaceList> LIST_T = new TypeReference<>() { };

    private final CampusPlaceRepository places;
    private final CampusConfigRepository configs;
    private final I18n i18n;
    private final UnitSourceRepository unitSources;
    private final UnitDepartmentRepository unitDepartments;
    private CacheService cache = CacheService.passthrough();

    /** Birim haber kaynagiyla (unit_source) eslesmesi yalniz akademik birim kategorilerinde aranir. */
    private static final Set<String> ACADEMIC = Set.of("faculty", "institute", "school", "vocational");
    /** Bir kaynagin en cok bu kadar bolum adi doner (kaynak basina onlarca; sinir guvenlik icin). */
    static final int MAX_DEPARTMENTS = 200;

    public CampusService(CampusPlaceRepository places, CampusConfigRepository configs, I18n i18n,
                         UnitSourceRepository unitSources, UnitDepartmentRepository unitDepartments) {
        this.places = places;
        this.configs = configs;
        this.i18n = i18n;
        this.unitSources = unitSources;
        this.unitDepartments = unitDepartments;
    }

    @Autowired(required = false)
    void setCache(CacheService cache) {
        this.cache = cache;
    }

    // ---- harita ayari ----

    @Transactional(propagation = Propagation.SUPPORTS, readOnly = true)
    public MapConfig map(Lang lang) {
        return cache.get(NS, "m:" + lang.code(), CacheTier.STABLE, MAP_T, () -> loadMap(lang));
    }

    /** Onbelleksiz yukleme (yonetici yazmasindan sonra anlik gorunum icin de kullanilir). */
    MapConfig loadMap(Lang lang) {
        CampusConfig c = config();
        List<CategoryView> cats = CampusCategory.ordered().stream()
                .map(k -> new CategoryView(k.key(), i18n.msg(k.labelKey(), lang), k.icon(), k.color())).toList();
        return new MapConfig(c.getDataVersion(), new Coord(c.getCenterLat(), c.getCenterLng()),
                new Zoom(c.getZoomInitial(), c.getZoomMin(), c.getZoomMax()),
                new Bounds(c.getBoundSouth(), c.getBoundWest(), c.getBoundNorth(), c.getBoundEast()),
                CampusJson.points(c.getBoundaryJson()),
                new Tiles(c.getTileUrl(), c.getTileAttribution(), c.getTileMaxNativeZoom(), c.getUserAgentHint()),
                cats);
    }

    /** Ayar satiri; yoksa (yerel/test: Flyway yok) varsayilanla olusturulur. */
    @Transactional
    public CampusConfig config() {
        return configs.findById(CampusConfig.SINGLE_ID).orElseGet(() -> configs.save(CampusDefaults.create()));
    }

    // ---- yerler ----

    /**
     * @param category bos/null = hepsi; bilinmeyen kategori 400 CAMPUS_CATEGORY_INVALID
     * @param q        Turkce duyarsiz ad/birim aramasi (onek + icerik); bos = sorgusuz liste
     */
    @Transactional(propagation = Propagation.SUPPORTS, readOnly = true)
    public PlaceList places(String category, String q, Integer limit) {
        String cat = "";
        if (category != null && !category.isBlank()) {
            CampusCategory c = CampusCategory.parse(category);
            if (c == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "CAMPUS_CATEGORY_INVALID", "Geçersiz kampüs kategorisi.");
            }
            cat = c.key();
        }
        int lim = limit == null ? DEFAULT_LIMIT : Math.min(Math.max(limit, 1), MAX_LIMIT);
        String nq = CampusText.normalize(q == null ? "" : q);
        if (nq.length() > MAX_QUERY_CHARS) {
            nq = nq.substring(0, MAX_QUERY_CHARS).trim();
        }
        if (nq.isEmpty()) {
            String fcat = cat;
            return cache.get(NS, "p:" + (cat.isEmpty() ? "all" : cat) + ":" + lim, CacheTier.STABLE, LIST_T,
                    () -> query(fcat, "", lim));
        }
        return query(cat, nq, lim);
    }

    private PlaceList query(String category, String nq, int limit) {
        String esc = CampusText.escapeLike(nq);
        String contains = "%" + esc + "%";
        String prefix = nq.isEmpty() ? "%" : esc + "%";
        String wordPrefix = nq.isEmpty() ? "%" : "% " + esc + "%";
        Map<String, String> hosts = unitHosts();
        List<PlaceView> items = places.search(category, contains, prefix, wordPrefix, PageRequest.of(0, limit)).stream()
                .map(p -> view(p, unitCode(p, hosts), null)).toList();
        return new PlaceList(items);
    }

    @Transactional(readOnly = true)
    public PlaceView place(Long id) {
        CampusPlace p = places.findByIdAndActiveTrueAndDeletedAtIsNull(id).orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "CAMPUS_PLACE_NOT_FOUND", "Kampüs yeri bulunamadı."));
        String code = unitCode(p, unitHosts());
        return view(p, code, departments(code));
    }

    static PlaceView view(CampusPlace p, String unitSourceCode, List<String> departments) {
        List<double[]> fp = CampusJson.points(p.getFootprintJson());
        return new PlaceView(p.getId(), p.getName(), p.getCategory(), p.getLat(), p.getLng(), p.getSummary(),
                p.getPhotoKey(), CampusJson.units(p.getUnitsJson()), fp.isEmpty() ? null : fp, p.getSortKey(),
                p.getWebUrl(), p.isRemote(), unitSourceCode, departments);
    }

    // ---- birim haber kaynagi (unitnews) eslesmesi: YALNIZ OKUMA, kaynak siteye istek yok ----

    /** unit_source taban adresinin konak adi (kucuk harf) -> kaynak kodu. Kucuk sabit tablo (23 kaynak). */
    Map<String, String> unitHosts() {
        Map<String, String> m = new HashMap<>();
        for (UnitSource s : unitSources.findAllByOrderByNameAsc()) {
            String h = hostOf(s.getBaseUrl());
            if (h != null) {
                m.put(h, s.getCode());
            }
        }
        return m;
    }

    /** Akademik birimin web adresi bir unit_source ile ayni konaktaysa kaynak kodu; yoksa null. */
    static String unitCode(CampusPlace p, Map<String, String> hosts) {
        if (p.getWebUrl() == null || !ACADEMIC.contains(p.getCategory())) {
            return null;
        }
        String h = hostOf(p.getWebUrl());
        return h == null ? null : hosts.get(h);
    }

    /** Eslesen kaynagin bolum adlari (ada gore); kod yoksa null. */
    List<String> departments(String sourceCode) {
        if (sourceCode == null) {
            return null;
        }
        return unitDepartments.findBySourceCodeOrderByNameAsc(sourceCode).stream().limit(MAX_DEPARTMENTS)
                .map(UnitDepartment::getName).toList();
    }

    static String hostOf(String url) {
        try {
            String h = url == null ? null : URI.create(url.trim()).getHost();
            return h == null ? null : h.toLowerCase(Locale.ROOT);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
