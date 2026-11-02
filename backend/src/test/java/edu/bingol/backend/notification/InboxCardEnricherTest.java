package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationView;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

/** Bildirim kutusu kart alanlari (tasarim 08): eylemler, gonderen adi/avatari (gizlilik + engel), takip istegi, kategori. */
class InboxCardEnricherTest {

    private final UserRepository users = mock(UserRepository.class);
    private final AvatarVisibility vis = mock(AvatarVisibility.class);
    private final BlockService blocks = mock(BlockService.class);
    private InboxCardEnricher enricher;

    private static User user(long id, String name, String avatar) {
        User u = new User();
        u.setId(id);
        u.setDisplayName(name);
        u.setAvatarUrl(avatar);
        return u;
    }

    private static Notification row(long id, NotificationType type, String subtype, String data, boolean read) {
        Notification n = new Notification();
        n.setId(id);
        n.setUserId(1L);
        n.setType(type);
        n.setSubtype(subtype);
        n.setTitle("t");
        n.setBody("b");
        n.setData(data);
        n.setCreatedAt(Instant.parse("2026-11-02T09:00:00Z"));
        if (read) {
            n.setReadAt(Instant.now());
        }
        return n;
    }

    @BeforeEach
    void setUp() {
        enricher = new InboxCardEnricher(users, vis, blocks, JsonMapper.builder().build());
        when(users.findAllById(anyCollection())).thenReturn(List.of(user(7L, "Can Öztürk", "/files/can.jpg")));
        when(vis.visibleOwners(anyLong(), anyCollection(), any(AvatarVisibility.Field.class))).thenReturn(Set.of(7L));
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
    }

    @Test
    void followRequestRowGetsAcceptRejectSenderAndRequestId() {
        List<NotificationView> out = enricher.enrich(1L, List.of(row(10, NotificationType.FOLLOW_REQUEST,
                "FOLLOW_REQUEST", "{\"userId\":\"7\",\"target\":\"FOLLOW_REQUESTS\"}", false)));
        NotificationView v = out.get(0);
        assertEquals("FOLLOW_REQUEST", v.card());
        assertEquals(List.of("accept", "reject"), v.actions());
        assertEquals("Can Öztürk", v.senderName());
        assertEquals("/files/can.jpg", v.senderAvatarUrl());
        assertEquals("7", v.requestId());
        assertEquals("social", v.category());
        assertEquals("social", v.channelId());
    }

    @Test
    void answeredFollowRequestLosesItsButtons() {
        NotificationView v = enricher.enrich(1L, List.of(row(10, NotificationType.FOLLOW_REQUEST, "FOLLOW_REQUEST",
                "{\"userId\":\"7\"}", true))).get(0);
        assertTrue(v.actions().isEmpty());
        assertEquals("7", v.requestId());
    }

    @Test
    void avatarHiddenByPrivacyOrBlockNeverLeaks() {
        when(vis.visibleOwners(anyLong(), anyCollection(), any(AvatarVisibility.Field.class))).thenReturn(Set.of());
        NotificationView hidden = enricher.enrich(1L, List.of(row(1, NotificationType.USER_FOLLOW, "USER_FOLLOW",
                "{\"userId\":\"7\"}", false))).get(0);
        assertEquals("Can Öztürk", hidden.senderName());
        assertNull(hidden.senderAvatarUrl());

        when(vis.visibleOwners(anyLong(), anyCollection(), any(AvatarVisibility.Field.class))).thenReturn(Set.of(7L));
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of(7L));
        NotificationView blocked = enricher.enrich(1L, List.of(row(2, NotificationType.USER_FOLLOW, "USER_FOLLOW",
                "{\"userId\":\"7\"}", false))).get(0);
        assertNull(blocked.senderAvatarUrl());
        assertNull(blocked.senderName());
    }

    @Test
    void likeRowUsesActorIdAndUnitNewsRowGetsLabel() {
        NotificationView like = enricher.enrich(1L, List.of(row(3, NotificationType.POST_LIKE, "POST_LIKE",
                "{\"postId\":\"4\",\"actorId\":\"7\"}", false))).get(0);
        assertEquals("Can Öztürk", like.senderName());
        assertEquals(List.of("view"), like.actions());

        NotificationView unit = enricher.enrich(1L, List.of(row(4, NotificationType.ANNOUNCEMENT, "UNIT_ANNOUNCEMENT",
                "{\"unitNewsId\":\"9\",\"label\":\"Bilgisayar Mühendisliği\"}", false))).get(0);
        assertEquals("UNIT_ANNOUNCEMENT", unit.card());
        assertEquals("Bilgisayar Mühendisliği", unit.label());
        assertEquals("announcements", unit.category());
    }

    @Test
    void newsRowExposesImageAndThumbStyle_securityRowHasNoSender() {
        NotificationView news = enricher.enrich(1L, List.of(row(5, NotificationType.NEWS, null,
                "{\"newsId\":\"1\",\"imageUrl\":\"https://www.bingol.edu.tr/a.jpg\"}", false))).get(0);
        assertEquals("NEWS", news.card());
        assertEquals("https://www.bingol.edu.tr/a.jpg", news.imageUrl());
        assertEquals("thumb", news.imageStyle());

        NotificationView sec = enricher.enrich(1L, List.of(row(6, NotificationType.SYSTEM, null,
                "{\"card\":\"SECURITY_NEW_DEVICE\"}", false))).get(0);
        assertEquals(List.of("not_me", "view"), sec.actions());
        assertEquals("security", sec.channelId());
        assertEquals("system", sec.category());
        assertNull(sec.senderName());
    }

    @Test
    void brokenOrMissingDataNeverDropsTheRow() {
        List<NotificationView> out = enricher.enrich(1L, List.of(
                row(7, NotificationType.EVENT, "EVENT_UPDATE", "not-json", false),
                row(8, NotificationType.EVENT, null, null, false)));
        assertEquals(2, out.size());
        assertEquals(List.of("view"), out.get(0).actions());
        assertEquals("events", out.get(1).category());
    }

    @Test
    void categoryFilterMapsToTypes() {
        assertTrue(NotificationInboxService.categoryTypes("messages").isEmpty());
        assertEquals(List.of(NotificationType.EVENT), NotificationInboxService.categoryTypes("events"));
        assertTrue(NotificationInboxService.categoryTypes("announcements").contains(NotificationType.NEWS));
        assertTrue(NotificationInboxService.categoryTypes("social").contains(NotificationType.FOLLOW_REQUEST));
        assertTrue(NotificationInboxService.categoryTypes("ALL").size() > 5);
        assertThrows(ApiException.class, () -> NotificationInboxService.categoryTypes("bogus"));
    }
}
