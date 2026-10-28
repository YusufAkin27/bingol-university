package edu.bingol.backend.post;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Keşfet "top" puan ayarları (`app.post.rank.*`). Formül: bkz. {@link PostRank}.
 * Ağırlıklar log ölçekli terimlere uygulanır; yarı ömür saat cinsindendir.
 *
 * @param velocityWeight son 24 saatteki beğeni hızı (ivme) ağırlığı
 * @param halfLifeHours zaman sönümü yarı ömrü (60 sa = 2,5 gün)
 * @param coldStartHours yaşı bu saatin altındaki gönderiye doğrusal azalan taban bonus
 * @param reportPenalty açık şikâyet başına çarpan (en çok maxReportsCounted şikâyet sayılır)
 * @param windowDays puan yalnız bu kadar gün yaşındaki gönderiler için hesaplanır; eskiler 0 olur
 * @param maxAuthorRun bir sayfada ardışık aynı yazardan en çok bu kadar gönderi
 * @param recomputeMs toplu yeniden hesap aralığı
 */
@ConfigurationProperties("app.post.rank")
public record PostRankProperties(
        @DefaultValue("1.0") double likeWeight,
        @DefaultValue("1.5") double commentWeight,
        @DefaultValue("0.6") double followerWeight,
        @DefaultValue("1.2") double velocityWeight,
        @DefaultValue("60") double halfLifeHours,
        @DefaultValue("6") double coldStartHours,
        @DefaultValue("2.0") double coldStartBonus,
        @DefaultValue("0.5") double reportPenalty,
        @DefaultValue("5") int maxReportsCounted,
        @DefaultValue("14") int windowDays,
        @DefaultValue("2") int maxAuthorRun,
        @DefaultValue("12") int defaultPageSize,
        @DefaultValue("30") int maxPageSize,
        @DefaultValue("300000") long recomputeMs) {
}
