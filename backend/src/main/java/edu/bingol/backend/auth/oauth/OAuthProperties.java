package edu.bingol.backend.auth.oauth;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.auth.oauth.*`: Google/Apple ile giris. {@code enabled=false} (varsayilan) iken tum OAuth uclari 404
 * OAUTH_DISABLED doner: yapilandirma gelmeden guvenle dagitilir.
 *
 * @param enabled         ozellik bayragi (AUTH_OAUTH_ENABLED)
 * @param googleClientIds Google ID token {@code aud} beyaz listesi (Web/Android/iOS istemci kimlikleri; GOOGLE_CLIENT_IDS)
 * @param appleClientIds  Apple identity token {@code aud} beyaz listesi (uygulama bundle id + varsa Services ID; APPLE_CLIENT_IDS)
 * @param requireTermsConsent onboarding sozlesme onayi (acceptTerms=true ya da onceden /api/legal/accept) ister
 * @param passwordSignupsNeedOnboarding parola ile kaydolanlar da profil tamamlama kapisindan gecsin (varsayilan false:
 *                        mevcut kayit akisi ve eski mobil surumler bozulmaz)
 */
@ConfigurationProperties("app.auth.oauth")
public record OAuthProperties(@DefaultValue("false") boolean enabled,
                              @DefaultValue List<String> googleClientIds,
                              @DefaultValue List<String> appleClientIds,
                              @DefaultValue("true") boolean requireTermsConsent,
                              @DefaultValue("false") boolean passwordSignupsNeedOnboarding) {

    public OAuthProperties {
        googleClientIds = clean(googleClientIds);
        appleClientIds = clean(appleClientIds);
    }

    private static List<String> clean(List<String> in) {
        return in == null ? List.of() : in.stream().map(String::trim).filter(s -> !s.isEmpty()).toList();
    }

    public List<String> audiencesOf(OAuthProvider p) {
        return p == OAuthProvider.GOOGLE ? googleClientIds : appleClientIds;
    }
}
