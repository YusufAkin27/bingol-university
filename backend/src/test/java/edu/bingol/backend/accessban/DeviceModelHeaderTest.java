package edu.bingol.backend.accessban;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;

/** Yeni cihaz bildirimi icin cihaz modeli basligi ve "yeni cihaz" tespiti. */
class DeviceModelHeaderTest {

    @Test
    void deviceModelHeaderIsSanitised() {
        assertEquals("Samsung Galaxy S24", ClientContexts.model("  Samsung Galaxy S24 "));
        assertEquals("Pixel 8 (Pro)", ClientContexts.model("Pixel 8 (Pro)"));
        assertNull(ClientContexts.model("<script>alert(1)</script>"));
        assertNull(ClientContexts.model("x".repeat(41)));
        assertNull(ClientContexts.model(""));
        assertNull(ClientContexts.model(null));
    }

    @Test
    void oldFourArgContextStillWorks() {
        ClientContext c = new ClientContext("1.1.1.1", "h", "ANDROID", "2.0.8");
        assertNull(c.deviceModel());
        assertTrue(c.hasDevice());
    }

    @Test
    void firstEverDeviceIsNotNewButUnseenSecondDeviceIs() {
        UserDeviceLogRepository repo = mock(UserDeviceLogRepository.class);
        DeviceLogService svc = new DeviceLogService(repo, java.time.Clock.systemUTC());
        ClientContext ctx = new ClientContext("1.1.1.1", "h2", "ANDROID", "2.0.8", "Pixel");
        when(repo.existsByUserIdAndDeviceHash(1L, "h2")).thenReturn(false);
        when(repo.countByUserId(1L)).thenReturn(0L);
        assertFalse(svc.isNewDevice(1L, ctx), "hesabin ilk cihazi yeni cihaz uyarisi uretmez");
        when(repo.countByUserId(1L)).thenReturn(2L);
        assertTrue(svc.isNewDevice(1L, ctx));
        when(repo.existsByUserIdAndDeviceHash(1L, "h2")).thenReturn(true);
        assertFalse(svc.isNewDevice(1L, ctx), "gorulmus cihaz yeni degil");
        assertFalse(svc.isNewDevice(1L, new ClientContext("1.1.1.1", null, "ANDROID", null)),
                "cihaz kimligi yoksa (X-Device-Id) karar verilemez: uyari yok");
        assertFalse(svc.isNewDevice(null, ctx));
        assertFalse(svc.isNewDevice(1L, null));
    }
}
