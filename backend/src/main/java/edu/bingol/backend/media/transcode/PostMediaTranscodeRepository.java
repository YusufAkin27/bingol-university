package edu.bingol.backend.media.transcode;

import edu.bingol.backend.post.media.PostMedia;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

/**
 * Donusturme kuyrugu icin sorgular (post.media.PostMediaRepository'den ayri: o modulun deposuna dokunulmaz).
 * Her guncelleme tek ifadelik atomik UPDATE'tir; coklu ornekte ayni is iki kez alinamaz ({@link #claim}).
 */
public interface PostMediaTranscodeRepository extends JpaRepository<PostMedia, Long> {

    @Query("SELECT m.id FROM PostMedia m WHERE m.transcodeStatus = 'PENDING' AND m.kind = 'VIDEO' ORDER BY m.id")
    List<Long> pendingIds(Pageable page);

    /** Isi sahiplenir: PENDING -> PROCESSING. 1 donmezse baskasi aldi. */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE PostMedia m SET m.transcodeStatus = 'PROCESSING', m.transcodeAt = :now "
            + "WHERE m.id = :id AND m.transcodeStatus = 'PENDING'")
    int claim(@Param("id") Long id, @Param("now") Instant now);

    /** Cokmus isleyicinin biraktigi PROCESSING isleri kuyruga geri alir. */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE PostMedia m SET m.transcodeStatus = 'PENDING' "
            + "WHERE m.transcodeStatus = 'PROCESSING' AND m.transcodeAt < :before")
    int resetStale(@Param("before") Instant before);

    /** Donusturme sonucu: yeni dosya + meta; satir arada silindiyse 0 doner (cagiran yeni dosyayi siler). */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE PostMedia m SET m.storageKey = :key, m.wrappedDek = :dek, m.encrypted = TRUE, m.bytes = :bytes, "
            + "m.durationMs = :dur, m.width = :w, m.height = :h, m.sha256 = :sha, m.thumbKey = :thumb, "
            + "m.transcodeStatus = 'DONE', m.transcodeAt = :now "
            + "WHERE m.id = :id AND m.transcodeStatus = 'PROCESSING'")
    int complete(@Param("id") Long id, @Param("key") String storageKey, @Param("dek") String wrappedDek,
                 @Param("bytes") long bytes, @Param("dur") Integer durationMs, @Param("w") Integer width,
                 @Param("h") Integer height, @Param("sha") String sha256, @Param("thumb") String thumbKey,
                 @Param("now") Instant now);

    /** Hata: yeniden denenecekse PENDING, sinir asildiysa FAILED (orijinal sunulmaya devam eder). */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE PostMedia m SET m.transcodeAttempts = m.transcodeAttempts + 1, "
            + "m.transcodeStatus = CASE WHEN m.transcodeAttempts + 1 >= :max THEN 'FAILED' ELSE 'PENDING' END, "
            + "m.transcodeAt = :now WHERE m.id = :id AND m.transcodeStatus = 'PROCESSING'")
    int fail(@Param("id") Long id, @Param("max") int maxAttempts, @Param("now") Instant now);

    /** Sifrelenmemis eski videolar (gocmen isi); donusturme kuyrugundakilere dokunulmaz. */
    @Query("SELECT m.id FROM PostMedia m WHERE m.kind = 'VIDEO' AND m.encrypted = FALSE "
            + "AND (m.transcodeStatus IS NULL OR m.transcodeStatus IN ('DONE', 'FAILED')) ORDER BY m.id")
    List<Long> plainVideoIds(Pageable page);

    /** Yalnizca duz kayit guncellenir (arada donusturme/sifreleme yaptiysa 0). */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE PostMedia m SET m.storageKey = :key, m.wrappedDek = :dek, m.encrypted = TRUE, m.thumbKey = :thumb "
            + "WHERE m.id = :id AND m.encrypted = FALSE AND m.storageKey = :oldKey")
    int sealExisting(@Param("id") Long id, @Param("oldKey") String oldKey, @Param("key") String newKey,
                     @Param("dek") String wrappedDek, @Param("thumb") String thumbKey);

    /** DEK'i verilen ana anahtar kimligiyle ("k1:%") sarili videolar (yeniden sarma gocu). */
    @Query("SELECT m.id FROM PostMedia m WHERE m.kind = 'VIDEO' AND m.encrypted = TRUE AND m.wrappedDek LIKE :prefix "
            + "AND (m.transcodeStatus IS NULL OR m.transcodeStatus IN ('DONE', 'FAILED')) ORDER BY m.id")
    List<Long> sealedWithKey(@Param("prefix") String prefix, Pageable page);

    /** Yeniden sarma: yalniz hala eski DEK/anahtarla duran satir guncellenir. */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE PostMedia m SET m.storageKey = :key, m.wrappedDek = :dek, m.thumbKey = :thumb "
            + "WHERE m.id = :id AND m.encrypted = TRUE AND m.storageKey = :oldKey AND m.wrappedDek = :oldDek")
    int reseal(@Param("id") Long id, @Param("oldKey") String oldKey, @Param("oldDek") String oldDek,
               @Param("key") String newKey, @Param("dek") String newDek, @Param("thumb") String thumbKey);

    @Query("SELECT COUNT(m) FROM PostMedia m WHERE m.kind = 'VIDEO' AND m.encrypted = FALSE")
    long countPlainVideos();

    @Query("SELECT COUNT(m) FROM PostMedia m WHERE m.transcodeStatus = :st")
    long countByStatus(@Param("st") String status);
}
