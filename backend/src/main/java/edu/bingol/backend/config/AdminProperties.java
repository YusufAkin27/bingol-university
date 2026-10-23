package edu.bingol.backend.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** `app.admin.*`: bu e-postalar dogrulama/giris sirasinda ADMIN rolu alir (virgulle ayrilmis liste). */
@ConfigurationProperties("app.admin")
public record AdminProperties(List<String> emails) {

    public boolean isAdminEmail(String email) {
        return emails != null && emails.stream().anyMatch(e -> e.trim().equalsIgnoreCase(email));
    }
}
