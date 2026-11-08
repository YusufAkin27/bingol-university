package edu.bingol.backend.post.reels;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Keşfet "tanıdığın kişiler" öncelik ağırlıkları (`app.post.familiarity.*`). YALNIZ sıralamayı etkiler: aday havuzu
 * (görünürlük, engel, gizlilik, görülmüş kümesi) değişmez; herkes yine çıkar, tanıdıkları öne gelir.
 *
 * @param enabled false: yalnız eski "Senin İçin" sırası (acil kapatma)
 * @param mutualWeight yazar beni de takip ediyor (karşılıklı)
 * @param directMessageWeight yazarla birebir sohbetim var
 * @param sharedClubWeight ortak aktif kulüp (3 kulüpte doyar)
 * @param friendOfFriendWeight takip ettiklerimin takip ettiği (5 kişide doyar)
 * @param sameDepartmentWeight aynı bölüm
 * @param sameFacultyWeight aynı fakülte (bölüm eşleşmesinde ayrıca eklenmez)
 * @param maxBonus toplam tanışıklık bonusu üst sınırı (popülerliği tamamen ezmesin)
 */
@ConfigurationProperties("app.post.familiarity")
public record FamiliarityProperties(
        @DefaultValue("true") boolean enabled,
        @DefaultValue("0.6") double mutualWeight,
        @DefaultValue("1.0") double directMessageWeight,
        @DefaultValue("0.5") double sharedClubWeight,
        @DefaultValue("0.4") double friendOfFriendWeight,
        @DefaultValue("0.35") double sameDepartmentWeight,
        @DefaultValue("0.15") double sameFacultyWeight,
        @DefaultValue("2.0") double maxBonus) {
}
