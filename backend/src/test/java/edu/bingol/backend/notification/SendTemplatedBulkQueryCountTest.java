package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * P04: {@code sendTemplatedBulk} alici basina degil parca basina sabit sayida sorgu calistirir ve karar tablosu
 * tek alicili {@code sendTemplate} ile aynidir (aktiflik, tur/alt tur tercihi, sessiz saat, dil).
 */
class SendTemplatedBulkQueryCountTest {

    private static final NotificationTemplates.Template EVENT_UPDATED =
            NotificationTemplates.find("notif.event.updated").orElseThrow();
    private static final Map<String, String> DATA = Map.of("eventId", "5");

    private final NotificationRepository notifications = mock(NotificationRepository.class);
    private final NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
    private final NotificationSubtypePrefRepository subtypePrefs = mock(NotificationSubtypePrefRepository.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final I18n i18n = mock(I18n.class);
    private final RecipientGuard guard = mock(RecipientGuard.class);
    private final NotificationBatchWriter writer = mock(NotificationBatchWriter.class);
    private final FakeFcmSender fcm = new FakeFcmSender();
    private NotificationService svc;

    private final Set<Long> inactive = new HashSet<>();
    private final Map<Long, Lang> langs = new HashMap<>();
    private final Map<Long, NotificationPref> prefMap = new HashMap<>();
    private final Map<Long, List<String>> tokenMap = new HashMap<>();
    private int returnedCount = 1;

    @BeforeEach
    void setUp() {
        PushDispatcher dispatcher = new PushDispatcher(fcm, devices, Runnable::run, (task, ms) -> { });
        svc = new NotificationService(notifications, prefs, subtypePrefs, devices, dispatcher, i18n, PushGate.OPEN, guard);
        svc.setBatchWriter(writer);
        when(writer.supported()).thenReturn(true);
        when(guard.receivable(anyCollection())).thenAnswer(inv -> {
            Map<Long, Lang> out = new HashMap<>();
            for (Object o : (java.util.Collection<?>) inv.getArgument(0)) {
                if (!inactive.contains((Long) o)) {
                    out.put((Long) o, langs.getOrDefault((Long) o, Lang.TR));
                }
            }
            return out;
        });
        when(prefs.findAllById(any())).thenAnswer(inv -> {
            List<NotificationPref> out = new ArrayList<>();
            for (Object o : (Iterable<?>) inv.getArgument(0)) {
                NotificationPref p = prefMap.get((Long) o);
                if (p != null) {
                    out.add(p);
                }
            }
            return out;
        });
        when(notifications.subtypeDisabledAmong(anyCollection(), anyString())).thenReturn(List.of());
        when(writer.insertAll(anyCollection(), any(), any(), anyString(), any(), any(), any())).thenAnswer(inv -> rows(inv.getArgument(0)));
        when(writer.upsertUnread(anyCollection(), any(), any(), any(), anyString(), any(), any(), anyInt(), any()))
                .thenAnswer(inv -> rows(inv.getArgument(0)));
        when(notifications.deviceTokensOf(anyCollection())).thenAnswer(inv -> {
            List<Object[]> out = new ArrayList<>();
            for (Object o : (java.util.Collection<?>) inv.getArgument(0)) {
                for (String t : tokenMap.getOrDefault((Long) o, List.of())) {
                    out.add(new Object[] {o, t});
                }
            }
            return out;
        });
        when(notifications.unreadCountsOf(anyCollection())).thenAnswer(inv -> {
            List<Object[]> out = new ArrayList<>();
            for (Object o : (java.util.Collection<?>) inv.getArgument(0)) {
                out.add(new Object[] {o, 4L});
            }
            return out;
        });
        when(i18n.msg(eq("notif.event.updated.title"), any(Lang.class), any(Object[].class))).thenAnswer(inv ->
                inv.getArgument(1) == Lang.EN ? "Event updated" : "Etkinlik guncellendi");
        when(i18n.msg(eq("notif.event.updated.body"), any(Lang.class), any(Object[].class))).thenAnswer(inv ->
                inv.getArgument(1) == Lang.EN ? "Changed" : "Degisti");
        when(i18n.langOf(anyLong())).thenReturn(Lang.TR);
    }

    private Map<Long, NotificationBatchWriter.Row> rows(java.util.Collection<?> ids) {
        Map<Long, NotificationBatchWriter.Row> out = new HashMap<>();
        for (Object o : ids) {
            out.put((Long) o, new NotificationBatchWriter.Row(1000 + (Long) o, returnedCount));
        }
        return out;
    }

    private static List<Long> ids(int n) {
        List<Long> out = new ArrayList<>();
        for (long i = 1; i <= n; i++) {
            out.add(i);
        }
        return out;
    }

    @Test
    void thousandRecipientsCostAFixedNumberOfQueriesPerChunkNotPerRecipient() {
        for (long id = 1; id <= 1000; id++) {
            tokenMap.put(id, List.of("tok-" + id + "-aaaaaaaaaaaaaaaaaaaaaaaa"));
        }

        int written = svc.sendTemplatedBulk(ids(1000), EVENT_UPDATED, DATA, null, "Konser");

        assertEquals(1000, written);
        // 1000 alici = 4 parca x 250; her parca: aktiflik+dil, tercih, alt tur, satir yazimi, token, rozet = 6 sorgu
        verify(guard, times(4)).receivable(anyCollection());
        verify(prefs, times(4)).findAllById(any());
        verify(notifications, times(4)).subtypeDisabledAmong(anyCollection(), eq("EVENT_UPDATE"));
        verify(writer, times(4)).insertAll(anyCollection(), eq(NotificationType.EVENT), eq("EVENT_UPDATE"), anyString(), any(), any(), any());
        verify(notifications, times(4)).deviceTokensOf(anyCollection());
        verify(notifications, times(4)).unreadCountsOf(anyCollection());
        // eski alici-basina yollar KULLANILMAZ
        verify(prefs, never()).findById(anyLong());
        verify(guard, never()).canReceive(anyLong());
        verify(devices, never()).findByUserId(anyLong());
        verify(notifications, never()).save(any());
        verify(notifications, never()).countUnreadInbox(anyLong());
        // ayni metin + ayni rozet = tek dagitim; 1000 cihaz 4 FCM dagitiminda toplanir (parca basina 1)
        assertEquals(4, fcm.messages().size());
    }

    @Test
    void collapseKeyUsesUpsertAndCounterShowsInPushTitle() {
        tokenMap.put(1L, List.of("tok-1-aaaaaaaaaaaaaaaaaaaaaaaaaa"));
        returnedCount = 3;

        svc.sendTemplatedBulk(List.of(1L), EVENT_UPDATED, DATA, "evt:5", "Konser");

        verify(writer).upsertUnread(anyCollection(), eq(NotificationType.EVENT), eq("EVENT_UPDATE"), eq("evt:5"),
                anyString(), any(), any(), eq(1), any());
        verify(writer, never()).insertAll(anyCollection(), any(), any(), anyString(), any(), any(), any());
        PushMessage m = fcm.messages().get(0);
        assertTrue(m.title().endsWith("(3)"), m.title());
    }

    @Test
    void sameDecisionTableAsPerRecipientPath() {
        inactive.add(2L); // askida
        NotificationPref off = new NotificationPref();
        off.setUserId(3L);
        off.setEvents(false); // tur kapali
        prefMap.put(3L, off);
        when(notifications.subtypeDisabledAmong(anyCollection(), anyString())).thenReturn(List.of(4L)); // alt tur kapali
        NotificationPref quiet = new NotificationPref();
        quiet.setUserId(5L);
        quiet.setQuietEnabled(true);
        quiet.setQuietStart(0);
        quiet.setQuietEnd(1439);
        quiet.setTimezone("UTC");
        prefMap.put(5L, quiet);
        langs.put(6L, Lang.EN);
        for (long id = 1; id <= 6; id++) {
            tokenMap.put(id, List.of("tok-" + id + "-aaaaaaaaaaaaaaaaaaaaaaaa"));
        }

        int written = svc.sendTemplatedBulk(ids(6), EVENT_UPDATED, DATA, null, "Konser");

        // 2 askida, 3 tur kapali, 4 alt tur kapali -> satir yalniz 1, 5, 6'ya
        assertEquals(3, written);
        // push: 5 sessiz saatte -> yalniz 1 (TR) ve 6 (EN, kendi dilinde metin)
        assertEquals(2, fcm.messages().size());
        assertEquals(Set.of("Etkinlik guncellendi", "Event updated"),
                fcm.messages().stream().map(PushMessage::title).collect(java.util.stream.Collectors.toSet()));
    }

    @Test
    void duplicateAndNullIdsAreIgnored() {
        List<Long> in = new ArrayList<>(List.of(1L, 1L, 2L));
        in.add(null);

        int written = svc.sendTemplatedBulk(in, EVENT_UPDATED, DATA, null, "Konser");

        assertEquals(2, written);
    }

    @Test
    void messageTypeIsRejected() {
        NotificationTemplates.Template msg =
                new NotificationTemplates.Template("notif.x", NotificationType.MESSAGE, null);
        assertThrows(IllegalArgumentException.class, () -> svc.sendTemplatedBulk(List.of(1L), msg, DATA, null));
    }

    @Test
    void unsupportedDatabaseFallsBackToPerRecipientPath() {
        when(writer.supported()).thenReturn(false);
        when(prefs.findById(anyLong())).thenReturn(java.util.Optional.empty());
        when(guard.canReceive(anyLong())).thenReturn(true);
        when(notifications.save(any(Notification.class))).thenAnswer(i -> i.getArgument(0));

        int n = svc.sendTemplatedBulk(List.of(1L, 2L), EVENT_UPDATED, DATA, null, "Konser");

        assertEquals(2, n);
        verify(notifications, times(2)).save(any(Notification.class));
        verify(writer, never()).insertAll(anyCollection(), any(), any(), anyString(), any(), any(), any());
        verify(guard, never()).receivable(anyCollection());
    }

    @Test
    void perRecipientKeysGroupIntoSeparateUpserts() {
        svc.sendTemplatedBulkBy(List.of(1L, 2L, 3L), EVENT_UPDATED, DATA, id -> id == 3L ? null : "evt:" + (id % 2),
                "Konser");

        verify(writer).upsertUnread(eq(List.of(1L)), any(), any(), eq("evt:1"), anyString(), any(), any(), anyInt(), any());
        verify(writer).upsertUnread(eq(List.of(2L)), any(), any(), eq("evt:0"), anyString(), any(), any(), anyInt(), any());
        verify(writer).insertAll(eq(List.of(3L)), any(), any(), anyString(), any(), any(), any());
        verify(writer, never()).upsertUnread(anyCollection(), any(), any(), isNull(), anyString(), any(), any(), anyInt(), any());
    }
}
