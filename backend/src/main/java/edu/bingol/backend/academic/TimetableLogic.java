package edu.bingol.backend.academic;

import java.time.LocalTime;
import java.util.List;
import java.util.Set;

/** Ders programi saf kurallari (veritabanisiz, birim testlenir). */
public final class TimetableLogic {

    public static final Set<String> COLORS =
            Set.of("red", "orange", "amber", "green", "teal", "blue", "indigo", "purple", "pink", "gray");
    private static final List<String> PALETTE =
            List.of("blue", "green", "orange", "purple", "teal", "pink", "indigo", "amber", "red");

    private TimetableLogic() {}

    /** Bir oturum: hangi derse ait (etiket gostermek icin), gun ve aralik. */
    public record Entry(Long courseId, String label, int day, LocalTime start, LocalTime end) {}

    /** Ayni gun ve start1 < end2 && start2 < end1 (bitisik dersler cakismaz). */
    public static boolean overlaps(Entry a, Entry b) {
        return a.day() == b.day() && a.start().isBefore(b.end()) && b.start().isBefore(a.end());
    }

    /**
     * Gelen oturumlardan biri mevcutlarla ya da gelenler kendi aralarinda cakisiyorsa cakisan "diger" kaydi dondurur.
     * Cakisma yoksa null.
     */
    public static Entry firstConflict(List<Entry> existing, List<Entry> incoming) {
        for (int i = 0; i < incoming.size(); i++) {
            Entry in = incoming.get(i);
            for (Entry ex : existing) {
                if (overlaps(in, ex)) {
                    return ex;
                }
            }
            for (int j = i + 1; j < incoming.size(); j++) {
                if (overlaps(in, incoming.get(j))) {
                    return incoming.get(j);
                }
            }
        }
        return null;
    }

    public static String describe(Entry e) {
        return e.label() + " " + AcademicTime.fmtTime(e.start()) + "-" + AcademicTime.fmtTime(e.end());
    }

    public static boolean validDay(Integer d) {
        return d != null && d >= 1 && d <= 7;
    }

    /** Renk anahtari: bossa ada gore deterministik; gecersizse null. */
    public static String resolveColor(String color, String name) {
        if (color == null || color.isBlank()) {
            return PALETTE.get(Math.floorMod(name == null ? 0 : name.strip().toLowerCase(java.util.Locale.ROOT).hashCode(), PALETTE.size()));
        }
        String c = color.strip().toLowerCase(java.util.Locale.ROOT);
        return COLORS.contains(c) ? c : null;
    }
}
