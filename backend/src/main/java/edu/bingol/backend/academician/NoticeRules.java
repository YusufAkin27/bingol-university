package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcNotice.Type;
import java.time.Instant;
import java.util.EnumMap;
import java.util.Map;

/**
 * Duyuru turu basina izinli/zorunlu alanlar TEK yerde (okunabilir tablo, birim testli). Kural disi dolu alan 400
 * AC_FIELD_INVALID verir (sessizce yutulmaz); zorunlu alan eksikse yine ayni kod.
 */
final class NoticeRules {

    /** titleMax/noteMax 0 = alan YASAK. event: NONE yasak, OPTIONAL, REQUIRED. */
    enum Event { NONE, OPTIONAL, REQUIRED }

    record Spec(int titleMax, boolean titleRequired, Event event, int noteMax, boolean files) {}

    record Clean(String title, String note, Instant eventAt) {}

    private static final Map<Type, Spec> SPECS = new EnumMap<>(Type.class);

    static {
        SPECS.put(Type.LESSON_STARTED, new Spec(0, false, Event.NONE, 0, false));
        SPECS.put(Type.ATTENDANCE_STARTED, new Spec(0, false, Event.NONE, 0, false));
        SPECS.put(Type.EXAM, new Spec(120, true, Event.REQUIRED, 500, true));
        SPECS.put(Type.ASSIGNMENT, new Spec(120, true, Event.REQUIRED, 1000, true));
        SPECS.put(Type.MATERIAL, new Spec(120, true, Event.NONE, 1000, true));
        SPECS.put(Type.LESSON_CANCELLED, new Spec(0, false, Event.REQUIRED, 300, false));
        SPECS.put(Type.ROOM_CHANGED, new Spec(100, true, Event.OPTIONAL, 300, false));
    }

    private NoticeRules() {}

    static Spec spec(Type t) {
        return SPECS.get(t);
    }

    /** Dosya baglanabilir mi. */
    static boolean allowsFiles(Type t) {
        return SPECS.get(t).files();
    }

    /** Yaklasan listesine girer mi (eventAt gelecekte oldugunda). */
    static boolean upcomingEligible(Type t) {
        return SPECS.get(t).event() != Event.NONE;
    }

    static Clean validate(Type type, String title, String note, Instant eventAt, int fileCount) {
        Spec s = SPECS.get(type);
        String t = field(title, "title", s.titleMax(), s.titleRequired());
        String n = field(note, "note", s.noteMax(), false);
        if (s.event() == Event.NONE && eventAt != null) {
            throw AcErrors.invalid("eventAt");
        }
        if (s.event() == Event.REQUIRED && eventAt == null) {
            throw AcErrors.invalid("eventAt");
        }
        if (fileCount > 0 && !s.files()) {
            throw AcErrors.invalid("fileIds");
        }
        return new Clean(t, n, eventAt);
    }

    private static String field(String raw, String name, int max, boolean required) {
        boolean blank = raw == null || raw.isBlank();
        if (max == 0) {
            if (!blank) {
                throw AcErrors.invalid(name);
            }
            return null;
        }
        return AcademicianService.clean(raw, name, max, required);
    }
}
