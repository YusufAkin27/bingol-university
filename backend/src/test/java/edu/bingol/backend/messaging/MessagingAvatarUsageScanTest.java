package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.messaging.dto.MessagingDtos.UserSummary;
import edu.bingol.backend.user.User;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * T-027 (QueryRulesTest benzeri tarama): mesajlasma paketinde bir KULLANICININ avatari ({@code User#getAvatarUrl()})
 * gizlilik/moderasyon karari ({@code AvatarVisibility}) olmadan DTO'ya girmemeli. Konusma (grup) fotografi
 * {@code Conversation#getAvatarUrl()} kullanici avatari degildir ve serbesttir.
 */
class MessagingAvatarUsageScanTest {

    /** Kullanici avatarini okuyan, kararini kendisi veren dosyalar (MessageService: push yuku viewersAmong ile sinirli). */
    private static final Set<String> REVIEWED_FILES = Set.of("MessageService.java");

    private static Path root() {
        Path p = Path.of("src/main/java/edu/bingol/backend/messaging");
        return Files.isDirectory(p) ? p : Path.of("backend").resolve(p);
    }

    @Test
    void userAvatarReadsInMessagingAreGuardedByTheVisibilityDecision() throws IOException {
        List<String> offenders = new ArrayList<>();
        try (Stream<Path> files = Files.walk(root())) {
            for (Path f : files.filter(x -> x.toString().endsWith(".java")).toList()) {
                String name = f.getFileName().toString();
                if (REVIEWED_FILES.contains(name)) {
                    continue;
                }
                List<String> lines = Files.readAllLines(f);
                for (int i = 0; i < lines.size(); i++) {
                    String l = lines.get(i);
                    if (!l.contains(".getAvatarUrl()") || l.trim().startsWith("*") || l.trim().startsWith("//")) {
                        continue;
                    }
                    boolean conversationAvatar = l.contains("c.getAvatarUrl()");
                    boolean guarded = l.contains("Visible.contains(");
                    if (!conversationAvatar && !guarded) {
                        offenders.add(name + ":" + (i + 1) + ": " + l.trim());
                    }
                }
            }
        }
        assertTrue(offenders.isEmpty(), "Avatar gizlilik karari olmadan okunuyor: " + offenders);
    }

    @Test
    void userSummaryFactoryIsFailClosed() {
        User u = new User();
        u.setId(2L);
        u.setDisplayName("Ali");
        u.setAvatarUrl("/files/avatars/x.jpg");

        assertEquals(null, UserSummary.of(u).avatarUrl()); // karar verilene kadar avatar yok
        assertEquals("/files/avatars/x.jpg", UserSummary.of(u).withAvatar("/files/avatars/x.jpg").avatarUrl());
    }
}
