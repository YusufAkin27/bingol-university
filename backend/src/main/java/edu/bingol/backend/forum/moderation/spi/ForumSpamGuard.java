package edu.bingol.backend.forum.moderation.spi;

/**
 * Forum tekrarli icerik (spam) koruması: AYNI kullanici, normalize edilmis BIREBIR AYNI gövdeyi pencere (varsayilan
 * 10 dk, {@code app.forum.spam-window-seconds}) icinde ikinci kez gonderirse 429 {@code FORUM_DUPLICATE_CONTENT}.
 *
 * <p>Kullanim (A konu, B yorum, C anket secenegi icin gerekmez): dogrulama ve {@code Idempotency-Key} tekrar oynatma
 * kontrolunden SONRA, kaydetmeden hemen ONCE {@link #assertNotDuplicate} cagrilir. Kayit basarisiz olursa
 * {@link #forget} ile isaret geri alinir (kullanici hatadan sonra ayni metni yeniden gonderebilsin).
 *
 * <p>Kisa metinler (normalize uzunluk &lt; 20) icin anahtar {@code contextId}'yi (yorumda konu id) da icerir: farkli
 * konulara "Katiliyorum" yazmak spam sayilmaz; uzun metinler baglamdan bagimsiz tekrar sayilir.
 */
public interface ForumSpamGuard {

    /** Olusturma turu etiketi (anahtar ayrimi). */
    String SCOPE_TOPIC = "topic";
    String SCOPE_COMMENT = "comment";

    /**
     * Tekrar ise 429 {@code FORUM_DUPLICATE_CONTENT} (ApiException) firlatir; degilse gövdeyi pencere boyunca isaretler.
     *
     * @param scope {@link #SCOPE_TOPIC} / {@link #SCOPE_COMMENT} (ya da baska sabit etiket)
     * @param contextId yorumda konu id'si, konuda null
     * @param body konuda "baslik + satir sonu + aciklama", yorumda yorum metni (ham ya da temizlenmis; normalize edilir)
     */
    void assertNotDuplicate(Long userId, String scope, Long contextId, String body);

    /** {@link #assertNotDuplicate} isaretini geri alir (kayit basarisiz oldu). Bilinmeyen isaret sessizce yok sayilir. */
    void forget(Long userId, String scope, Long contextId, String body);

    /** Baglamsiz kisayol (konu). */
    default void assertNotDuplicate(Long userId, String scope, String body) {
        assertNotDuplicate(userId, scope, null, body);
    }
}
