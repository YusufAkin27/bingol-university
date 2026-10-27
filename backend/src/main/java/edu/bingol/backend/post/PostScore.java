package edu.bingol.backend.post;

/** Popülerlik puanı: (beğeni*1 + yorum*2) / (yaşSaat+2)^1.2. */
public final class PostScore {

    private PostScore() {}

    public static double compute(int likes, int comments, double ageHours) {
        double raw = likes + comments * 2.0;
        return raw / Math.pow(Math.max(ageHours, 0) + 2.0, 1.2);
    }
}
