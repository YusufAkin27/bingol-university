package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.i18n.Lang;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** TWO_FACTOR_CODE sablonu: uc dilde HTML + duz metin, kod ve sure dolu, islemsiz yer tutucu kalmaz. */
class TwoFactorMailTemplateTest {

    private final MailRenderer renderer = new MailRenderer();

    @Test
    void rendersInAllThreeLanguagesWithCodeAndMinutes() {
        for (Lang lang : Lang.values()) {
            MailRenderer.Rendered r = renderer.render(MailTemplate.TWO_FACTOR_CODE, lang,
                    Map.of("code", "482913", "minutes", "10"));

            assertThat(r.html()).as(lang.code()).contains("482913").contains("dir=\"ltr\"").contains("10")
                    .doesNotContain("{{").doesNotContain("mail.tpl.");
            assertThat(r.text()).as(lang.code()).contains("482913").contains("10").doesNotContain("{{")
                    .doesNotContain("mail.tpl.");
            assertThat(r.subject()).as(lang.code()).startsWith("BÜ Kampüs").doesNotContain("mail.tpl.");
        }
    }

    @Test
    void subjectsAndDirectionPerLanguage() {
        assertThat(renderer.render(MailTemplate.TWO_FACTOR_CODE, Lang.TR, Map.of("code", "1", "minutes", "10")).subject())
                .isEqualTo("BÜ Kampüs - Giriş doğrulama kodu");
        assertThat(renderer.render(MailTemplate.TWO_FACTOR_CODE, Lang.EN, Map.of("code", "1", "minutes", "10")).subject())
                .isEqualTo("BÜ Kampüs - Sign-in verification code");
        assertThat(renderer.render(MailTemplate.TWO_FACTOR_CODE, Lang.AR, Map.of("code", "1", "minutes", "10")).html())
                .contains("<html lang=\"ar\" dir=\"rtl\">");
    }

    @Test
    void isATransactionalMailNeverAnnouncement() {
        assertThat(MailCategory.of(MailTemplate.TWO_FACTOR_CODE)).isEqualTo(MailCategory.TRANSACTIONAL);
        assertThat(MailCategory.of(MailTemplate.TWO_FACTOR_CODE).priority()).isZero();
    }
}
