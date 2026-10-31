package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.profile.privacy.AvatarVisibility.Field;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * T-027 (parca 2): kulup / etkinlik DTO'larinda avatar TEK karar noktasindan ({@link CommunityService#avatarsFor}) gecer:
 * engel + profil gizliligi (ONLY_ME / SHARED_CONTEXT) + moderasyon avatar_hidden. Karar verilemezse kapali basarisiz.
 */
class ClubAvatarPrivacyTest {

    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final CommunityService svc = new CommunityService(mock(CommunityRepository.class), members,
            mock(UserRepository.class), mock(BlockService.class), mock(NotificationService.class), mock(MediaService.class),
            new ClubPermissions(members, mock(ClubMemberGrantRepository.class)), mock(ClubAuditService.class),
            mock(ClubExtrasHooks.class));
    private final AvatarVisibility visibility = mock(AvatarVisibility.class);

    private static User user(long id, String avatar) {
        User u = new User();
        u.setId(id);
        u.setAvatarUrl(avatar);
        return u;
    }

    @Test
    void onlyMeSharedContextAndModeratedAvatarsAreNotSent() {
        svc.setVisibility(visibility);
        // 1: herkese acik, 2: ONLY_ME / avatar_hidden (gorunmez), 3: acik ama engelli, 4: avatari yok
        when(visibility.visibleOwners(eq(100L), any(), eq(Field.AVATAR))).thenReturn(Set.of(1L, 3L, 4L));

        Map<Long, String> out = svc.avatarsFor(100L,
                List.of(user(1, "/files/a1"), user(2, "/files/a2"), user(3, "/files/a3"), user(4, null)), Set.of(3L, -1L));

        assertEquals("/files/a1", out.get(1L));
        assertNull(out.get(2L), "ONLY_ME / avatar_hidden avatari kulup listesinde sizmamali");
        assertNull(out.get(3L), "engelli cift");
        assertNull(out.get(4L));
        assertEquals(1, out.size());
    }

    @Test
    void failsClosedWhenVisibilityDecisionIsUnavailable() {
        // setVisibility cagrilmadi (gizlilik karari yok)
        Map<Long, String> out = svc.avatarsFor(100L, List.of(user(1, "/files/a1")), Set.of());
        assertTrue(out.isEmpty());
    }

    @Test
    void ownerAlwaysSeesOwnAvatarViaVisibilityRule() {
        svc.setVisibility(visibility);
        when(visibility.visibleOwners(eq(1L), any(), eq(Field.AVATAR))).thenReturn(Set.of(1L));
        assertEquals("/files/me", svc.avatarsFor(1L, List.of(user(1, "/files/me")), Set.of()).get(1L));
    }

    /**
     * Tarama: kullanici avatari kulup / etkinlik DTO'larina yalniz {@link CommunityService#avatarsFor} uzerinden girer
     * (yonetici paketleri ve kendi gizlilik kontrolunu yapan onizleme servisi haric). Yeni dogrudan getAvatarUrl()
     * kullanimi bu testi kirar: gizlilik atlanmasin.
     */
    @Test
    void noDirectAvatarUrlReadsInClubAndEventUserFacingCode() throws IOException {
        Set<String> allowed = Set.of("community/CommunityService.java", "event/EventAttendeePreviewService.java");
        Path root = Path.of("src/main/java/edu/bingol/backend");
        Set<String> offenders;
        try (Stream<Path> files = Files.walk(root)) {
            offenders = files.filter(p -> p.toString().endsWith(".java"))
                    .map(p -> root.relativize(p).toString().replace('\\', '/'))
                    .filter(rel -> rel.startsWith("community/") || rel.startsWith("event/"))
                    .filter(rel -> !rel.contains("/admin/") && !allowed.contains(rel))
                    .filter(rel -> {
                        try {
                            return Files.readString(root.resolve(rel), StandardCharsets.UTF_8).contains(".getAvatarUrl()");
                        } catch (IOException e) {
                            throw new IllegalStateException(e);
                        }
                    }).collect(Collectors.toSet());
        }
        assertTrue(offenders.isEmpty(), "dogrudan getAvatarUrl(): " + offenders);
        assertFalse(allowed.isEmpty());
    }
}
