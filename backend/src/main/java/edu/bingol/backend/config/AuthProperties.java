package edu.bingol.backend.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.auth.*` ayarlari.
 *
 * @param pendingRegistrationTtl dogrulanmamis (bekleyen) kaydin Redis'te kalma suresi; sure dolunca kayit silinir
 *                               ve kullanici yeniden kayit olur. Yenilenmez (sinirsiz uzamaz).
 * @param sessionMaxDays         mutlak oturum omru (gun): refresh rotasyonu oturumu bundan uzun tasiyamaz; sure
 *                               girisin (authTime) anindan sayilir, bitince yeniden giris gerekir.
 * @param refreshReuseWindow     tuketilmis refresh token'in "kullanildi" isaretinin kalma suresi: bu sure icinde
 *                               ayni token tekrar sunulursa calinma sayilir ve kullanicinin tum oturumlari kapanir.
 * @param refreshReuseGrace      agda kaybolan yanit icin tolerans: tuketimden bu kadar kisa sure sonra gelen ayni
 *                               token oturumlari iptal ETMEZ (yalniz 401); sonrasi calinma sayilir.
 */
@ConfigurationProperties("app.auth")
public record AuthProperties(@DefaultValue("72h") Duration pendingRegistrationTtl,
                             @DefaultValue("90") int sessionMaxDays,
                             @DefaultValue("6h") Duration refreshReuseWindow,
                             @DefaultValue("10s") Duration refreshReuseGrace) {
}
