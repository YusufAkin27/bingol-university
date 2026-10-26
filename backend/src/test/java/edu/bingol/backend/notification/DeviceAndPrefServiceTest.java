package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.dto.NotificationDtos.PrefsUpdate;
import edu.bingol.backend.notification.dto.NotificationDtos.PrefsView;
import edu.bingol.backend.notification.dto.NotificationDtos.QuietHoursView;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class DeviceAndPrefServiceTest {

    // ---- cihaz ----
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final DeviceService deviceSvc = new DeviceService(devices);

    @Test
    void tokenMovesToNewUserOnRegister() {
        Device existing = new Device();
        existing.setUserId(1L);
        existing.setFcmToken("tok-1234567890123456");
        when(devices.findByFcmToken("tok-1234567890123456")).thenReturn(Optional.of(existing));
        when(devices.findByUserIdOrderByUpdatedAtDesc(2L)).thenReturn(List.of(existing));

        deviceSvc.register(2L, "tok-1234567890123456", "ANDROID");

        assertEquals(2L, existing.getUserId());
        verify(devices).saveAndFlush(existing);
    }

    @Test
    void deviceLimitEvictsOldest() {
        when(devices.findByFcmToken(anyString())).thenReturn(Optional.empty());
        List<Device> mine = new ArrayList<>();
        for (int i = 0; i < DeviceService.MAX_DEVICES + 2; i++) {
            Device d = new Device();
            d.setFcmToken("t" + i);
            mine.add(d);
        }
        when(devices.findByUserIdOrderByUpdatedAtDesc(5L)).thenReturn(mine);

        deviceSvc.register(5L, "tok-new-xxxxxxxxxxxx", "IOS");

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Iterable<Device>> cap = ArgumentCaptor.forClass(Iterable.class);
        verify(devices).deleteAll(cap.capture());
        List<Device> removed = new ArrayList<>();
        cap.getValue().forEach(removed::add);
        assertEquals(2, removed.size());
        assertEquals("t" + DeviceService.MAX_DEVICES, removed.get(0).getFcmToken()); // listenin sonundakiler (en eski)
    }

    @Test
    void underLimitDeletesNothing() {
        when(devices.findByFcmToken(anyString())).thenReturn(Optional.empty());
        when(devices.findByUserIdOrderByUpdatedAtDesc(5L)).thenReturn(List.of(new Device()));
        deviceSvc.register(5L, "tok-new-xxxxxxxxxxxx", "WEB");
        verify(devices, never()).deleteAll(any(Iterable.class));
    }

    // ---- tercih ----
    private final NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
    private final NotificationSubtypePrefRepository subs = mock(NotificationSubtypePrefRepository.class);
    private final NotificationPrefService prefSvc = new NotificationPrefService(prefs, subs);

    private void stubSave() {
        when(prefs.findById(anyLong())).thenReturn(Optional.empty());
        when(prefs.save(any(NotificationPref.class))).thenAnswer(i -> i.getArgument(0));
        when(subs.findByUserIdAndSubtype(anyLong(), anyString())).thenReturn(Optional.empty());
        when(subs.findByUserId(anyLong())).thenReturn(List.of());
    }

    @Test
    void legacyFiveFlagUpdateStillWorksAndKeepsRest() {
        stubSave();
        PrefsView v = prefSvc.update(1L, new PrefsUpdate(false, null, null, true, null, null, null));
        assertFalse(v.news());
        assertTrue(v.announcements());
        assertFalse(v.quietHours().enabled());
        assertEquals("22:00", v.quietHours().start());
        assertEquals(NotificationSubtype.values().length, v.subtypes().size());
        assertTrue(v.subtypes().values().stream().allMatch(b -> b));
    }

    @Test
    void quietHoursAndSubtypesAreStored() {
        stubSave();
        PrefsView v = prefSvc.update(1L, new PrefsUpdate(null, null, null, null, null,
                new QuietHoursView(true, "23:30", "06:15", "Asia/Tokyo"), Map.of("event_reminder", false)));
        assertTrue(v.quietHours().enabled());
        assertEquals("23:30", v.quietHours().start());
        assertEquals("06:15", v.quietHours().end());
        assertEquals("Asia/Tokyo", v.quietHours().timezone());
        ArgumentCaptor<NotificationSubtypePref> cap = ArgumentCaptor.forClass(NotificationSubtypePref.class);
        verify(subs).save(cap.capture());
        assertEquals("EVENT_REMINDER", cap.getValue().getSubtype());
        assertFalse(cap.getValue().isEnabled());
    }

    @Test
    void invalidInputsRejectedWithoutSaving() {
        stubSave();
        assertThrows(ApiException.class, () -> prefSvc.update(1L, new PrefsUpdate(null, null, null, null, null,
                new QuietHoursView(true, "22:00", "22:00", "UTC"), null)));
        assertThrows(ApiException.class, () -> prefSvc.update(1L, new PrefsUpdate(null, null, null, null, null,
                new QuietHoursView(true, "22:00", "07:00", "Mars/Olympus"), null)));
        assertThrows(ApiException.class, () -> prefSvc.update(1L, new PrefsUpdate(null, null, null, null, null,
                null, Map.of("NO_SUCH", true))));
        verify(prefs, never()).save(any(NotificationPref.class));
    }

    @Test
    void retentionJobDeletesWithCutoffs() {
        NotificationRepository repo = mock(NotificationRepository.class);
        when(repo.deleteReadBefore(any(Instant.class))).thenReturn(3);
        when(repo.deleteUnreadBefore(any(Instant.class))).thenReturn(1);
        NotificationRetentionJob job = new NotificationRetentionJob(repo, 90, 365);
        Instant now = Instant.parse("2026-06-01T00:00:00Z");

        assertEquals(4, job.run(now));
        verify(repo).deleteReadBefore(now.minusSeconds(90L * 86400));
        verify(repo).deleteUnreadBefore(now.minusSeconds(365L * 86400));
    }

    @Test
    void retentionJobSwallowsErrors() {
        NotificationRepository repo = mock(NotificationRepository.class);
        when(repo.deleteReadBefore(any(Instant.class))).thenThrow(new RuntimeException("db"));
        assertEquals(0, new NotificationRetentionJob(repo, 90, 365).run(Instant.now()));
    }
}
