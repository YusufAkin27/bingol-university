package edu.bingol.backend.mail.campaign;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailRenderer;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class CustomMailRendererTest {

    private static MailCustomTemplateVersion version() {
        MailCustomTemplateVersion v = new MailCustomTemplateVersion();
        v.setSubjectTr("Merhaba {{ad}}");
        v.setHtmlTr(MailTemplateSanitizer.cleanHtml("<p>Selam {{ad}}, bolum: {{bolum}}</p><a href=\"{{uygulamaUrl}}\">Ac</a><a href=\"{{abonelikCikUrl}}\">Cik</a>"));
        v.setTextTr("Selam {{ad}}, bolum: {{bolum}}");
        v.setSubjectEn("Hello {{ad}}");
        v.setHtmlEn(MailTemplateSanitizer.cleanHtml("<p>Hi {{ad}}</p>"));
        v.setTextEn("Hi {{ad}}");
        return v;
    }

    private static Map<String, String> vars(String name) {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("ad", name);
        m.put("eposta", "a@bingol.edu.tr");
        m.put("bolum", "");
        m.put("fakulte", "");
        m.put("sinif", "");
        m.put("uygulamaUrl", "https://app.test");
        m.put("abonelikCikUrl", "https://app.test/u?t=1&x=2");
        return m;
    }

    private CustomMailRenderer renderer(MailCustomTemplateVersion v) {
        MailCustomTemplateVersionRepository repo = mock(MailCustomTemplateVersionRepository.class);
        when(repo.findByTemplateIdAndVersion(7L, 1)).thenReturn(Optional.of(v));
        return new CustomMailRenderer(repo);
    }

    @Test
    void placeholderValuesAreHtmlEscapedButPlainTextIsRaw() {
        Map<String, String> vars = vars("<script>alert(1)</script> & \"q\"");
        vars.put("tplId", "7");
        vars.put("tplVer", "1");
        MailRenderer.Rendered r = renderer(version()).render(Lang.TR, vars);
        assertThat(r.html()).doesNotContain("<script>").contains("&lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;q&quot;");
        assertThat(r.text()).contains("<script>alert(1)</script> & \"q\"");
        assertThat(r.subject()).isEqualTo("Merhaba <script>alert(1)</script> & \"q\"");
    }

    @Test
    void wrapsInLayoutAndFillsUnsubscribeVariable() {
        Map<String, String> vars = vars("Ali");
        vars.put("tplId", "7");
        vars.put("tplVer", "1");
        MailRenderer.Rendered tr = renderer(version()).render(Lang.TR, vars);
        assertThat(tr.html()).contains("<!DOCTYPE html>").contains("BÜ Kampüs").contains("href=\"https://app.test\"")
                .contains("href=\"https://app.test/u?t=1&amp;x=2\"").contains("lang=\"tr\"");
        // abonelik alt bilgisini kuyruk iscisi ekler (UnsubscribeFooter); burada ikinci kez eklenmez
        assertThat(tr.html()).doesNotContain("Abonelikten çık");
        MailRenderer.Rendered en = renderer(version()).render(Lang.EN, vars);
        assertThat(en.subject()).isEqualTo("Hello Ali");
        assertThat(en.html()).contains("lang=\"en\"");
    }

    @Test
    void missingLanguageFallsBackToTurkish() {
        MailCustomTemplateVersion v = version();
        CustomMailRenderer.Resolved ar = CustomMailRenderer.resolve(v, Lang.AR);
        assertThat(ar.fallback()).isTrue();
        assertThat(ar.used()).isEqualTo(Lang.TR);
        CustomMailRenderer.Resolved en = CustomMailRenderer.resolve(v, Lang.EN);
        assertThat(en.fallback()).isFalse();
        Map<String, String> vars = vars("Ali");
        vars.put("tplId", "7");
        vars.put("tplVer", "1");
        MailRenderer.Rendered r = renderer(v).render(Lang.AR, vars);
        assertThat(r.subject()).isEqualTo("Merhaba Ali");
        assertThat(r.html()).contains("dir=\"ltr\"");
    }

    @Test
    void testSubjectPrefixAndNoHeaderInjection() {
        Map<String, String> vars = vars("Ali\r\nBcc: x@y.z");
        vars.put("tplId", "7");
        vars.put("tplVer", "1");
        vars.put("subjectPrefix", "[TEST] ");
        MailRenderer.Rendered r = renderer(version()).render(Lang.TR, vars);
        assertThat(r.subject()).startsWith("[TEST] Merhaba").doesNotContain("\n").doesNotContain("\r");
    }
}
