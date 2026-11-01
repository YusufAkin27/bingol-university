package edu.bingol.backend.legal;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface DocumentRepository extends JpaRepository<LegalDocument, Long> {

    /** Metinsiz baslik satiri: tam sozlesme metni (120-320 KB) gerekmeyen okumalar (bekleyen onay, surum listesi) icin. */
    interface DocHead {
        LegalType getType();

        String getLang();

        int getVersion();

        String getTitle();

        boolean isRequireReaccept();

        java.time.Instant getPublishedAt();
    }

    /** Aktif belgelerin basliklari, tek dilde (onay/surum takibi tr belge uzerinden). */
    @Query("SELECT d.type AS type, d.lang AS lang, d.version AS version, d.title AS title, "
            + "d.requireReaccept AS requireReaccept, d.publishedAt AS publishedAt "
            + "FROM LegalDocument d WHERE d.active = true AND d.lang = :lang")
    List<DocHead> activeHeads(@Param("lang") String lang);

    /** Bir turun tum surumlerinin basliklari (metinsiz), en yeni surum once. */
    @Query("SELECT d.type AS type, d.lang AS lang, d.version AS version, d.title AS title, "
            + "d.requireReaccept AS requireReaccept, d.publishedAt AS publishedAt "
            + "FROM LegalDocument d WHERE d.type = :type AND d.lang = :lang ORDER BY d.version DESC")
    List<DocHead> versionHeads(@Param("type") LegalType type, @Param("lang") String lang);

    Optional<LegalDocument> findByTypeAndLangAndActiveTrue(LegalType type, String lang);

    /** Yonetici: tum diller, en yeni surum once. */
    List<LegalDocument> findByTypeOrderByVersionDescLangAsc(LegalType type);

    @Query("SELECT COALESCE(MAX(d.version), 0) FROM LegalDocument d WHERE d.type = :type")
    int maxVersion(@Param("type") LegalType type);

    /**
     * Yeniden onay isteyen EN YENI surum (yoksa 0). Bilgilendirme niteligindeki (require_reaccept=false) sonraki
     * surumler, daha once yayimlanmis zorunlu onayi ortadan kaldirmaz.
     */
    @Query("SELECT COALESCE(MAX(d.version), 0) FROM LegalDocument d WHERE d.type = :type AND d.lang = 'tr' AND d.requireReaccept = true")
    int maxReacceptVersion(@Param("type") LegalType type);

    @Transactional
    @Modifying
    @Query("UPDATE LegalDocument d SET d.active = false WHERE d.type = :type AND d.active = true")
    int deactivate(@Param("type") LegalType type);
}
