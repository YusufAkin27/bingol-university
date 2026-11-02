package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Stitch kart tasarimi servis davranisi: zengin tek alicili gonderim (push metni kutudan ayri, gonderen bilgisi yalniz
 * push'ta), guvenlik bildirimi (tercih/sessiz saat uygulanmaz, acik token'lara gider), sablondan kart enjeksiyonu,
 * menu tercihi.
 */
class NotificationCardServiceTest {

    private final NotificationRepository notifications = mock(NotificationRepository.class);
    private final NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
    private final NotificationSubtypePrefRepository subtypePrefs = mock(NotificationSubtypePrefRepository.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final I18n i18n = mock(I18n.class);
    private final RecipientGuard guard = mock(RecipientGuard.class);
    private final FakeFcmSender fcm = new FakeFcmSender();
    private NotificationService svc;

    private static Device device(String t) {
        Device d = new Device();
        d.setFcmToken(t);
        return d;
    }

    @BeforeEach
    void setUp() {
        PushDispatcher dispatcher = new PushDispatcher(fcm, devices, Runnable::run, (task, ms) -> { });
        svc = new NotificationService(notifications, prefs, subtypePrefs, devices, dispatcher, i18n,
                new PushGate(new PushGateTest.MemStore(), 0, 100), guard);
        when(notifications.save(any(Notification.class))).thenAnswer(i -> i.getArgument(0));
        when(prefs.findById(anyLong())).thenReturn(Optional.empty());
        when(subtypePrefs.findByUserIdAndSubtype(anyLong(), anyString())).thenReturn(Optional.empty());
        when(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(anyLong(), anyString()))
                .thenReturn(Optional.empty());
        when(devices.findByUserId(1L)).thenReturn(List.of(device("tok-aaaaaaaaaaaaaaaa")));
        when(i18n.langOf(anyLong())).thenReturn(Lang.TR);
        when(guard.canReceive(anyLong())).thenReturn(true);
    }

    @Test
    void sendCardUsesPushTextAndKeepsSenderOutOfInboxRow() {
        svc.sendCard(1L, NotificationType.USER_FOLLOW, NotificationSubtype.USER_FOLLOW, "follow:7", "Yeni takipçi",
                "Ali seni takip etti", "Ali seni takip etmeye başladı", "Bilgisayar Mühendisliği · 3. sınıf",
                Map.of("target", "USER", "value", "7", "userId", "7"),
                Map.of("senderName", "Ali", "senderAvatarUrl", "/files/a.jpg"));

        PushMessage m = fcm.messages().get(0);
        assertEquals("Ali seni takip etmeye başladı", m.title());
        assertEquals("Bilgisayar Mühendisliği · 3. sınıf", m.body());
        assertEquals("Ali", m.data().get("senderName"));
        assertEquals("follow_back", m.data().get("actions"));
        assertEquals("social", m.channelId());
        org.mockito.ArgumentCaptor<Notification> row = org.mockito.ArgumentCaptor.forClass(Notification.class);
        verify(notifications).save(row.capture());
        assertEquals("Yeni takipçi", row.getValue().getTitle()); // kutu satiri push metninden bagimsiz
        assertFalse(row.getValue().getData().contains("senderAvatarUrl")); // avatar kalici veriye yazilmaz
        assertFalse(row.getValue().getData().contains("senderName"));
    }

    @Test
    void securityAlwaysDeliversToGivenTokensEvenInQuietHoursAndWithAllPrefsOff() {
        NotificationPref off = NotificationPref.defaults(1L);
        off.setNews(false);
        off.setAnnouncements(false);
        off.setEvents(false);
        off.setMessages(false);
        off.setCommunities(false);
        // su an ortasinda kalan bir sessiz saat penceresi (+-30 dk): test saatinden bagimsiz
        int now = java.time.ZonedDateTime.now(ZoneId.of("Europe/Istanbul")).getHour() * 60
                + java.time.ZonedDateTime.now(ZoneId.of("Europe/Istanbul")).getMinute();
        off.setQuietEnabled(true);
        off.setQuietStart((now - 30 + 1440) % 1440);
        off.setQuietEnd((now + 30) % 1440);
        off.setTimezone("Europe/Istanbul");
        when(prefs.findById(1L)).thenReturn(Optional.of(off));
        assertTrue(QuietHours.isQuiet(off, Instant.now()), "on kosul: kullanici sessiz saatte");

        // kullanicinin kayitli cihazi YOK (tek cihaz kurali sildi): cihazlar disaridan verilir ve DOGRUDAN gider
        when(devices.findByUserId(1L)).thenReturn(List.of());
        Device old = device("old-token-bbbbbbbb");
        old.setPlatform("ANDROID");
        svc.sendSecurity(1L, "Yeni cihazdan giriş", "Pixel 8 · 09:41", Map.of("card", "SECURITY_NEW_DEVICE"),
                List.of(old));

        PushMessage m = fcm.messages().get(0);
        assertEquals("Yeni cihazdan giriş", m.title());
        assertEquals("security", m.channelId());
        assertEquals("not_me,view", m.data().get("actions"));
        assertEquals("SYSTEM", m.data().get("type"));
        assertTrue(m.highPriority());
        assertEquals(1, fcm.sentTo("old-token-bbbbbbbb").size());
        verify(notifications).save(any(Notification.class)); // kutu satiri da yazilir
    }

    @Test
    void securityWithoutTokensFallsBackToCurrentDevices() {
        svc.sendSecurity(1L, "Şifreniz değiştirildi", "Siz yapmadıysanız hemen şifrenizi sıfırlayın.",
                Map.of("card", "SECURITY_PASSWORD"), null);
        assertEquals(1, fcm.sentTo("tok-aaaaaaaaaaaaaaaa").size());
        assertEquals("reset_password", fcm.messages().get(0).data().get("actions"));
    }

    @Test
    void securityIgnoresRateGate() {
        // dakikalik ust sinir 1: ikinci genel push kesilir, guvenlik ise SYSTEM oldugundan kesilmez
        PushDispatcher dispatcher = new PushDispatcher(fcm, devices, Runnable::run, (task, ms) -> { });
        NotificationService tight = new NotificationService(notifications, prefs, subtypePrefs, devices, dispatcher, i18n,
                new PushGate(new PushGateTest.MemStore(), 0, 1), guard);
        tight.send(1L, NotificationType.NEWS, "a", "b", Map.of("newsId", "1"));
        tight.send(1L, NotificationType.NEWS, "c", "d", Map.of("newsId", "2"));
        int before = fcm.messages().size();
        tight.sendSecurity(1L, "x", "y", Map.of("card", "SECURITY_SESSION"), null);
        assertEquals(before + 1, fcm.messages().size());
    }

    @Test
    void templatedSendInjectsCardIntoStoredRowAndPush() {
        when(i18n.msg(anyString(), any(Lang.class), any(Object[].class))).thenReturn("metin");
        svc.sendTemplated(1L, NotificationType.EVENT, "notif.event.reminderHour", Map.of("eventId", "4"), "Etkinlik");
        PushMessage m = fcm.messages().get(0);
        assertEquals("EVENT_HOUR", m.data().get("card"));
        assertEquals("qr_checkin", m.data().get("actions"));
        org.mockito.ArgumentCaptor<Notification> row = org.mockito.ArgumentCaptor.forClass(Notification.class);
        verify(notifications).save(row.capture());
        assertTrue(row.getValue().getData().contains("\"card\":\"EVENT_HOUR\"")); // kutuda da eylem turetilebilsin
    }

    @Test
    void menuDailyHonoursItsOwnFlagAndDefaultsOff() {
        assertFalse(NotificationPref.defaults(1L).isMenuDaily());
        NotificationPref p = NotificationPref.defaults(1L);
        assertFalse(NotificationSubtype.MENU_DAILY.flag(p));
        p.setMenuDaily(true);
        assertTrue(NotificationSubtype.MENU_DAILY.flag(p));
        assertTrue(NotificationSubtype.MENU_DAILY.flagBacked());
        // kapaliyken gonderim yapilmaz
        NotificationPref closed = NotificationPref.defaults(1L);
        when(prefs.findById(1L)).thenReturn(Optional.of(closed));
        when(i18n.msg(anyString(), any(Lang.class), any(Object[].class))).thenReturn("menu");
        svc.sendTemplate(1L, NotificationTemplates.register("notif.menu.today", NotificationType.ANNOUNCEMENT,
                NotificationSubtype.MENU_DAILY), Map.of(), "menu:2026-11-02", "Çorba", "800");
        assertTrue(fcm.messages().isEmpty());
        verify(notifications, never()).save(any(Notification.class));
    }

    @Test
    void securityTypesAreNotUserConfigurableSubtypes() {
        // SYSTEM turunun alt turu yok: tercih listesine guvenlik/destek alt turu girmez
        for (NotificationSubtype s : NotificationSubtype.values()) {
            assertTrue(s.parent() != NotificationType.SYSTEM);
        }
        assertTrue(PushMessages.ttlSeconds(NotificationType.SYSTEM, null) >= 7 * 86_400);
    }
}
