package edu.bingol.backend.auth.oauth;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ExtraBody;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;

/**
 * 409 OAUTH_LINK_REQUIRED: saglayici kimligi tanimiyor AMA ayni e-posta mevcut bir hesapta var. Otomatik birlestirme
 * YOKTUR; kullanici once e-posta + sifreyle girip {@code POST /api/auth/oauth/link} ile baglamalidir. Govde
 * {code, message, provider, emailMasked} (e-posta maskeli).
 */
public class OAuthLinkRequiredException extends ApiException implements ExtraBody {

    private final String provider;
    private final String emailMasked;

    public OAuthLinkRequiredException(OAuthProvider provider, String emailMasked) {
        super(HttpStatus.CONFLICT, "OAUTH_LINK_REQUIRED",
                "Bu e-posta ile kayıtlı bir hesap var. Önce e-posta ve şifrenizle giriş yapıp bağlayın.");
        this.provider = provider.name();
        this.emailMasked = emailMasked;
    }

    @Override
    public Map<String, String> extraBody() {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("provider", provider);
        m.put("emailMasked", emailMasked);
        return m;
    }
}
