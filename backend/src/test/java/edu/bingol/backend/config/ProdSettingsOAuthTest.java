package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

/** Google/Apple girisi: bayrak ACIKKEN istemci kimlik listeleri (aud beyaz listesi) bos olamaz; kapaliyken denetlenmez. */
class ProdSettingsOAuthTest {

    private static List<String> errors(MockEnvironment env, List<String> warnings) {
        List<String> errors = new ArrayList<>();
        ProdSettingsValidator.validateOAuth(env, errors, warnings);
        return errors;
    }

    @Test
    void flagOffNeedsNothing() {
        List<String> w = new ArrayList<>();
        assertTrue(errors(new MockEnvironment(), w).isEmpty());
        assertTrue(w.isEmpty());
        assertTrue(errors(new MockEnvironment().withProperty("app.auth.oauth.enabled", "false"), w).isEmpty());
    }

    @Test
    void flagOnWithoutAnyClientIdRefusesToStart() {
        List<String> w = new ArrayList<>();
        List<String> e = errors(new MockEnvironment().withProperty("app.auth.oauth.enabled", "true")
                .withProperty("app.auth.oauth.google-client-ids", " , ").withProperty("app.auth.oauth.apple-client-ids", ""), w);
        assertFalse(e.isEmpty());
        assertTrue(e.get(0).contains("GOOGLE_CLIENT_IDS") && e.get(0).contains("APPLE_CLIENT_IDS"), e.toString());
    }

    @Test
    void oneProviderConfiguredWarnsAboutTheOtherAndBothConfiguredIsClean() {
        List<String> w = new ArrayList<>();
        assertTrue(errors(new MockEnvironment().withProperty("app.auth.oauth.enabled", "true")
                .withProperty("app.auth.oauth.google-client-ids", "web.apps.googleusercontent.com,android.apps.googleusercontent.com"), w).isEmpty());
        assertTrue(w.stream().anyMatch(x -> x.contains("APPLE_CLIENT_IDS")), w.toString());

        List<String> w2 = new ArrayList<>();
        assertTrue(errors(new MockEnvironment().withProperty("app.auth.oauth.enabled", "true")
                .withProperty("app.auth.oauth.google-client-ids", "web.apps.googleusercontent.com")
                .withProperty("app.auth.oauth.apple-client-ids", "tr.com.bukampus.app"), w2).isEmpty());
        assertTrue(w2.isEmpty());
    }
}
