package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.academician.AcNotice.Type;
import edu.bingol.backend.common.ApiException;
import java.time.Instant;
import org.junit.jupiter.api.Test;

/** Tur basina izinli/zorunlu alanlar tablosu. */
class NoticeRulesTest {

    private static final Instant T = Instant.parse("2030-01-01T10:00:00Z");

    private static void invalid(Type t, String title, String note, Instant at, int files) {
        ApiException e = assertThrows(ApiException.class, () -> NoticeRules.validate(t, title, note, at, files),
                t + " " + title + " " + note + " " + at + " " + files);
        assertEquals("AC_FIELD_INVALID", e.code());
    }

    @Test
    void fieldlessTypes() {
        for (Type t : new Type[] {Type.LESSON_STARTED, Type.ATTENDANCE_STARTED}) {
            var c = NoticeRules.validate(t, null, null, null, 0);
            assertNull(c.title());
            NoticeRules.validate(t, "  ", "", null, 0); // bos alan sorun degil
            invalid(t, "baslik", null, null, 0);
            invalid(t, null, "not", null, 0);
            invalid(t, null, null, T, 0);
            invalid(t, null, null, null, 1);
        }
    }

    @Test
    void examAndAssignmentNeedTitleAndDate() {
        for (Type t : new Type[] {Type.EXAM, Type.ASSIGNMENT}) {
            var c = NoticeRules.validate(t, " Vize ", null, T, 2);
            assertEquals("Vize", c.title());
            invalid(t, null, null, T, 0);
            invalid(t, "x", null, null, 0);
            invalid(t, "x".repeat(121), null, T, 0);
        }
        invalid(Type.EXAM, "x", "n".repeat(501), T, 0);
        NoticeRules.validate(Type.EXAM, "x", "n".repeat(500), T, 0);
        invalid(Type.ASSIGNMENT, "x", "n".repeat(1001), T, 0);
        NoticeRules.validate(Type.ASSIGNMENT, "x", "n".repeat(1000), T, 0);
    }

    @Test
    void materialHasTitleAndNoDate() {
        NoticeRules.validate(Type.MATERIAL, "Ders notu", "not", null, 3);
        invalid(Type.MATERIAL, null, null, null, 0);
        invalid(Type.MATERIAL, "x", null, T, 0);
    }

    @Test
    void lessonCancelledNeedsDateAndNoTitleOrFiles() {
        NoticeRules.validate(Type.LESSON_CANCELLED, null, "hasta", T, 0);
        invalid(Type.LESSON_CANCELLED, null, null, null, 0);
        invalid(Type.LESSON_CANCELLED, "baslik", null, T, 0);
        invalid(Type.LESSON_CANCELLED, null, "n".repeat(301), T, 0);
        invalid(Type.LESSON_CANCELLED, null, null, T, 1);
    }

    @Test
    void roomChangedNeedsRoomAndOptionalDate() {
        NoticeRules.validate(Type.ROOM_CHANGED, "B-204", null, null, 0);
        NoticeRules.validate(Type.ROOM_CHANGED, "B-204", "not", T, 0);
        invalid(Type.ROOM_CHANGED, null, null, null, 0);
        invalid(Type.ROOM_CHANGED, "r".repeat(101), null, null, 0);
        invalid(Type.ROOM_CHANGED, "B-204", null, null, 1);
    }

    @Test
    void filesAndUpcomingEligibility() {
        assertTrue(NoticeRules.allowsFiles(Type.EXAM));
        assertTrue(NoticeRules.allowsFiles(Type.ASSIGNMENT));
        assertTrue(NoticeRules.allowsFiles(Type.MATERIAL));
        assertFalse(NoticeRules.allowsFiles(Type.ROOM_CHANGED));
        assertFalse(NoticeRules.allowsFiles(Type.LESSON_CANCELLED));
        assertTrue(NoticeRules.upcomingEligible(Type.EXAM));
        assertTrue(NoticeRules.upcomingEligible(Type.LESSON_CANCELLED));
        assertTrue(NoticeRules.upcomingEligible(Type.ROOM_CHANGED));
        assertFalse(NoticeRules.upcomingEligible(Type.MATERIAL));
        assertFalse(NoticeRules.upcomingEligible(Type.LESSON_STARTED));
    }
}
