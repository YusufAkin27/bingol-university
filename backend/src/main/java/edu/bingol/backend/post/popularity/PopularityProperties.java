package edu.bingol.backend.post.popularity;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Kullanıcı "Popülerlik puanı" ayarları (`app.post.popularity.*`). Her bileşen log ölçekli ve bir tavana göre
 * 0..1'e sıkıştırılır (tavan ve üstü = 1); puan = 100 x ağırlıklı ortalama.
 *
 * @param followerCap takipçi tavanı (bu kadar takipçi bileşeni 1'e çıkarır)
 * @param likeCap alınan toplam beğeni tavanı
 * @param postCap gönderi sayısı tavanı
 * @param followerWeight takipçi ağırlığı
 * @param likeWeight alınan beğeni ağırlığı
 * @param postWeight gönderi sayısı ağırlığı
 * @param recomputeMs toplu yeniden hesap aralığı (varsayılan 1 saat)
 * @param batchSize toplu hesapta kullanıcı parçası
 */
@ConfigurationProperties("app.post.popularity")
public record PopularityProperties(
        @DefaultValue("500") int followerCap,
        @DefaultValue("2000") int likeCap,
        @DefaultValue("60") int postCap,
        @DefaultValue("0.45") double followerWeight,
        @DefaultValue("0.40") double likeWeight,
        @DefaultValue("0.15") double postWeight,
        @DefaultValue("3600000") long recomputeMs,
        @DefaultValue("500") int batchSize) {
}
