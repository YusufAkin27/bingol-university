package edu.bingol.backend.campus;

import edu.bingol.backend.common.cache.CacheInvalidationListener;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Tek satirlik (id = 1) harita ayari: merkez, zoom, sinirlar, kampus poligonu, karo adresi. Sema: V1200. */
@Entity
@EntityListeners(CacheInvalidationListener.class)
@Table(name = "campus_config")
@Getter
@Setter
public class CampusConfig {

    public static final short SINGLE_ID = 1;

    @Id
    private short id = SINGLE_ID;

    @Column(nullable = false)
    private double centerLat;

    @Column(nullable = false)
    private double centerLng;

    @Column(nullable = false)
    private short zoomInitial;

    @Column(nullable = false)
    private short zoomMin;

    @Column(nullable = false)
    private short zoomMax;

    @Column(name = "bound_south", nullable = false)
    private double boundSouth;

    @Column(name = "bound_west", nullable = false)
    private double boundWest;

    @Column(name = "bound_north", nullable = false)
    private double boundNorth;

    @Column(name = "bound_east", nullable = false)
    private double boundEast;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String boundaryJson = "[]";

    @Column(name = "tile_url", nullable = false, length = 300)
    private String tileUrl;

    @Column(nullable = false, length = 200)
    private String tileAttribution;

    @Column(nullable = false)
    private short tileMaxNativeZoom;

    @Column(nullable = false, length = 80)
    private String userAgentHint;

    /** Her yazmada (ayar ya da yer) artar; istemci surum karsilastirmasi icin. */
    @Column(nullable = false)
    private long dataVersion = 1;

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
