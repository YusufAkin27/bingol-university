package edu.bingol.backend.post;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;

/**
 * Keşfet "top" puanı (saf fonksiyon; test edilebilir).
 *
 * <pre>
 * engagement = wL*ln(1+beğeni) + wC*ln(1+yorum) + wF*ln(1+yazarTakipçi) + wV*ln(1+son24saatBeğeni)
 *            + wW*ln(1+izlenme) + wT*ortTamamlanma*ln(1+izlenme)          (son iki terim yalnız video)
 * sönüm      = 0.5 ^ (yaşSaat / yarıÖmürSaat)
 * soğuk      = yaş &lt; coldStartHours ? bonus * (1 - yaş/coldStartHours) : 0
 * puan       = (engagement * sönüm + soğuk) * reportPenalty ^ min(açıkŞikâyet, max)
 * </pre>
 */
public final class PostRank {

    private PostRank() {}

    public static double compute(PostRankProperties p, int likes, int comments, int followers, int likes24h,
                                 int openReports, double ageHours) {
        return compute(p, likes, comments, followers, likes24h, 0, 0.0, openReports, ageHours);
    }

    /** Video terimli tam form: views = izlenme sayısı, avgCompletion = ortalama tamamlanma 0..1. */
    public static double compute(PostRankProperties p, int likes, int comments, int followers, int likes24h,
                                 int views, double avgCompletion, int openReports, double ageHours) {
        double age = Math.max(ageHours, 0);
        double engagement = p.likeWeight() * ln(likes) + p.commentWeight() * ln(comments)
                + p.followerWeight() * ln(followers) + p.velocityWeight() * ln(likes24h)
                + viewTerm(p, views, avgCompletion);
        double decay = Math.pow(0.5, age / Math.max(p.halfLifeHours(), 0.01));
        double cold = age < p.coldStartHours() ? p.coldStartBonus() * (1 - age / p.coldStartHours()) : 0;
        double penalty = Math.pow(p.reportPenalty(), Math.min(Math.max(openReports, 0), p.maxReportsCounted()));
        return (engagement * decay + cold) * penalty;
    }

    private static double viewTerm(PostRankProperties p, int views, double avgCompletion) {
        double lv = ln(views);
        return p.viewWeight() * lv + p.completionWeight() * Math.min(Math.max(avgCompletion, 0), 1) * lv;
    }

    /**
     * Gösterim puanı 0..100 (yaştan bağımsız, saf etkileşim): beğeni + yazar takipçisi + (video için) izlenme ve
     * tamamlanma. Doygun: 100 * (1 - e^(-etkileşim/ölçek)); hiç etkileşim yoksa 0.
     */
    public static int displayScore(PostRankProperties p, int likes, int followers, int views, double avgCompletion) {
        double e = p.likeWeight() * ln(likes) + p.followerWeight() * ln(followers) + viewTerm(p, views, avgCompletion);
        double scale = Math.max(p.popularityScale(), 0.01);
        return (int) Math.max(0, Math.min(100, Math.round(100.0 * (1 - Math.exp(-e / scale)))));
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
