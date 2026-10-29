package edu.bingol.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.rate-limit.*`: kimlik dogrulama uclarinin hiz siniri esikleri. Tasarim: kaba kuvvet korumasi HESAP/E-POSTA ve
 * CIHAZ bazlidir (sikidir); IP bazli sinirlar yalnizca "toplu / kampus NAT" tavanidir (binlerce ogrenci ayni genel
 * IP'den cikabilir), tek basina mesru kullaniciyi engellemez ama tek kaynaktan kitlesel kotuye kullanimi keser.
 *
 * @param loginIpMax            IP basina 15 dk icindeki TOPLAM giris denemesi tavani (NAT tavani)
 * @param loginIpFailMax        IP basina 15 dk icindeki BASARISIZ giris tavani (credential stuffing); kampus NAT'inda
 *                              ogrenci yazim hatalari bu sayaca girer, bu yuzden yuksektir
 * @param loginDeviceFailMax    cihaz (X-Device-Id ozeti) basina 15 dk icindeki basarisiz giris (farkli hesaplari deneyen cihaz)
 * @param loginPairFailMax      (e-posta, cihaz ya da cihaz yoksa IP) cifti basina basarisiz giris; hesap korumasi
 * @param loginEmailIpFailMax   (e-posta, IP) cifti basina basarisiz giris; cihaz kimligini degistirerek tek IP'den
 *                              hesap denemeyi sinirlar
 * @param loginEmailFailMax     e-posta basina (istemciden bagimsiz) basarisiz giris; dagitik kaba kuvvetin kesin tavani
 * @param refreshIpMax          IP basina 15 dk icindeki refresh tavani (NAT tavani)
 * @param refreshUserMax        kullanici basina 15 dk icindeki refresh (gecerli token sahibi)
 * @param refreshInvalidIpMax   IP basina 15 dk icindeki GECERSIZ/tuketilmis refresh denemesi
 * @param codeIpMax             IP basina saatlik kod postasi isteyen istek (register/resend/forgot; her biri ayri sayac)
 * @param codeDeviceMax         cihaz basina saatlik kod postasi isteyen istek (register+resend+forgot ortak)
 * @param verifyIpMax           IP basina 10 dk dogrulama (verify-email, verify-reset-code) istegi
 * @param resetIpMax            IP basina 10 dk sifre sifirlama istegi
 * @param changePasswordIpMax   IP basina saatlik parola degistirme istegi (kullanici basina sinir 5/sa ayrica sabit)
 */
@ConfigurationProperties("app.rate-limit")
public record RateLimitProperties(@DefaultValue("5000") int loginIpMax,
                                  @DefaultValue("600") int loginIpFailMax,
                                  @DefaultValue("30") int loginDeviceFailMax,
                                  @DefaultValue("10") int loginPairFailMax,
                                  @DefaultValue("30") int loginEmailIpFailMax,
                                  @DefaultValue("60") int loginEmailFailMax,
                                  @DefaultValue("30000") int refreshIpMax,
                                  @DefaultValue("60") int refreshUserMax,
                                  @DefaultValue("600") int refreshInvalidIpMax,
                                  @DefaultValue("1000") int codeIpMax,
                                  @DefaultValue("10") int codeDeviceMax,
                                  @DefaultValue("3000") int verifyIpMax,
                                  @DefaultValue("3000") int resetIpMax,
                                  @DefaultValue("600") int changePasswordIpMax) {

    /** Birim testleri ve elle kurulum icin varsayilanlar. */
    public static RateLimitProperties defaults() {
        return new RateLimitProperties(5000, 600, 30, 10, 30, 60, 30000, 60, 600, 1000, 10, 3000, 3000, 600);
    }
}
