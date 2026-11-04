package edu.bingol.backend.post.reels;

/** Reels / "Senin İçin" kural tabanlı puanı (saf fonksiyonlar; test edilebilir). Ağırlıklar: {@link ReelsProperties}. */
public final class ReelsRanker {

    private ReelsRanker() {}

    /**
     * Bir aday video için girdiler. history* alanları izleme kaydı yoksa 0/büyük değerlerle verilir:
     * {@code seenBefore=false}, {@code hoursSinceSeen=Double.MAX_VALUE}.
     */
    public record Features(double ageHours, int displayScore, boolean followed, int authorLikes, boolean seenBefore,
                           double hoursSinceSeen, int impressions, int quickSkips, double jitter) {}

    public static double score(ReelsProperties p, Features f) {
        double fresh = p.freshWeight() * Math.pow(0.5, Math.max(f.ageHours(), 0) / Math.max(p.freshHalfLifeHours(), 0.01));
        double unseen = f.seenBefore() ? 0 : p.unseenBonus();
        double interest = p.interestWeight() * Math.min(1.0, Math.log1p(Math.max(f.authorLikes(), 0)) / Math.log(4));
        double follow = f.followed() ? p.followBonus() : 0;
        double quality = p.qualityWeight() * Math.max(0, Math.min(100, f.displayScore())) / 100.0;
        double random = p.randomWeight() * f.jitter();
        double recent = 0;
        if (f.seenBefore() && p.recentSeenHours() > 0) {
            recent = p.recentSeenPenalty() * Math.max(0, 1 - f.hoursSinceSeen() / p.recentSeenHours());
        }
        double repeat = p.repeatPenalty() * Math.log1p(Math.max(f.impressions(), 0));
        double skip = p.quickSkipPenalty() * Math.min(Math.max(f.quickSkips(), 0), 3);
        return fresh + unseen + interest + follow + quality + random - recent - repeat - skip;
    }

    /** "Senin İçin" puanı: ortak popülerlik puanı (rank_score doygun) + takip + ilgi + taze + rastgelelik. */
    public static double forYou(ReelsProperties p, double rankScore, boolean followed, int authorLikes, double jitter) {
        double rank = Math.max(rankScore, 0);
        double norm = rank / (rank + 3.0); // 0..1, doygun
        double interest = Math.min(1.0, Math.log1p(Math.max(authorLikes, 0)) / Math.log(4));
        return p.forYouRankWeight() * norm + (followed ? p.forYouFollowBonus() : 0)
                + p.forYouInterestWeight() * interest + p.forYouRandomWeight() * jitter;
    }

    /** (tohum, gönderi) için 0 <= x < 1 deterministik değer (splitmix64): aynı oturumda sıra kararlı, yenilemede değişir. */
    public static double jitter(long seed, long postId) {
        long z = seed + postId * 0x9E3779B97F4A7C15L;
        z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9L;
        z = (z ^ (z >>> 27)) * 0x94D049BB133111EBL;
        z = z ^ (z >>> 31);
        return (z >>> 11) * (1.0 / (1L << 53));
    }
}
