package edu.bingol.backend.media;

import java.util.Set;

/**
 * SPI: bir modul, kendi tablolarinda herkese acik gorsel URL'si tuttugunu bu arayuzle bildirir.
 * Yetim temizligi ve {@link MediaService#release} bir dosyayi YALNIZ hicbir kaynak "kullaniliyor" demiyorsa siler.
 * Basit durumda kod yazmak yerine `app.media.extra-reference-columns=tablo.sutun` yeterlidir.
 */
public interface MediaReferenceSource {

    /** @param url goreli URL, ornek /files/avatars/ab12.jpg (kucuk resim degil, ana dosya) */
    boolean isReferenced(String url);

    /**
     * Gece yetim taramasi icin TOPLU yol (FIX-P03, A02#10): kaynagin bildigi tum URL'ler tek seferde. Varsayilan
     * {@code null} = desteklemiyor, tarama dosya basina {@link #isReferenced} cagirir. Eksiksiz degilse (sorgu
     * hatasi vb.) {@code null} donun ya da istisna firlatin: tarama o zaman dosya basina denetime duser.
     */
    default Set<String> snapshot() {
        return null;
    }
}
