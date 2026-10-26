package edu.bingol.backend.profile.privacy;

import java.util.List;

/**
 * Hesap silmede (KVKK) kullanicinin tum profil gorsel referanslarinin temizlenmesi icin kanca.
 * T1 (medya/dosya silme API'si) kendi uygulamasini @Component olarak ekler; birden fazla uygulama olabilir.
 * Uygulamalar exception sizdirmamalidir; sizdirsa bile {@link AvatarCleanups} yutar (silme akisi bozulmaz).
 */
public interface AvatarCleanup {

    /** @param refs kullanicinin profil gorsellerinin URL/yol referanslari (su an yalnizca avatar) */
    void cleanup(Long userId, List<String> refs);
}
