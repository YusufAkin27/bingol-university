package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.common.ApiException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class LoginIdentifierTest {

    @Test
    void studentNumberBecomesEmail() {
        assertEquals("226051015@bingol.edu.tr", LoginIdentifier.normalize("226051015"));
        assertEquals("226051015@bingol.edu.tr", LoginIdentifier.normalize("  226 051-015. "));
    }

    @Test
    void emailsAreKeptAndLowercased() {
        assertEquals("ali.veli@bingol.edu.tr", LoginIdentifier.normalize("  Ali.Veli@Bingol.EDU.tr "));
        assertEquals("a@ogr.bingol.edu.tr", LoginIdentifier.normalize("a@ogr.bingol.edu.tr"));
        assertEquals("226051015@bingol.edu.tr", LoginIdentifier.normalize("226051015@BINGOL.edu.tr"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"12345", "1234567890123", "22605a015", "abc", "  ", "-", "12.34"})
    void invalidIdentifiersAreRejected(String raw) {
        ApiException e = assertThrows(ApiException.class, () -> LoginIdentifier.normalize(raw));
        assertEquals("VALIDATION_ERROR", e.code());
    }

    @Test
    void nullIsRejected() {
        assertThrows(ApiException.class, () -> LoginIdentifier.normalize(null));
    }

    @Test
    void plusAliasDetectionAndCanonicalKey() {
        org.junit.jupiter.api.Assertions.assertTrue(LoginIdentifier.hasPlusAlias("ali+2@bingol.edu.tr"));
        org.junit.jupiter.api.Assertions.assertFalse(LoginIdentifier.hasPlusAlias("ali@bingol.edu.tr"));
        org.junit.jupiter.api.Assertions.assertFalse(LoginIdentifier.hasPlusAlias("226051015@bingol.edu.tr"));
        assertEquals("ali@bingol.edu.tr", LoginIdentifier.aliasKey("ali+2@bingol.edu.tr"));
        assertEquals("ali@bingol.edu.tr", LoginIdentifier.aliasKey("ali+a+b@bingol.edu.tr"));
        assertEquals("ali@bingol.edu.tr", LoginIdentifier.aliasKey("ali@bingol.edu.tr"));
    }
}
