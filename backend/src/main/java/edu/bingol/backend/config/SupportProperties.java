package edu.bingol.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/** `app.support.*`: herkese acik destek talepleri (T27). */
@ConfigurationProperties("app.support")
public record SupportProperties(@DefaultValue("365") int publicTicketRetentionDays,
                                @DefaultValue("http://localhost:8090") String trackBaseUrl,
                                @DefaultValue("3") int minFillSeconds) {
}
