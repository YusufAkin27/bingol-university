package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/**
 * Stitch bildirim tasarimi (NOTIF-CONTRACT.md, 28 kart): kart -> kanal + eylemler + gorsel stili tablosu ve
 * PushMessages'in bunlari yuke yazdigi. Sozlesme degisirse bu tablo da bilerek degisir.
 */
class NotifCardTest {

    private static Map<String, String> data(String... kv) {
        Map<String, String> m = new HashMap<>();
        for (int i = 0; i < kv.length; i += 2) {
            m.put(kv[i], kv[i + 1]);
        }
        return m;
    }

    private static PushMessage push(NotificationType t, NotificationSubtype s, Map<String, String> d, int count) {
        return PushMessages.of(t, s, "T", "B", PushPayload.build(t, s, d, count), null, 1);
    }

    /** Sozlesme tablosu: kart, kanal, eylemler, gorsel stili (bos = yok). */
    @ParameterizedTest
    @CsvSource({
            "CHAT_DM,chat,'reply,mark_read',",
            "CHAT_GROUP,chat,'reply,mute_1h',",
            "CHAT_PHOTO,chat,'view,reply',big",
            "CHAT_MANY,chat,'reply,mark_read',",
            "EVENT_DAY,event,'calendar,view',",
            "EVENT_HOUR,event,qr_checkin,",
            "EVENT_CHANGED,event,view,",
            "EVENT_ADMISSION,event,view,",
            "EVENT_CANCELLED,event,view,",
            "ANNOUNCEMENT,announcement,view,",
            "UNIT_ANNOUNCEMENT,announcement,view,",
            "ACADEMIC_ANNOUNCEMENT,academic,view,",
            "NEWS,announcement,view,thumb",
            "EXAM_REMINDER,academic,exam_card,",
            "MENU_TODAY,announcement,view,thumb",
            "POLL_NEW,poll,vote,",
            "POLL_CLOSING,poll,vote,",
            "POST_LIKE,social,view,thumb",
            "USER_FOLLOW,social,follow_back,",
            "FOLLOW_REQUEST,social,'accept,reject',",
            "FOLLOW_ACCEPTED,social,view,",
            "SECURITY_NEW_DEVICE,security,'not_me,view',",
            "SECURITY_PASSWORD,security,reset_password,",
            "SECURITY_2FA_OFF,security,enable_2fa,",
            "SECURITY_2FA_ON,security,view,",
            "SECURITY_SESSION,security,sign_out_device,",
            "SUPPORT_TICKET,announcement,view_ticket,"
    })
    void cardTableMatchesContract(String card, String channel, String actions, String style) {
        NotifCard c = NotifCard.valueOf(card);
        assertEquals(channel, c.channel());
        assertEquals(actions, c.actionsCsv());
        assertEquals(style == null ? null : style, c.imageStyle());
    }

    @Test
    void chatCardIsDerivedFromMessageShape() {
        assertEquals(NotifCard.CHAT_DM, NotifCard.resolve(NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT,
                data("conversationType", "DIRECT"), 1));
        assertEquals(NotifCard.CHAT_GROUP, NotifCard.resolve(NotificationType.MESSAGE, NotificationSubtype.MESSAGE_GROUP,
                data("conversationType", "GROUP"), 1));
        assertEquals(NotifCard.CHAT_MANY, NotifCard.resolve(NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT,
                data(), 3));
        // fotograf, birikimden once gelir (son mesaj fotografliysa kart fotografli)
        assertEquals(NotifCard.CHAT_PHOTO, NotifCard.resolve(NotificationType.MESSAGE, NotificationSubtype.MESSAGE_GROUP,
                data("imageUrl", "/x"), 3));
    }

    @Test
    void chatPushCarriesActionsGroupBadgeAndPhotoStyle() {
        PushMessage dm = push(NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT,
                data("conversationId", "5", "conversationType", "DIRECT"), 1);
        assertEquals("CHAT_DM", dm.data().get("card"));
        assertEquals("reply,mark_read", dm.data().get("actions"));
        assertEquals("chat", dm.data().get("channelId"));
        assertFalse(dm.data().containsKey("groupBadge"));

        PushMessage grp = push(NotificationType.MESSAGE, NotificationSubtype.MESSAGE_GROUP,
                data("conversationId", "5", "conversationType", "GROUP"), 1);
        assertEquals("reply,mute_1h", grp.data().get("actions"));
        assertEquals("1", grp.data().get("groupBadge"));

        PushMessage photo = push(NotificationType.MESSAGE, NotificationSubtype.MESSAGE_GROUP,
                data("conversationId", "5", "conversationType", "GROUP", "imageUrl", "/thumb"), 1);
        assertEquals("CHAT_PHOTO", photo.data().get("card"));
        assertEquals("big", photo.data().get("imageStyle"));
        assertEquals("1", photo.data().get("groupBadge")); // gruptaki fotografli karta da rozet
        assertEquals("view,reply", photo.data().get("actions"));
    }

    @Test
    void imageStyleOnlyWhenImagePresent() {
        PushMessage news = push(NotificationType.NEWS, null, data("newsId", "9"), 1);
        assertEquals("NEWS", news.data().get("card"));
        assertFalse(news.data().containsKey("imageStyle"));
        PushMessage withImg = push(NotificationType.NEWS, null, data("newsId", "9", "imageUrl", "https://x"), 1);
        assertEquals("thumb", withImg.data().get("imageStyle"));
    }

    @Test
    void templateKeysMapToCards() {
        assertEquals(NotifCard.EVENT_DAY, NotifCard.forKey("notif.event.reminderDay"));
        assertEquals(NotifCard.EVENT_HOUR, NotifCard.forKey("notif.event.reminderHour.title"));
        assertEquals(NotifCard.EVENT_CHANGED, NotifCard.forKey("notif.event.updated"));
        assertEquals(NotifCard.EVENT_CANCELLED, NotifCard.forKey("notif.event.cancelled"));
        assertEquals(NotifCard.EVENT_CANCELLED, NotifCard.forKey("notif.event.cancelledByAdmin"));
        assertEquals(NotifCard.EVENT_ADMISSION, NotifCard.forKey("notif.admission.accepted"));
        assertEquals(NotifCard.POLL_NEW, NotifCard.forKey("notif.poll.opened"));
        assertEquals(NotifCard.POLL_CLOSING, NotifCard.forKey("notif.poll.closing"));
        assertEquals(NotifCard.MENU_TODAY, NotifCard.forKey("notif.menu.todayPartial"));
        assertEquals(NotifCard.UNIT_ANNOUNCEMENT, NotifCard.forKey("notif.unitnews.new"));
        assertEquals(NotifCard.SUPPORT_TICKET, NotifCard.forKey("notif.ticket.answered.title"));
        assertEquals(NotifCard.SECURITY_2FA_ON, NotifCard.forKey("notif.twofactor.enabled.title"));
        assertEquals(NotifCard.SECURITY_2FA_OFF, NotifCard.forKey("notif.twofactor.userdisabled.title"));
        assertEquals(NotifCard.SECURITY_2FA_OFF, NotifCard.forKey("notif.twofactor.disabled.title"));
        assertNull(NotifCard.forKey("notif.community.joinRequest"));
        assertNull(NotifCard.forKey(null));
    }

    @Test
    void withCardInjectsCardWithoutOverridingProducer() {
        Map<String, String> d = NotificationService.withCard(Map.of("eventId", "4"), "notif.event.reminderHour");
        assertEquals("EVENT_HOUR", d.get("card"));
        assertEquals("4", d.get("eventId"));
        Map<String, String> own = Map.of("card", "EVENT_DAY");
        assertEquals("EVENT_DAY", NotificationService.withCard(own, "notif.event.reminderHour").get("card"));
        assertNull(NotificationService.withCard(null, "notif.community.joinRequest")); // karti olmayan sablon: aynen
    }

    @Test
    void securityCardsUseSecurityChannelAndAreUrgent() {
        PushMessage m = push(NotificationType.SYSTEM, null, data("card", "SECURITY_NEW_DEVICE"), 1);
        assertEquals("security", m.channelId());
        assertEquals("security", m.data().get("channelId"));
        assertEquals("not_me,view", m.data().get("actions"));
        assertTrue(m.highPriority());
        assertEquals("BU_NOT_ME_VIEW", m.data().get("iosCategory"));
    }

    @Test
    void socialAndEventAndPollCards() {
        assertEquals("accept,reject", push(NotificationType.FOLLOW_REQUEST, NotificationSubtype.FOLLOW_REQUEST,
                data("userId", "7", "requestId", "7"), 1).data().get("actions"));
        assertEquals("follow_back", push(NotificationType.USER_FOLLOW, NotificationSubtype.USER_FOLLOW,
                data("userId", "7"), 1).data().get("actions"));
        assertEquals("social", push(NotificationType.POST_LIKE, NotificationSubtype.POST_LIKE,
                data("postId", "1"), 1).channelId());
        PushMessage hour = push(NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER,
                data("eventId", "3", "card", "EVENT_HOUR"), 1);
        assertEquals("event", hour.channelId());
        assertEquals("qr_checkin", hour.data().get("actions"));
        PushMessage closing = push(NotificationType.ANNOUNCEMENT, NotificationSubtype.POLL,
                data("pollId", "3", "card", "POLL_CLOSING"), 1);
        assertEquals("poll", closing.channelId());
        assertEquals("vote", closing.data().get("actions"));
        PushMessage exam = push(NotificationType.ANNOUNCEMENT, NotificationSubtype.EXAM_REMINDER, data("examId", "3"), 1);
        assertEquals("academic", exam.channelId());
        assertEquals("exam_card", exam.data().get("actions"));
        PushMessage acad = push(NotificationType.ANNOUNCEMENT, NotificationSubtype.ACADEMIC_ANNOUNCEMENT, data(), 1);
        assertEquals("academic", acad.channelId());
    }

    @Test
    void globalPollBroadcastKeepsPollChannelEvenWithoutTemplateKey() {
        // PollNotifier genel yayinda broadcastLocalized kullanir (ANNOUNCEMENT, alt tur yok): kanal `poll` kalmali
        PushMessage m = push(NotificationType.ANNOUNCEMENT, null, data("pollId", "9"), 1);
        assertEquals("poll", m.channelId());
        assertEquals("vote", m.data().get("actions"));
        assertEquals("POLL_NEW", m.data().get("card"));
    }

    @Test
    void unknownCombinationFallsBackToTypeChannelWithoutActions() {
        PushMessage m = push(NotificationType.COMMUNITY, null, data("communityId", "2"), 1);
        assertEquals("announcement", m.channelId());
        assertNull(m.data().get("actions"));
        assertNull(m.data().get("card"));
    }

    @Test
    void iosCategoryIsDeterministicFromActionSet() {
        assertEquals("BU_REPLY_MARK_READ", NotifCard.CHAT_DM.iosCategory());
        assertEquals("BU_ACCEPT_REJECT", NotifCard.FOLLOW_REQUEST.iosCategory());
        assertEquals("BU_QR_CHECKIN", NotifCard.EVENT_HOUR.iosCategory());
        assertNotNull(NotifCard.parse("chat_dm"));
        assertNull(NotifCard.parse("nope"));
    }
}
