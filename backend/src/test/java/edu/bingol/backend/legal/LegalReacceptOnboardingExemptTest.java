package edu.bingol.backend.legal;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** Yeniden onay zorlamasi acikken bile profil tamamlama (acceptTerms ile onay alir) engellenmez. */
class LegalReacceptOnboardingExemptTest {

    @Test
    void onboardingIsExemptFromTheReacceptGateButOtherProfileWritesAreNot() {
        assertFalse(LegalReacceptFilter.inScope("PUT", "/api/users/me/onboarding"));
        assertTrue(LegalReacceptFilter.inScope("PUT", "/api/users/me/username"));
        assertTrue(LegalReacceptFilter.inScope("POST", "/api/posts"));
    }
}
