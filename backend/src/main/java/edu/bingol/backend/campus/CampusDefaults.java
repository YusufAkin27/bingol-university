package edu.bingol.backend.campus;

/** Varsayilan harita ayari (V1200 ile ayni degerler); satir yoksa (Flyway'siz ortam) servis bununla olusturur. */
final class CampusDefaults {

    static final String TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
    static final String ATTRIBUTION = "© OpenStreetMap katkıda bulunanları";
    static final String USER_AGENT_HINT = "BUKampus/{version}";

    private CampusDefaults() {}

    static CampusConfig create() {
        CampusConfig c = new CampusConfig();
        c.setCenterLat(38.8855);
        c.setCenterLng(40.4985);
        c.setZoomInitial((short) 16);
        c.setZoomMin((short) 14);
        c.setZoomMax((short) 19);
        c.setBoundSouth(38.84);
        c.setBoundWest(40.44);
        c.setBoundNorth(38.93);
        c.setBoundEast(40.56);
        c.setBoundaryJson("[]");
        c.setTileUrl(TILE_URL);
        c.setTileAttribution(ATTRIBUTION);
        c.setTileMaxNativeZoom((short) 19);
        c.setUserAgentHint(USER_AGENT_HINT);
        return c;
    }
}
