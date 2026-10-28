package edu.bingol.backend.post;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

/** Keşfet puan formülü ve yazar çeşitliliği (saf birim testleri). */
class PostRankTest {

    private static final PostRankProperties P = new PostRankProperties(1.0, 1.5, 0.6, 1.2, 60, 6, 2.0, 0.5, 5, 14, 2, 12, 30, 300000);

    private static double s(int likes, int comments, int followers, int likes24h, int reports, double ageH) {
        return PostRank.compute(P, likes, comments, followers, likes24h, reports, ageH);
    }

    @Test
    void morelikesRaiseScore() {
        assertTrue(s(10, 0, 0, 0, 0, 24) > s(1, 0, 0, 0, 0, 24));
        assertTrue(s(10, 0, 0, 0, 0, 24) > s(0, 0, 0, 0, 0, 24));
    }

    @Test
    void likesAreLogScaled() {
        double d1 = s(10, 0, 0, 0, 0, 12) - s(0, 0, 0, 0, 0, 12);
        double d2 = s(1000, 0, 0, 0, 0, 12) - s(990, 0, 0, 0, 0, 12);
        assertTrue(d1 > d2 * 10, "ayni +10 begeni dusuk tabanda cok daha degerli");
    }

    @Test
    void moreFollowersAndVelocityRaiseScore() {
        assertTrue(s(5, 0, 1000, 0, 0, 24) > s(5, 0, 0, 0, 0, 24));
        assertTrue(s(5, 0, 0, 5, 0, 24) > s(5, 0, 0, 0, 0, 24));
    }

    @Test
    void oldPostDecaysWithHalfLife() {
        double fresh = s(20, 0, 0, 0, 0, 24);
        double old = s(20, 0, 0, 0, 0, 24 + 60);
        assertEquals(fresh / 2, old, 1e-9, "yari omur 60 saat");
        assertTrue(s(20, 0, 0, 0, 0, 24 * 10) < fresh / 8);
    }

    @Test
    void newPostGetsColdStartBonusEvenWithoutLikes() {
        double brandNew = s(0, 0, 0, 0, 0, 0);
        assertEquals(2.0, brandNew, 1e-9);
        assertTrue(brandNew > s(0, 0, 0, 0, 0, 3));
        assertEquals(0.0, s(0, 0, 0, 0, 0, 6), 1e-9);
        assertTrue(s(0, 0, 0, 0, 0, 1) > s(1, 0, 0, 0, 0, 12), "taze begenisiz gonderi 12 sa'lik 1 begenilikten onde");
    }

    @Test
    void reportsPenalizeAndAreCapped() {
        double clean = s(10, 2, 50, 3, 0, 5);
        assertEquals(clean / 2, s(10, 2, 50, 3, 1, 5), 1e-9);
        assertEquals(clean / 32, s(10, 2, 50, 3, 5, 5), 1e-9);
        assertEquals(s(10, 2, 50, 3, 5, 5), s(10, 2, 50, 3, 99, 5), 1e-12);
    }

    @Test
    void negativeInputsAreSafe() {
        assertTrue(Double.isFinite(s(-5, -1, -3, -2, -1, -4)));
    }

    @Test
    void diversifyLimitsAuthorRunWithoutLosingItems() {
        // yazarlar: A A A A B C -> en cok 2 ardisik A
        List<Long> authors = List.of(1L, 1L, 1L, 1L, 2L, 3L);
        List<Long> out = PostRank.diversify(authors, x -> x, 2);
        assertEquals(6, out.size());
        assertEquals(authors.stream().sorted().toList(), out.stream().sorted().toList());
        for (int i = 2; i < out.size(); i++) {
            assertTrue(!(out.get(i).equals(out.get(i - 1)) && out.get(i).equals(out.get(i - 2))),
                    "3 ardisik ayni yazar olmamali: " + out);
        }
    }

    @Test
    void diversifyKeepsOrderWhenNothingToFix() {
        List<Long> a = List.of(1L, 2L, 1L, 3L, 1L);
        assertEquals(a, PostRank.diversify(a, x -> x, 2));
    }

    @Test
    void diversifyAllSameAuthorKeepsOrder() {
        List<Long> a = List.of(5L, 5L, 5L, 5L);
        assertEquals(a, PostRank.diversify(a, x -> x, 2));
    }
}
