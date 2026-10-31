package edu.bingol.backend.appinfo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** T-017: e-posta ve baglanti ayarlarinda bicim/satir sonu/sema dogrulamasi (Reply-To baslik enjeksiyonu, javascript: URL). */
class SettingsServiceTest {

    private final AppSettingRepository repo = mock(AppSettingRepository.class);
    private final AppInfoService service = new AppInfoService(repo);

    private void exists(String key) {
        AppSetting s = new AppSetting();
        s.setKey(key);
        s.setValue("eski");
        when(repo.findById(key)).thenReturn(Optional.of(s));
    }

    private void assertInvalid(String key, String value) {
        exists(key);
        ApiException e = assertThrows(ApiException.class, () -> service.set(key, value), key + "=" + value);
        assertEquals("SETTING_INVALID", e.code(), key + "=" + value);
        assertEquals(400, e.status().value());
        verify(repo, never()).save(any());
    }

    private void assertSaved(String key, String value, String expected) {
        org.mockito.Mockito.clearInvocations(repo); // ayni testte birden cok kayit: her cagri kendi save()'ini dogrular
        exists(key);
        service.set(key, value);
        ArgumentCaptor<AppSetting> c = ArgumentCaptor.forClass(AppSetting.class);
        verify(repo).save(c.capture());
        assertEquals(expected, c.getValue().getValue());
    }

    @Test
    void emailSettingsRejectNonEmailsScriptsAndLineBreaks() {
        assertInvalid("support_email", "not-an-email");
        assertInvalid("contact_email", "<script>x</script>");
        assertInvalid("support_email", "a@bingol.edu.tr\r\nBcc: kurban@example.com");
        assertInvalid("support_email", "a@bingol.edu.tr\nX-Header: 1");
        assertInvalid("support_email", "a@bingol.edu.tr, b@bingol.edu.tr");
        assertInvalid("support_email", "a b@bingol.edu.tr");
        assertInvalid("legal.controller.email", "kvkk");
        assertInvalid("contact_email", "@bingol.edu.tr");
    }

    @Test
    void validEmailAndEmptyAreAccepted() {
        assertSaved("support_email", "destek@bingol.edu.tr", "destek@bingol.edu.tr");
        assertSaved("contact_email", "  iletisim@bingol.edu.tr ", "iletisim@bingol.edu.tr");
        assertSaved("contact_email", "", ""); // ayar temizleme serbest
    }

    @Test
    void linkSettingsNeedHttpsAndNoControlOrMarkupCharacters() {
        assertInvalid("store_url_ios", "javascript:alert(1)");
        assertInvalid("store_url_android", "http://play.google.com/x");
        assertInvalid("banner_url", "https://x.test/a b");
        assertInvalid("banner_url", "https://x.test/\r\nSet-Cookie: a=b");
        assertInvalid("instagram", "instagram.com/bingol");
        assertInvalid("twitter", "https://x.test/<script>");
        assertInvalid("youtube", "https://");
        assertInvalid("website", "ftp://x.test");
    }

    @Test
    void validHttpsLinksAreAccepted() {
        assertSaved("store_url_ios", "https://apps.apple.com/app/id1", "https://apps.apple.com/app/id1");
        assertSaved("instagram", "https://instagram.com/bingolu", "https://instagram.com/bingolu");
        assertSaved("banner_url", "", "");
    }

    @Test
    void unrelatedSettingsKeepWorkingAndMessageKeysExistInAllLanguages() {
        assertSaved("banner_text_tr", "Duyuru", "Duyuru");
        for (String file : new String[] {"ops", "ops_en", "ops_ar"}) {
            java.util.Properties p = new java.util.Properties();
            try (var in = new java.io.InputStreamReader(
                    getClass().getResourceAsStream("/i18n/" + file + ".properties"), java.nio.charset.StandardCharsets.UTF_8)) {
                p.load(in);
            } catch (java.io.IOException e) {
                throw new java.io.UncheckedIOException(e);
            }
            assertEquals(true, p.containsKey("error.SETTING_INVALID"), file);
        }
    }
}
