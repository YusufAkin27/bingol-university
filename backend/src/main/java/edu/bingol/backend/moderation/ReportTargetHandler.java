package edu.bingol.backend.moderation;

import java.util.Optional;

/**
 * Raporlanabilir bir icerik turunun moderasyon adaptoru. Mesajlasma, topluluk ve etkinlik modulleri kendi
 * turleri icin bunu bean olarak uygular; moderasyon servisi tum handler'lari otomatik toplar.
 *
 * <p>Zorunlu: {@link #type()}, {@link #exists}, {@link #ownerId}, {@link #hide}. Istege bagli yetenekler (varsayilanlar
 * mevcut handler'lari bozmaz):
 * <ul>
 *   <li>{@link #preview}: kuyrukta yoneticiye gosterilecek onizleme (gorsel/metin).</li>
 *   <li>{@link #reversible} + {@link #unhide}: gizleme geri alinabiliyorsa true yapin. Yalnizca geri alinabilir
 *       turler <b>otomatik gizlenir</b> (esik asilinca) ve <b>itiraza</b> acilir; geri alinamayanlar yalniz yonetici
 *       karariyla gizlenir.</li>
 * </ul>
 * hide/unhide idempotent olmalidir.
 */
public interface ReportTargetHandler {

    ReportTargetType type();

    boolean exists(Long targetId);

    /** Icerigin sahibi (uyari/askiya alma icin); bilinmiyorsa bos. */
    Optional<Long> ownerId(Long targetId);

    /** Icerigi gizle/kaldir (yumusak silme). Raporu "HIDE" ile cozunce veya esik asilinca cagrilir. */
    void hide(Long targetId);

    /** Yonetici kuyrugu icin onizleme; yoksa bos. Silinmis icerik icin bos donmelidir. */
    default Optional<MediaPreview> preview(Long targetId) {
        return Optional.empty();
    }

    /** {@link #hide} geri alinabiliyor mu (yumusak silme + {@link #unhide})? */
    default boolean reversible() {
        return false;
    }

    /** Gizlemeyi geri al. Yalnizca {@link #reversible()} true ise cagrilir. */
    default void unhide(Long targetId) {
        throw new UnsupportedOperationException("unhide desteklenmiyor: " + type());
    }
}
