package edu.bingol.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.storage.*` kapasite ayarlari (depolama doluluk izleme). {@link StorageProperties} ile ayni onek, ayri kayit
 * (o kaydin kurucusu testlerde yaygin kullanildigi icin degistirilmez).
 *
 * <p>Veritabani sunucusunun diski uygulama konteynerinden gorulmeyebilir. Iki yol: {@code dbDiskPath} (DB verisiyle
 * AYNI dosya sistemindeki, uygulamadan okunabilir bir dizin; yuzde OLCULUR) ya da {@code dbDiskCapacityBytes} (VPS
 * disk boyutu; kullanim = DB + yukleme + yedek + {@code reservedBytes} toplamindan HESAPLANIR). Ikisi de yoksa
 * veritabani diski "bilinmiyor" gorunur.
 */
@ConfigurationProperties("app.storage")
public record StorageCapacityProperties(
        @DefaultValue("0") long dbDiskCapacityBytes,
        @DefaultValue("") String dbDiskPath,
        /** Hesaplanan modda isletim sistemi/imajlar/gunlukler icin sabit pay (bayt). */
        @DefaultValue("0") long reservedBytes) {
}
