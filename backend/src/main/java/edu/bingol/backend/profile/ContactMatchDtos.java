package edu.bingol.backend.profile;

import jakarta.validation.constraints.NotNull;
import java.util.List;

public final class ContactMatchDtos {

    private ContactMatchDtos() {}

    /** Her hash: rehberdeki e-postanin (kucuk harf, kirpilmis) SHA-256 hex'i. */
    public record MatchRequest(@NotNull List<String> hashes) {}

    public record Match(String hash, Long userId, String displayName, String avatarUrl, String faculty,
                        String department) {}

    public record MatchResponse(List<Match> matches) {}

    /** "Rehberden bulunabilirim" (varsayilan false). */
    public record Discoverable(boolean enabled) {}

    public record DiscoverableRequest(@NotNull Boolean enabled) {}
}
