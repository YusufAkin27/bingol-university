package edu.bingol.backend.moderation;

import java.util.Locale;
import java.util.Optional;

/** Karar nedeni sablonlari. Metinler `mod.reason.<KOD>` anahtarlariyla (tr/en/ar) cevrilir. */
public enum DecisionReason {
    SPAM, HARASSMENT, SEXUAL, VIOLENCE, HATE, PRIVACY, COPYRIGHT, IMPERSONATION, OTHER;

    public String messageKey() {
        return "mod.reason." + name();
    }

    public static Optional<DecisionReason> parse(String code) {
        if (code == null || code.isBlank()) {
            return Optional.empty();
        }
        try {
            return Optional.of(valueOf(code.trim().toUpperCase(Locale.ROOT)));
        } catch (IllegalArgumentException e) {
            return Optional.empty();
        }
    }
}
