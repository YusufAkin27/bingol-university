package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationPage;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationView;
import edu.bingol.backend.notification.dto.NotificationDtos.UnreadCounts;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * Iki ayri bildirim merkezi: Hareketler (kalp, SOCIAL) ve Bildirimler (zil, INFORMATION). Bir bildirim tek kapsama
 * aittir; sayaclar ve "tumunu okundu yap" kapsama ozeldir; kapsamsiz (eski) istemci tum kutuyu gorur.
 */
@SpringBootTest
class NotificationScopeSplitTest {

    @Autowired NotificationInboxService inbox;
    @Autowired NotificationRepository repo;
    @Autowired UserRepository users;
    @Autowired edu.bingol.backend.profile.MeSummaryService summary;

    private Long user() {
        User u = new User();
        u.setEmail("scope-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kisi");
        u.setEmailVerified(true);
        return users.saveAndFlush(u).getId();
    }

    private Notification row(Long uid, NotificationType type, String subtype, String data) {
        Notification n = new Notification();
        n.setUserId(uid);
        n.setType(type);
        n.setSubtype(subtype);
        n.setTitle(type.name());
        n.setBody("b");
        n.setData(data);
        return repo.saveAndFlush(n);
    }

    private Long seed() {
        Long uid = user();
        row(uid, NotificationType.POST_LIKE, "POST_LIKE", "{\"postId\":\"1\",\"actorId\":\"9\"}");
        row(uid, NotificationType.POST_COMMENT, "POST_COMMENT", "{\"postId\":\"1\"}");
        row(uid, NotificationType.USER_FOLLOW, "USER_FOLLOW", "{\"userId\":\"9\"}");
        row(uid, NotificationType.FOLLOW_REQUEST, "FOLLOW_REQUEST", "{\"userId\":\"9\"}");
        row(uid, NotificationType.FORUM, "FORUM_TOPIC_LIKE", "{\"topicId\":\"3\"}");
        row(uid, NotificationType.COMMUNITY, "COMMUNITY_JOIN", "{\"communityId\":\"4\",\"userId\":\"9\"}");
        row(uid, NotificationType.EVENT, "EVENT_REMINDER", "{\"eventId\":\"5\"}");
        row(uid, NotificationType.ANNOUNCEMENT, null, "{\"announcementId\":\"6\"}");
        row(uid, NotificationType.ANNOUNCEMENT, "POLL", "{\"pollId\":\"7\"}");
        row(uid, NotificationType.COMMUNITY, "COMMUNITY_POST", "{\"communityId\":\"4\"}");
        row(uid, NotificationType.SYSTEM, null, null);
        row(uid, NotificationType.NEWS, null, "{\"newsId\":\"8\"}");
        row(uid, NotificationType.MESSAGE, "MESSAGE_DIRECT", "{\"conversationId\":\"1\"}");
        return uid;
    }

    @Test
    void bellNeverContainsSocialOrChat_heartOnlySocial() {
        Long uid = seed();
        NotificationPage bell = inbox.list(uid, null, 50, null, false, null, "INFORMATION");
        NotificationPage heart = inbox.list(uid, null, 50, null, false, null, "SOCIAL");

        assertEquals(6, bell.items().size());
        assertEquals(6, heart.items().size());
        for (NotificationView v : bell.items()) {
            assertEquals("INFORMATION", v.getScope(), v.type() + "/" + v.subtype());
            assertTrue(!"SOCIAL".equals(v.getCategory()) && !"MESSAGE".equals(v.getCategory()));
        }
        for (NotificationView v : heart.items()) {
            assertEquals("SOCIAL", v.getScope(), v.type() + "/" + v.subtype());
        }
        Set<Long> a = new java.util.HashSet<>();
        bell.items().forEach(v -> a.add(v.id()));
        heart.items().forEach(v -> assertTrue(a.add(v.id()), "bir bildirim iki merkezde gorunmez"));
        // kapsamsiz eski istemci: tum kutu (MESSAGE haric) = 12
        assertEquals(12, inbox.list(uid, null, 50, null, false).items().size());
    }

    @Test
    void sqlScopeAgreesWithJavaCategory() {
        Long uid = seed();
        for (boolean social : new boolean[] {true, false}) {
            for (Notification n : repo.pageScope(uid, null, java.util.Arrays.asList(NotificationType.values()), false, social, "ALL",
                    org.springframework.data.domain.PageRequest.of(0, 100))) {
                String scope = NotificationPresentation.scope(n.getType(), n.getSubtype(),
                        NotificationPresentation.data(n.getData()));
                assertEquals(social ? "SOCIAL" : "INFORMATION", scope, n.getType() + "/" + n.getSubtype());
            }
        }
    }

    @Test
    void countersAreIndependentAndMarkAllIsScoped() {
        Long uid = seed();
        UnreadCounts c = inbox.unreadCounts(uid);
        assertEquals(6, c.social());
        assertEquals(6, c.information());
        assertEquals(12, c.unreadCount());

        inbox.markRead(uid, null, true, "SOCIAL");
        c = inbox.unreadCounts(uid);
        assertEquals(0, c.social());
        assertEquals(6, c.information(), "kalp 'tumunu oku' zili etkilemez");
        assertEquals(0, inbox.list(uid, null, 50, null, true, null, "SOCIAL").items().size());

        inbox.markRead(uid, null, true, "INFORMATION");
        assertEquals(0, inbox.unreadCounts(uid).information());
    }

    @Test
    void legacyMarkAllReadsEverythingAndScopeIsValidated() {
        Long uid = seed();
        inbox.markRead(uid, null, true);
        UnreadCounts c = inbox.unreadCounts(uid);
        assertEquals(0, c.social());
        assertEquals(0, c.information());
        assertThrows(ApiException.class, () -> inbox.list(uid, null, 10, null, false, null, "CHAT"));
        assertThrows(ApiException.class, () -> inbox.markRead(uid, null, true, "BOGUS"));
    }

    @Test
    void categoryAndScopeConflictYieldsEmptyList() {
        Long uid = seed();
        assertTrue(inbox.list(uid, null, 50, null, false, "SOCIAL", "INFORMATION").items().isEmpty());
        assertEquals(6, inbox.list(uid, null, 50, null, false, "SOCIAL", "SOCIAL").items().size());
        assertEquals(1, inbox.list(uid, null, 50, null, false, "EVENT", "INFORMATION").items().size());
    }

    @Test
    void meSummaryExposesIndependentCountsAndKeepsLegacyTotal() {
        Long uid = seed();
        var m = summary.summary(uid);
        assertEquals(12, m.unreadNotifications(), "eski alan toplam kalir");
        assertEquals(6, m.unreadSocial());
        assertEquals(6, m.unreadInformation());
    }

    @Test
    void kindFiltersAndMultiCategory() {
        Long uid = seed();
        // Hareketler alt suzgecleri: begeni (POST_LIKE + forum konusu begenisi), yorum, takip/istek (+ kulup basvurusu)
        assertEquals(2, inbox.list(uid, null, 50, null, false, null, "SOCIAL", "LIKES").items().size());
        assertEquals(1, inbox.list(uid, null, 50, null, false, null, "SOCIAL", "COMMENTS").items().size());
        assertEquals(3, inbox.list(uid, null, 50, null, false, null, "SOCIAL", "FOLLOWS").items().size());
        assertThrows(ApiException.class, () -> inbox.list(uid, null, 10, null, false, null, "SOCIAL", "BOGUS"));
        // Duyurular cipi: virgullu kategori listesi (duyuru + akademik + anket + kulup duyurusu), etkinlik/sistem haric
        var duyuru = inbox.list(uid, null, 50, null, false, "ANNOUNCEMENT,ACADEMIC,POLL", "INFORMATION", null).items();
        assertEquals(4, duyuru.size());
        assertTrue(duyuru.stream().noneMatch(v -> "EVENT".equals(v.getCategory()) || "SYSTEM".equals(v.getCategory())));
        assertEquals(1, inbox.list(uid, null, 50, null, false, "SYSTEM", "INFORMATION", null).items().size());
    }

    @Test
    void presentationScopeMapping() {
        assertEquals("CHAT", NotificationPresentation.scope(NotificationType.MESSAGE, null, Map.of()));
        assertEquals("SOCIAL", NotificationPresentation.scope(NotificationType.COMMUNITY, "COMMUNITY_JOIN", Map.of()));
        assertEquals("INFORMATION", NotificationPresentation.scope(NotificationType.COMMUNITY, "COMMUNITY_POST", Map.of()));
        assertEquals("INFORMATION", NotificationPresentation.scope(NotificationType.EVENT, null, Map.of()));
    }
}
