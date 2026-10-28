package edu.bingol.backend.accessban;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** X-Device-Id dondurme saldirisi: kullanici basina farkli cihaz / satir siniri, saatlik yeni-anahtar siniri. */
class DeviceLogCapTest {

    private final UserDeviceLogRepository repo = mock(UserDeviceLogRepository.class);
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-28T10:00:00Z"), ZoneOffset.UTC);
    private final DeviceLogService svc = new DeviceLogService(repo, clock);

    private static ClientContext ctx(String device) {
        return new ClientContext("203.0.113.5", device, "ANDROID", "1.0");
    }

    @Test
    void underTheCapANewDeviceInsertsANewRow() {
        svc.setMaxDevicesPerUser(50);
        when(repo.findByUserIdAndDeviceHashAndIp(anyLong(), anyString(), anyString())).thenReturn(Optional.empty());
        when(repo.countByUserId(7L)).thenReturn(3L);
        when(repo.existsByUserIdAndDeviceHash(7L, "dev-new")).thenReturn(false);
        when(repo.countDistinctDevices(7L)).thenReturn(3L);

        svc.record(7L, ctx("dev-new"), "LOGIN");

        ArgumentCaptor<UserDeviceLog> saved = ArgumentCaptor.forClass(UserDeviceLog.class);
        verify(repo).save(saved.capture());
        assertEquals("dev-new", saved.getValue().getDeviceHash());
        verify(repo, never()).findFirstByUserIdOrderByLastSeenAtAsc(anyLong());
    }

    @Test
    void overTheDeviceCapTheOldestRowIsRecycledInsteadOfGrowingTheTable() {
        svc.setMaxDevicesPerUser(50);
        UserDeviceLog oldest = new UserDeviceLog();
        oldest.setUserId(7L);
        oldest.setDeviceHash("old-dev");
        oldest.setIp("198.51.100.1");
        oldest.setSeenCount(40);
        when(repo.findByUserIdAndDeviceHashAndIp(anyLong(), anyString(), anyString())).thenReturn(Optional.empty());
        when(repo.countByUserId(7L)).thenReturn(50L);
        when(repo.existsByUserIdAndDeviceHash(7L, "rotating-1")).thenReturn(false);
        when(repo.countDistinctDevices(7L)).thenReturn(50L);
        when(repo.findFirstByUserIdOrderByLastSeenAtAsc(7L)).thenReturn(Optional.of(oldest));

        svc.record(7L, ctx("rotating-1"), "LOGIN");

        ArgumentCaptor<UserDeviceLog> saved = ArgumentCaptor.forClass(UserDeviceLog.class);
        verify(repo).save(saved.capture());
        assertSame(oldest, saved.getValue(), "yeni satir degil, en eski satir devralinir");
        assertEquals("rotating-1", oldest.getDeviceHash());
        assertEquals(1, oldest.getSeenCount());
    }

    @Test
    void rowCapAlsoBoundsIpRotationOnTheSameDevice() {
        svc.setMaxDevicesPerUser(10);
        UserDeviceLog oldest = new UserDeviceLog();
        oldest.setUserId(7L);
        when(repo.findByUserIdAndDeviceHashAndIp(anyLong(), anyString(), anyString())).thenReturn(Optional.empty());
        when(repo.countByUserId(7L)).thenReturn(40L); // 10 * 4
        when(repo.existsByUserIdAndDeviceHash(7L, "same-dev")).thenReturn(true);
        when(repo.countDistinctDevices(7L)).thenReturn(1L);
        when(repo.findFirstByUserIdOrderByLastSeenAtAsc(7L)).thenReturn(Optional.of(oldest));

        svc.record(7L, ctx("same-dev"), "LOGIN");

        verify(repo).save(oldest);
    }

    @Test
    void knownDeviceStillUpdatesItsOwnRowEvenAtTheCap() {
        svc.setMaxDevicesPerUser(50);
        UserDeviceLog mine = new UserDeviceLog();
        mine.setUserId(7L);
        mine.setDeviceHash("dev-a");
        when(repo.findByUserIdAndDeviceHashAndIp(7L, "dev-a", "203.0.113.5")).thenReturn(Optional.of(mine));

        svc.record(7L, ctx("dev-a"), "LOGIN");

        verify(repo).save(mine);
        verify(repo, never()).countByUserId(anyLong());
        assertEquals(2, mine.getSeenCount());
    }

    @Test
    void zeroDisablesTheCap() {
        svc.setMaxDevicesPerUser(0);
        when(repo.findByUserIdAndDeviceHashAndIp(anyLong(), anyString(), anyString())).thenReturn(Optional.empty());

        svc.record(7L, ctx("x"), "LOGIN");

        verify(repo, never()).countByUserId(anyLong());
        verify(repo).save(any(UserDeviceLog.class));
    }

    @Test
    void touchLimitsHowManyNewDeviceKeysOneUserCanTriggerPerHour() throws Exception {
        // touch() asenkron yazar; sinir anahtar kuyruga girmeden ONCE uygulanir (bellek ici)
        when(repo.findByUserIdAndDeviceHashAndIp(anyLong(), anyString(), anyString())).thenReturn(Optional.empty());
        for (int i = 0; i < 200; i++) {
            svc.touch(9L, ctx("rot-" + i));
        }
        Thread.sleep(500);
        // En fazla 30 yeni anahtar kabul edilir (kalani sessizce atilir)
        verify(repo, org.mockito.Mockito.atMost(30)).findByUserIdAndDeviceHashAndIp(anyLong(), anyString(), anyString());
    }
}
