package edu.bingol.backend.share;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Sohbetteki paylasim onizleme karti (okuma aninda, GORUNTULEYENE gore hesaplanir; veritabaninda tutulmaz).
 * `available=false`: icerik silinmis/gizlenmis ya da goruntuleyen goremiyor (gizli hesap, engel, ozel kulup); bu durumda
 * `title`, `subtitle`, `imageUrl`, `kind` gonderilmez (var/yok ayrimi sizdirilmaz). `url` her durumda herkese acik
 * paylasim baglantisidir (yalniz tur + kimlik; icerik sizdirmaz).
 *
 * @param kind NEWS icin HABER | DUYURU | ETKINLIK; POST/REEL icin PHOTO | VIDEO; EVENT icin gonderilmez
 * @param imageUrl kucuk resim: goreli `/api/posts/media/{id}?thumb=true` (oturumlu), `/files/...` ya da https bingol.edu.tr
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ShareCard(String type, Long id, boolean available, String title, String subtitle, String imageUrl,
                        String kind, String url) {

    /** Icerik yok / goruntulenemiyor: yalniz tur, kimlik ve baglanti. */
    public static ShareCard unavailable(ShareRef ref, String url) {
        return new ShareCard(ref.type().name(), ref.id(), false, null, null, null, null, url);
    }

    /** Sohbet listesi son mesaj onizlemesi: baslik/gorsel yok (notr), yalniz tur ve kullanilabilirlik. */
    public ShareCard neutral() {
        return new ShareCard(type, id, available, null, null, null, null, url);
    }
}
