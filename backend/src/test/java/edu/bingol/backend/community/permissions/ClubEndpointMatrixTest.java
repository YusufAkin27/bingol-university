package edu.bingol.backend.community.permissions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.UserRepository;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.multipart.MultipartFile;

/**
 * Yetki matrisi: her konum x her mevcut uc (bilgi, kapak, istek listesi, istek karari, cikarma/ban, yetki sorgusu).
 * Gonderi ve etkinlik uclari CommunityService.can/require'a baglidir; onlar da burada dogrulanir.
 */
class ClubEndpointMatrixTest {

    private final ClubTestSupport t = new ClubTestSupport();
    private final CommunityService svc = new CommunityService(t.communities, t.members, mock(UserRepository.class),
            mock(BlockService.class), mock(NotificationService.class), mock(FileStorage.class), t.permissions,
            mock(ClubAuditService.class));

    /** actorId -> konum adi. Her konum icin yeni kullanici id'si. */
    private final Map<String, Actor> actors = new LinkedHashMap<>();

    private void positions() {
        t.member(20L, Role.MEMBER);
        actors.put("member", new Actor(20L, false));
        t.member(21L, Role.MODERATOR);
        actors.put("moderator", new Actor(21L, false));
        t.member(22L, Role.ADMIN);
        actors.put("admin", new Actor(22L, false));
        t.member(23L, Role.OWNER);
        actors.put("owner", new Actor(23L, false));
        actors.put("systemAdmin", new Actor(500L, true));
        t.member(24L, Role.MEMBER);
        t.grant(24L, ClubPermission.MANAGE_POSTS);
        actors.put("postManager", new Actor(24L, false));
        t.member(25L, Role.MEMBER);
        t.grant(25L, ClubPermission.MANAGE_EVENTS);
        actors.put("eventManager", new Actor(25L, false));
        t.member(26L, Role.MEMBER);
        t.grant(26L, ClubPermission.MANAGE_MEMBERS, ClubPermission.INVITE);
        actors.put("memberManager", new Actor(26L, false));
        t.member(27L, Role.MODERATOR);
        t.grant(27L, ClubPermission.INVITE); // moderator ama yetkileri kisitlanmis
        actors.put("restrictedModerator", new Actor(27L, false));
        t.member(28L, Role.MEMBER);
        t.grant(28L, ClubPermission.EDIT_INFO);
        actors.put("infoEditor", new Actor(28L, false));
        actors.put("stranger", new Actor(99L, false));
    }

    private static boolean allowed(Runnable r) {
        try {
            r.run();
            return true;
        } catch (ApiException e) {
            assertEquals(HttpStatus.FORBIDDEN, e.status(), "yetkisizlik 403 olmali: " + e.code());
            return false;
        }
    }

    private void expect(String op, java.util.function.Function<Actor, Runnable> call, String... allowedPositions) {
        java.util.Set<String> ok = java.util.Set.of(allowedPositions);
        for (var e : actors.entrySet()) {
            // Hedef kayitlari her denemede tazele (silinen/degisen nesne sonrakini etkilemesin).
            t.member(5L, Role.MEMBER, CommunityMember.Status.PENDING);
            t.member(6L, Role.MEMBER);
            assertEquals(ok.contains(e.getKey()), allowed(call.apply(e.getValue())), op + " / " + e.getKey());
        }
    }

    @Test
    void editInfoAndCover() {
        positions();
        MultipartFile file = mock(MultipartFile.class);
        String[] who = {"moderator", "admin", "owner", "systemAdmin", "infoEditor"};
        expect("update", a -> () -> svc.update(a, 10L, new UpdateCommunityRequest(null, "yeni", null, null, null)), who);
        expect("cover", a -> () -> svc.setCover(a, 10L, file), who);
    }

    @Test
    void memberManagementEndpoints() {
        positions();
        String[] who = {"moderator", "admin", "owner", "systemAdmin", "memberManager"};
        expect("requests", a -> () -> svc.requests(a, 10L, null, 20), who);
        expect("approve", a -> () -> svc.decide(a, 10L, 5L, true), who);
        expect("reject", a -> () -> svc.decide(a, 10L, 5L, false), who);
        expect("remove", a -> () -> svc.remove(a, 10L, 6L, false), who);
        expect("ban", a -> () -> svc.remove(a, 10L, 6L, true), who);
    }

    @Test
    void postAndEventPermissionsAreExposedThroughCan() {
        positions();
        for (var e : actors.entrySet()) {
            String k = e.getKey();
            Actor a = e.getValue();
            boolean staff = java.util.Set.of("moderator", "admin", "owner", "systemAdmin").contains(k);
            assertEquals(staff || k.equals("postManager"), svc.can(a, 10L, ClubPermission.MANAGE_POSTS), "posts / " + k);
            assertEquals(staff || k.equals("eventManager"), svc.can(a, 10L, ClubPermission.MANAGE_EVENTS), "events / " + k);
            assertEquals(staff || k.equals("memberManager") || k.equals("restrictedModerator"),
                    svc.can(a, 10L, ClubPermission.INVITE), "invite / " + k);
            assertEquals(k.equals("owner") || k.equals("systemAdmin"), svc.can(a, 10L, ClubPermission.MANAGE_ROLES),
                    "roles / " + k);
        }
        assertFalse(svc.can(new Actor(99L, false), 10L, ClubPermission.MANAGE_POSTS));
    }

    // ---- cikarma/ban: sira kurallari ----

    private void removeAs(Actor a, long target) {
        svc.remove(a, 10L, target, false);
    }

    @Test
    void removalRespectsRank() {
        positions();
        t.member(30L, Role.MODERATOR);
        t.member(31L, Role.ADMIN);
        t.member(32L, Role.MEMBER);
        t.grant(32L, ClubPermission.MANAGE_POSTS); // ozel yetkili uye
        Actor mod = actors.get("moderator");
        Actor admin = actors.get("admin");
        Actor memberMgr = actors.get("memberManager");

        assertFalse(allowed(() -> removeAs(mod, 30L)), "moderator moderatoru cikaramaz");
        assertFalse(allowed(() -> removeAs(mod, 31L)), "moderator yoneticiyi cikaramaz");
        assertFalse(allowed(() -> removeAs(admin, 31L)), "yonetici esiti cikaramaz");
        assertFalse(allowed(() -> removeAs(memberMgr, 32L)), "uye yoneticisi ozel yetkili uyeyi cikaramaz");
        assertFalse(allowed(() -> removeAs(memberMgr, 30L)), "uye yoneticisi moderatoru cikaramaz");
        assertTrue(allowed(() -> removeAs(admin, 30L)), "yonetici moderatoru cikarabilir");
        assertTrue(allowed(() -> removeAs(actors.get("owner"), 31L)), "sahip yoneticiyi cikarabilir");
        assertTrue(allowed(() -> removeAs(actors.get("systemAdmin"), 31L)), "sistem yoneticisi cikarabilir");
        assertTrue(allowed(() -> removeAs(mod, 20L)), "moderator duz uyeyi cikarabilir");
    }

    @Test
    void ownerCanNeverBeRemovedAndSelfRemovalIsBlocked() {
        positions();
        ApiException e = ClubTestSupport.error(() -> svc.remove(actors.get("systemAdmin"), 10L, 23L, true));
        assertEquals("OWNER_PROTECTED", e.code());
        assertEquals("USE_LEAVE", ClubTestSupport.error(() -> svc.remove(actors.get("owner"), 10L, 23L, false)).code());
    }
}
