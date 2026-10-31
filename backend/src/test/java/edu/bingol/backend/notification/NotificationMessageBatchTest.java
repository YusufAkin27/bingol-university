package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
import edu.bingol.backend.notification.NotificationService.MessageTarget;
import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * T-035: cok alicili sohbet bildirimi. Karar tablosu alici basina eski yolla AYNIDIR (aktiflik, tercih, alt tur,
 * sessiz saat, push=false, dil, "N yeni mesaj"); fark yalniz sorgu sayisidir: parca basina birer IN sorgusu.
 */
class NotificationMessageBatchTest {

    private static final Map<String, String> GROUP = Map.of("conversationId", "5", "messageId", "9",
            "conversationType", "GROUP");

    private final NotificationRepository notifications = mock(NotificationRepository.class);
    private final NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
    private final NotificationSubtypePrefRepository subtypePrefs = mock(NotificationSubtypePrefRepository.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final I18n i18n = mock(I18n.class);
    private final RecipientGuard guard = mock(RecipientGuard.class);
    private final NotificationBatchWriter writer = mock(NotificationBatchWriter.class);
    private final FakeFcmSender fcm = new FakeFcmSender();
    private NotificationService svc;

    /** Aktif olmayan kullanicilar (guard.receivable bunlari dondurmez). */
    private final Set<Long> inactive = new java.util.HashSet<>();
    private final Map<Long, Lang> langs = new HashMap<>();
    private final Map<Long, NotificationPref> prefMap = new HashMap<>();
    private final Map<Long, List<String>> tokenMap = new HashMap<>();
    /** upsert sonucunda donecek sayac (varsayilan 1). */
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
                Long id = (Long) o;
                if (!inactive.contains(id)) {
                    out.put(id, langs.getOrDefault(id, Lang.TR));
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
        when(writer.upsertUnread(anyCollection(), any(), any(), any(), anyString(), any(), any(), anyInt(), any()))
                .thenAnswer(inv -> {
                    Map<Long, NotificationBatchWriter.Row> out = new HashMap<>();
                    for (Object o : (java.util.Collection<?>) inv.getArgument(0)) {
                        out.put((Long) o, new NotificationBatchWriter.Row(1000 + (Long) o, returnedCount));
                    }
                    return out;
                });
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
                out.add(new Object[] {o, 7L});
            }
            return out;
        });
        when(i18n.msg("notif.message.new", Lang.TR)).thenReturn("Yeni mesaj");
        when(i18n.msg("notif.message.new", Lang.EN)).thenReturn("New message");
        when(i18n.msg("notif.message.many", Lang.TR, "3")).thenReturn("3 yeni mesaj");
        when(i18n.langOf(anyLong())).thenReturn(Lang.TR);
    }

    private static MessageTarget target(long id, boolean push) {
        return new MessageTarget(id, push, Map.of("senderName", "Ali"));
    }

    @Test
    void sixHundredRecipientsCostAFixedNumberOfQueriesPerChunkNotPerRecipient() {
        List<MessageTarget> all = new ArrayList<>();
        for (long id = 1; id <= 600; id++) {
            all.add(target(id, false));
        }

        svc.sendNewMessageBatch(all, "Grup - Ali", null, false, GROUP, 1);

        // 600 alici = 250 + 250 + 100 -> 3 parca; her parca: 1 aktiflik/dil + 1 tercih + 1 alt tur + 1 yazim
        verify(guard, times(3)).receivable(anyCollection());
        verify(prefs, times(3)).findAllById(any());
        verify(notifications, times(3)).subtypeDisabledAmong(anyCollection(), eq("MESSAGE_GROUP"));
        verify(writer, times(3)).upsertUnread(anyCollection(), eq(NotificationType.MESSAGE), eq("MESSAGE_GROUP"),
                eq("conv:5"), eq("Grup - Ali"), eq("Yeni mesaj"), any(), eq(1), any());
        // eski alici-basina yollar KULLANILMAZ
        verify(prefs, never()).findById(anyLong());
        verify(guard, never()).canReceive(anyLong());
        verify(devices, never()).findByUserId(anyLong());
        verify(notifications, never()).save(any());
        verify(notifications, never()).countByUserIdAndReadAtIsNull(anyLong());
    }

    @Test
    void sameDecisionTableAsPerRecipientPath() {
        inactive.add(4L); // askida: satir da push da yok
        NotificationPref off = new NotificationPref();
        off.setUserId(2L);
        off.setMessages(false); // tur kapali
        prefMap.put(2L, off);
        when(notifications.subtypeDisabledAmong(anyCollection(), anyString())).thenReturn(List.of(3L)); // alt tur kapali
        NotificationPref quiet = new NotificationPref();
        quiet.setUserId(5L);
        quiet.setQuietEnabled(true);
        quiet.setQuietStart(0);
        quiet.setQuietEnd(1439); // gunun neredeyse tamami sessiz
        quiet.setTimezone("UTC");
        prefMap.put(5L, quiet);
        langs.put(7L, Lang.EN);
        for (long id : new long[] {1, 5, 6, 7}) {
            tokenMap.put(id, List.of("tok-" + id + "-aaaaaaaaaaaaaaaaaaaa"));
        }

        svc.sendNewMessageBatch(List.of(target(1, true), target(2, true), target(3, true), target(4, true),
                target(5, true), target(6, false), target(7, true)), "Ali", null, false, GROUP, 1);

        // Satir yazilanlar: 1, 5, 6 (TR) ve 7 (EN, kendi dilinde govde)
        ArgumentCaptor<java.util.Collection<Long>> tr = ArgumentCaptor.forClass(java.util.Collection.class);
        verify(writer).upsertUnread(tr.capture(), any(), any(), any(), anyString(), eq("Yeni mesaj"), any(), anyInt(), any());
        assertEquals(Set.of(1L, 5L, 6L), Set.copyOf(tr.getValue()));
        ArgumentCaptor<java.util.Collection<Long>> en = ArgumentCaptor.forClass(java.util.Collection.class);
        verify(writer).upsertUnread(en.capture(), any(), any(), any(), anyString(), eq("New message"), any(), anyInt(), any());
        assertEquals(Set.of(7L), Set.copyOf(en.getValue()));

        // Push yalniz 1 ve 7: 2/3/4 elendi, 5 sessiz saat, 6 push=false
        List<String> pushed = fcm.messages().stream().flatMap(m -> m.data().values().stream()).toList();
        assertEquals(2, fcm.messages().size(), pushed::toString);
    }

    @Test
    void coalescedJobIncrementsCounterAndPushSummarizesTheCount() {
        tokenMap.put(1L, List.of("tok-1-aaaaaaaaaaaaaaaaaaaaaaaa"));
        returnedCount = 3; // satir sayaci 3'e cikti (birlestirilmis 3 mesaj)

        svc.sendNewMessageBatch(List.of(target(1, true)), "Ali", null, false, GROUP, 3);

        verify(writer).upsertUnread(anyCollection(), any(), any(), any(), anyString(), any(), any(), eq(3), any());
        PushMessage m = fcm.messages().get(0);
        assertEquals("3 yeni mesaj", m.body());
        assertEquals("3", m.data().get("count"));
    }

    @Test
    void previewIsKeptOnlyForOptedInRecipientsAndBadgeComesFromOneQuery() {
        for (long id : new long[] {1, 2}) {
            tokenMap.put(id, List.of("tok-" + id + "-aaaaaaaaaaaaaaaaaaaaaaaa"));
        }
        NotificationPref yes = new NotificationPref();
        yes.setUserId(1L);
        yes.setMessagePreview(true);
        prefMap.put(1L, yes);

        svc.sendNewMessageBatch(List.of(target(1, true), target(2, true)), "Ali", "gizli metin", true, GROUP, 1);

        List<PushMessage> sent = fcm.messages();
        assertEquals(2, sent.size());
        assertTrue(sent.stream().anyMatch(m -> "gizli metin".equals(m.body())), "onizleme izni olana metin gider");
        assertTrue(sent.stream().anyMatch(m -> "Yeni mesaj".equals(m.body())), "izinsize sabit govde");
        verify(notifications, times(1)).unreadCountsOf(anyCollection());
        verify(notifications, times(1)).deviceTokensOf(anyCollection());
    }

    @Test
    void unsupportedDatabaseFallsBackToPerRecipientPath() {
        when(writer.supported()).thenReturn(false);
        when(prefs.findById(anyLong())).thenReturn(Optional.empty());
        when(guard.canReceive(anyLong())).thenReturn(true);
        when(notifications.save(any(Notification.class))).thenAnswer(i -> i.getArgument(0));

        svc.sendNewMessageBatch(List.of(target(1, false), target(2, false)), "Ali", null, false, GROUP, 1);

        verify(notifications, times(2)).save(any(Notification.class));
        verify(writer, never()).upsertUnread(anyCollection(), any(), any(), any(), anyString(), any(), any(), anyInt(), any());
        verify(guard, never()).receivable(anyCollection());
    }

    @Test
    void dataIsStoredWithoutPushExtras() {
        svc.sendNewMessageBatch(List.of(new MessageTarget(1L, false, Map.of("senderAvatarUrl", "/files/a.png"))), "Ali",
                null, false, GROUP, 1);

        ArgumentCaptor<String> data = ArgumentCaptor.forClass(String.class);
        verify(writer).upsertUnread(anyCollection(), any(), any(), any(), anyString(), any(), data.capture(), anyInt(),
                any(Instant.class));
        assertTrue(!data.getValue().contains("senderAvatarUrl"), data.getValue());
        verify(writer, never()).upsertUnread(anyCollection(), any(), any(), isNull(), anyString(), any(), any(), anyInt(), any());
    }
}
