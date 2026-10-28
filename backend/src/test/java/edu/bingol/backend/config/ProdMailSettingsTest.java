package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

/** ProdSettingsValidator: e-posta teslim edilebilirligi tutarliligi. */
class ProdMailSettingsTest {

    private static MockEnvironment mail() {
        return new MockEnvironment()
                .withProperty("app.mail.enabled", "true")
                .withProperty("app.mail.from", "no-reply@kampus.bingol.edu.tr")
                .withProperty("spring.mail.properties.mail.smtp.starttls.required", "true")
                .withProperty("app.mail.unsubscribe-base-url", "https://kampus.bingol.edu.tr");
    }

    private static List<String>[] run(MockEnvironment env) {
        List<String> errors = new ArrayList<>();
        List<String> warnings = new ArrayList<>();
        ProdSettingsValidator.validateMailDeliverability(env, errors, warnings);
        @SuppressWarnings("unchecked")
        List<String>[] r = new List[] {errors, warnings};
        return r;
    }

    @Test
    void consistentSettingsAreClean() {
        var r = run(mail());
        assertTrue(r[0].isEmpty() && r[1].isEmpty(), r[0] + " " + r[1]);
    }

    @Test
    void blankOrFakeFromIsAnError() {
        assertTrue(!run(mail().withProperty("app.mail.from", ""))[0].isEmpty());
        assertTrue(!run(mail().withProperty("app.mail.from", "x@localhost"))[0].isEmpty());
        assertTrue(!run(mail().withProperty("app.mail.from", "noatsign"))[0].isEmpty());
    }

    @Test
    void tlsNotRequiredAndLocalUnsubscribeUrlWarn() {
        var r = run(mail().withProperty("spring.mail.properties.mail.smtp.starttls.required", "false")
                .withProperty("app.mail.unsubscribe-base-url", "http://localhost:8090"));
        assertTrue(r[1].stream().anyMatch(w -> w.contains("TLS")), r[1].toString());
        assertTrue(r[1].stream().anyMatch(w -> w.contains("PUBLIC_WEB_URL")), r[1].toString());
    }

    @Test
    void differingSmtpUserDomainWarnsAndDisabledMailSkipsChecks() {
        var r = run(mail().withProperty("spring.mail.username", "user@other-provider.net"));
        assertTrue(r[1].stream().anyMatch(w -> w.contains("hizalama")), r[1].toString());
        var off = run(new MockEnvironment().withProperty("app.mail.enabled", "false"));
        assertTrue(off[0].isEmpty() && off[1].isEmpty());
    }
}
