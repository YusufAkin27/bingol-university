package edu.bingol.backend.media;

/**
 * SPI: bir modul, kendi tablolarinda herkese acik gorsel URL'si tuttugunu bu arayuzle bildirir.
 * Yetim temizligi ve {@link MediaService#release} bir dosyayi YALNIZ hicbir kaynak "kullaniliyor" demiyorsa siler.
 * Basit durumda kod yazmak yerine `app.media.extra-reference-columns=tablo.sutun` yeterlidir.
 */
public interface MediaReferenceSource {

    /** @param url goreli URL, ornek /files/avatars/ab12.jpg (kucuk resim degil, ana dosya) */
    boolean isReferenced(String url);
}
