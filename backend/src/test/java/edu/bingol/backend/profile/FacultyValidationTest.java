package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.common.ApiException;
import java.util.List;
import org.junit.jupiter.api.Test;

class FacultyValidationTest {

    private static final List<String> LIST = List.of("Mühendislik Fakültesi", "Fen Edebiyat Fakültesi");

    @Test
    void emptyListAcceptsAnyText() {
        assertEquals("Herhangi", ProfileService.validFaculty("Herhangi", List.of()));
    }

    @Test
    void valueMustBeInTheListWhenListIsDefined() {
        assertEquals("Mühendislik Fakültesi", ProfileService.validFaculty("Mühendislik Fakültesi", LIST));
        ApiException e = assertThrows(ApiException.class, () -> ProfileService.validFaculty("Uydurma Fakülte", LIST));
        assertEquals("INVALID_FACULTY", e.code());
        assertEquals(400, e.status().value());
    }

    @Test
    void clearingIsAlwaysAllowed() {
        assertNull(ProfileService.validFaculty(null, LIST));
    }
}
