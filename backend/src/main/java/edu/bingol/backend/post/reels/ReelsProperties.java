package edu.bingol.backend.post.reels;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Reels öneri ve "Senin İçin" kişiselleştirme ağırlıkları (`app.post.reels.*`). Kural tabanlı puandır (ML yok):
 * <pre>
 * puan = fresh*0.5^(yaşSaat/freshHalfLifeHours) + (izlenmemişse unseenBonus) + interest*min(1, ln(1+yazarBeğenisi)/ln(4))
 *      + (takipEdilen ? followBonus : 0) + quality*gösterimPuanı/100 + random*jitter(seed,gönderi)
 *      - recentSeenPenalty*max(0, 1 - sonİzlenmedenSaat/recentSeenHours) - repeatPenalty*ln(1+gösterim)
 *      - quickSkipPenalty*min(hızlıGeçme, 3)
 * </pre>
 *
 * @param poolSize puanlanan aday havuzu (rank_score sırasında ilk N görülmemiş video)
 * @param defaultPageSize Reels sayfa boyutu varsayılanı
 * @param maxPageSize Reels sayfa boyutu üst sınırı
 * @param freshWeight yeni içerik bonus ağırlığı
 * @param freshHalfLifeHours yeni içerik bonusunun yarı ömrü (saat)
 * @param unseenBonus bu kullanıcının hiç görmediği video bonusu
 * @param interestWeight yazarın gönderilerini daha önce beğenmiş olma ilgisi
 * @param followBonus takip edilen yazar bonusu (ölçülü)
 * @param qualityWeight kalite/etkileşim (gönderi gösterim puanı 0..100) ağırlığı
 * @param randomWeight kontrollü rastgele keşif ağırlığı (oturum tohumuyla deterministik)
 * @param recentSeenPenalty yakın zamanda izlenmiş videonun cezası
 * @param recentSeenHours son izlenme cezasının sönme süresi
 * @param repeatPenalty tekrar gösterim (gösterim sayısı) cezası
 * @param quickSkipPenalty hızlı geçilme cezası
 * @param quickSkipMs bu süreden kısa izleme hızlı geçme sayılır
 * @param quickSkipPct bu yüzdenin altındaki tamamlanma hızlı geçme sayılır (süre >= 5 sn videolarda)
 * @param resurfaceAfterDays bu günden eski izleme kaydı videoyu "izlenmemiş" yerine tekrar aday yapar
 * @param retentionDays izleme geçmişi saklama (gün)
 * @param sessionTtlHours oturum içi gösterilenler kümesinin (Redis) ömrü
 * @param maxAuthorRun sayfa içinde ardışık aynı yazardan en çok bu kadar
 * @param forYouPoolSize "Senin İçin" kişiselleştirme aday havuzu
 * @param forYouRankWeight "Senin İçin" ortak popülerlik puanı ağırlığı
 * @param forYouFollowBonus "Senin İçin" takip önceliği
 * @param forYouInterestWeight "Senin İçin" yazar ilgisi
 * @param forYouRandomWeight "Senin İçin" kontrollü rastgelelik
 */
@ConfigurationProperties("app.post.reels")
public record ReelsProperties(
        @DefaultValue("200") int poolSize,
        @DefaultValue("8") int defaultPageSize,
        @DefaultValue("20") int maxPageSize,
        @DefaultValue("2.0") double freshWeight,
        @DefaultValue("72") double freshHalfLifeHours,
        @DefaultValue("1.5") double unseenBonus,
        @DefaultValue("1.0") double interestWeight,
        @DefaultValue("1.2") double followBonus,
        @DefaultValue("2.0") double qualityWeight,
        @DefaultValue("1.0") double randomWeight,
        @DefaultValue("2.5") double recentSeenPenalty,
        @DefaultValue("24") double recentSeenHours,
        @DefaultValue("0.8") double repeatPenalty,
        @DefaultValue("1.0") double quickSkipPenalty,
        @DefaultValue("1500") long quickSkipMs,
        @DefaultValue("15") int quickSkipPct,
        @DefaultValue("14") int resurfaceAfterDays,
        @DefaultValue("45") int retentionDays,
        @DefaultValue("6") int sessionTtlHours,
        @DefaultValue("1") int maxAuthorRun,
        @DefaultValue("150") int forYouPoolSize,
        @DefaultValue("2.0") double forYouRankWeight,
        @DefaultValue("1.5") double forYouFollowBonus,
        @DefaultValue("0.8") double forYouInterestWeight,
        @DefaultValue("0.6") double forYouRandomWeight) {
}
