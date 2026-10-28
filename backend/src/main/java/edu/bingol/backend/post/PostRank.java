package edu.bingol.backend.post;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;

/**
 * Keşfet "top" puanı (saf fonksiyon; test edilebilir).
 *
 * <pre>
 * engagement = wL*ln(1+beğeni) + wC*ln(1+yorum) + wF*ln(1+yazarTakipçi) + wV*ln(1+son24saatBeğeni)
 * sönüm      = 0.5 ^ (yaşSaat / yarıÖmürSaat)
 * soğuk      = yaş &lt; coldStartHours ? bonus * (1 - yaş/coldStartHours) : 0
 * puan       = (engagement * sönüm + soğuk) * reportPenalty ^ min(açıkŞikâyet, max)
 * </pre>
 */
public final class PostRank {

    private PostRank() {}

    public static double compute(PostRankProperties p, int likes, int comments, int followers, int likes24h,
                                 int openReports, double ageHours) {
        double age = Math.max(ageHours, 0);
        double engagement = p.likeWeight() * ln(likes) + p.commentWeight() * ln(comments)
                + p.followerWeight() * ln(followers) + p.velocityWeight() * ln(likes24h);
        double decay = Math.pow(0.5, age / Math.max(p.halfLifeHours(), 0.01));
        double cold = age < p.coldStartHours() ? p.coldStartBonus() * (1 - age / p.coldStartHours()) : 0;
        double penalty = Math.pow(p.reportPenalty(), Math.min(Math.max(openReports, 0), p.maxReportsCounted()));
        return (engagement * decay + cold) * penalty;
    }

    private static double ln(int v) {
        return Math.log1p(Math.max(v, 0));
    }

    /**
     * Yazar çeşitliliği: sayfa İÇİNDE ardışık aynı yazardan en çok {@code maxRun} gönderi olacak şekilde
     * yeniden dizer (kayıpsız: öğeler atılmaz, yalnız sıra değişir; imleç veritabanı sırasındaki son kayıttan kurulur).
     * Hepsi aynı yazarsa sıra korunur.
     */
    public static <T> List<T> diversify(List<T> items, Function<T, Long> authorOf, int maxRun) {
        if (maxRun < 1 || items.size() <= maxRun) {
            return items;
        }
        List<T> rest = new ArrayList<>(items);
        List<T> out = new ArrayList<>(items.size());
        while (!rest.isEmpty()) {
            int pick = 0;
            for (int i = 0; i < rest.size(); i++) {
                if (!wouldExceed(out, authorOf, authorOf.apply(rest.get(i)), maxRun)) {
                    pick = i;
                    break;
                }
            }
            out.add(rest.remove(pick));
        }
        return out;
    }

    private static <T> boolean wouldExceed(List<T> out, Function<T, Long> authorOf, Long author, int maxRun) {
        if (out.size() < maxRun) {
            return false;
        }
        for (int k = 1; k <= maxRun; k++) {
            if (!authorOf.apply(out.get(out.size() - k)).equals(author)) {
                return false;
            }
        }
        return true;
    }
}
