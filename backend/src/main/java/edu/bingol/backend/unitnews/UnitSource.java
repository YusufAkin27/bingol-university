package edu.bingol.backend.unitnews;

import edu.bingol.backend.common.cache.CacheInvalidationListener;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Bir alt site (fakulte/enstitu/MYO/YDYO); durum alanlarini yalniz {@link UnitNewsSyncService} yazar. */
@Entity
@EntityListeners(CacheInvalidationListener.class)
@Table(name = "unit_source")
// Yalniz degisen sutunlar yazilir: yonetici ayari (enabled/facultyKeys) ile senkron durumu birbirini bayat degerle ezmesin
@org.hibernate.annotations.DynamicUpdate
@Getter
@Setter
public class UnitSource {

    public enum Kind { FACULTY, INSTITUTE, VOCATIONAL, LANGUAGE }

    @Id
    @Column(length = 20)
    private String code;

    @Column(nullable = false, length = 120)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Kind kind;

    @Column(nullable = false, length = 120)
    private String baseUrl;

    /** Enstitu: yalniz yuksek lisans/doktora (MASTER/PHD) kullanicilarina eklenir. */
    @Column(nullable = false)
    private boolean graduate;

    /** Virgullu AudienceKey degerleri: katalogdaki hangi fakulte adlarina hizmet eder. */
    @Column(nullable = false, length = 600)
    private String facultyKeys = "";

    @Column(nullable = false)
    private boolean enabled = true;

    private Instant departmentsCheckedAt;
    private Instant lastSuccessAt;
    private Instant lastAttemptAt;

    @Column(length = 300)
    private String lastMessage;

    @Column(nullable = false)
    private boolean maintenance;
}
