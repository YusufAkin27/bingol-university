package edu.bingol.backend.unitnews;

import java.util.Collection;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UnitAnnouncementRepository extends JpaRepository<UnitAnnouncement, Long> {

    boolean existsByUrl(String url);

    /** Verilen adreslerden zaten kayitli olanlar (tek sorguda yenileri ayirmak icin). */
    java.util.List<UnitAnnouncement> findByUrlIn(Collection<String> urls);

    long countBySourceCode(String sourceCode);
}
