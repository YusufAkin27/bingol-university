package edu.bingol.backend.post.reels;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** Reels / Senin İçin kural tabanlı puan (saf birim testleri). */
class ReelsRankerTest {

    private static final ReelsProperties P = new ReelsProperties(200, 8, 20, 2.0, 72, 1.5, 1.0, 1.2, 2.0, 1.0, 2.5, 24,
            0.8, 1.0, 1500, 15, 14, 45, 6, 1, 150, 2.0, 1.5, 0.8, 0.6);

    private static ReelsRanker.Features base() {
        return new ReelsRanker.Features(10, 30, false, 0, false, Double.MAX_VALUE, 0, 0, 0.5);
    }

    private static ReelsRanker.Features with(double age, int disp, boolean followed, int likes, boolean seen,
                                             double hours, int imp, int skips) {
        return new ReelsRanker.Features(age, disp, followed, likes, seen, hours, imp, skips, 0.5);
    }

    @Test
    void positiveSignalsRaiseAndNegativeSignalsLowerTheScore() {
        double b = ReelsRanker.score(P, base());
        assertTrue(ReelsRanker.score(P, with(1, 30, false, 0, false, Double.MAX_VALUE, 0, 0)) > b, "yeni icerik");
        assertTrue(ReelsRanker.score(P, with(200, 30, false, 0, false, Double.MAX_VALUE, 0, 0)) < b, "eski icerik");
        assertTrue(ReelsRanker.score(P, with(10, 80, false, 0, false, Double.MAX_VALUE, 0, 0)) > b, "kalite");
        assertTrue(ReelsRanker.score(P, with(10, 30, true, 0, false, Double.MAX_VALUE, 0, 0)) > b, "takip");
        assertTrue(ReelsRanker.score(P, with(10, 30, false, 5, false, Double.MAX_VALUE, 0, 0)) > b, "yazar ilgisi");
        // izlenmis: izlenmemis bonusu gider + son izlenme + tekrar cezalari
        double seenNow = ReelsRanker.score(P, with(10, 30, false, 0, true, 0.0, 1, 0));
        double seenLong = ReelsRanker.score(P, with(10, 30, false, 0, true, 500, 1, 0));
        assertTrue(seenNow < seenLong && seenLong < b, "son izlenme cezasi zamanla soner");
        assertTrue(ReelsRanker.score(P, with(10, 30, false, 0, true, 500, 5, 0))
                < ReelsRanker.score(P, with(10, 30, false, 0, true, 500, 1, 0)), "tekrar gosterim cezasi");
        assertTrue(ReelsRanker.score(P, with(10, 30, false, 0, true, 500, 1, 2))
                < ReelsRanker.score(P, with(10, 30, false, 0, true, 500, 1, 0)), "hizli gecme cezasi");
        // hizli gecme cezasi 3'te doyar
        assertEquals(ReelsRanker.score(P, with(10, 30, false, 0, true, 500, 1, 3)),
                ReelsRanker.score(P, with(10, 30, false, 0, true, 500, 1, 9)), 1e-12);
    }

    @Test
    void jitterIsDeterministicBoundedAndVariesWithSeed() {
        assertEquals(ReelsRanker.jitter(42, 7), ReelsRanker.jitter(42, 7), 0.0);
        boolean differs = false;
        for (long s = 0; s < 50; s++) {
            double j = ReelsRanker.jitter(s, 99);
            assertTrue(j >= 0 && j < 1);
            differs |= j != ReelsRanker.jitter(s + 1, 99);
        }
        assertTrue(differs);
        assertTrue(ReelsRanker.jitter(1, 1) != ReelsRanker.jitter(1, 2));
    }

    @Test
    void forYouCombinesSharedRankFollowInterestAndRandomness() {
        double base = ReelsRanker.forYou(P, 2.0, false, 0, 0.5);
        assertTrue(ReelsRanker.forYou(P, 8.0, false, 0, 0.5) > base, "populerlik");
        assertTrue(ReelsRanker.forYou(P, 2.0, true, 0, 0.5) > base, "takip");
        assertTrue(ReelsRanker.forYou(P, 2.0, false, 4, 0.5) > base, "yazar ilgisi");
        assertTrue(ReelsRanker.forYou(P, 2.0, true, 0, 0.0) > ReelsRanker.forYou(P, 2.0, false, 0, 1.0),
                "takip bonusu rastgeleligi yener");
        assertTrue(ReelsRanker.forYou(P, -5, false, 0, 0) >= 0, "negatif rank kenetlenir");
    }
}
