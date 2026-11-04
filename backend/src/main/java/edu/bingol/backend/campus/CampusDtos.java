package edu.bingol.backend.campus;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/** Kampus haritasi API sozlesmesi (docs/CAMPUS_MAP.md). Nokta dizileri {@code [lat, lng]} ciftleridir. */
public final class CampusDtos {

    private CampusDtos() {}

    // ---------------- kullanici ----------------

    public record Coord(double lat, double lng) {}

    public record Zoom(int initial, int min, int max) {}

    public record Bounds(double south, double west, double north, double east) {}

    public record Tiles(String urlTemplate, String attribution, int maxNativeZoom, String userAgentHint) {}

    public record CategoryView(String key, String label, String icon, String color) {}

    /** GET /api/campus/map. {@code version}: her yer/ayar yazmasinda artan tam sayi (istemci onbellegi icin). */
    public record MapConfig(long version, Coord center, Zoom zoom, Bounds bounds, List<double[]> boundary, Tiles tiles,
                            List<CategoryView> categories) {}

    /**
     * Kullanici yer ogesi. {@code remote}: ana yerleske disi birim (ana harita sinirlarinda gosterilmez, "diger
     * yerleskeler"). {@code webUrl}: resmi sayfa (https, bingol.edu.tr). {@code unitSourceCode}: web adresi birim haber
     * kaynagiyla (unit_source) eslesen akademik birimlerde kaynak kodu, yoksa null. {@code departments}: eslesen kaynagin
     * bolum adlari; YALNIZ yer detayinda dolu, liste ogesinde null.
     */
    public record PlaceView(Long id, String name, String category, double lat, double lng, String summary,
                            String photoUrl, List<String> units, List<double[]> footprint, int sortKey,
                            String webUrl, boolean remote, String unitSourceCode, List<String> departments) {}

    public record PlaceList(List<PlaceView> items) {}

    // ---------------- yonetici ----------------

    /** Yer olusturma/guncelleme govdesi (PUT tam degistirir; yalniz {@code active} bos ise mevcut korunur). */
    public record PlaceRequest(
            @NotBlank @Size(max = 120) String name,
            @NotBlank @Size(max = 20) String category,
            @NotNull Double lat,
            @NotNull Double lng,
            @Size(max = 300) String summary,
            @Size(max = 20) List<@NotBlank @Size(max = 80) String> units,
            @Size(max = 200) List<@Size(min = 2, max = 2) List<@NotNull Double>> footprint,
            Integer sortKey,
            Boolean active,
            @Size(max = 300) String webUrl,
            Boolean remote) {}

    public record AdminPlace(Long id, String name, String category, double lat, double lng, String summary,
                             String photoUrl, List<String> units, List<double[]> footprint, int sortKey,
                             boolean active, String webUrl, boolean remote, String unitSourceCode,
                             List<String> departments, String sourceRef, Instant createdAt, Instant updatedAt) {}

    public record AdminPlacePage(List<AdminPlace> items, int page, int size, long total) {}

    public record TilesRequest(
            @NotBlank @Size(max = 300) String urlTemplate,
            @NotBlank @Size(max = 200) String attribution,
            @NotNull Integer maxNativeZoom,
            @Size(max = 80) String userAgentHint) {}

    public record BoundsRequest(@NotNull Double south, @NotNull Double west, @NotNull Double north,
                                @NotNull Double east) {}

    public record ZoomRequest(@NotNull Integer initial, @NotNull Integer min, @NotNull Integer max) {}

    public record CoordRequest(@NotNull Double lat, @NotNull Double lng) {}

    /**
     * PUT /api/admin/campus/config: tam degistirme. {@code bounds} bos ise poligonun sinir kutusundan (kenar payli)
     * hesaplanir. {@code boundary}: en az 3, en cok 500 nokta {@code [lat, lng]}.
     */
    public record ConfigRequest(
            @NotNull @Valid CoordRequest center,
            @NotNull @Valid ZoomRequest zoom,
            @Valid BoundsRequest bounds,
            @NotNull @Size(min = 3, max = 500) List<@Size(min = 2, max = 2) List<@NotNull Double>> boundary,
            @NotNull @Valid TilesRequest tiles) {}

    public record DeleteResult(Long id, boolean deleted) {}
}
