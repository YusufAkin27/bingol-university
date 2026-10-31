package edu.bingol.backend.notification;

import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import org.junit.jupiter.api.Test;

class SessionDeviceCleanerTest {

    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final SessionDeviceCleaner cleaner = new SessionDeviceCleaner(devices);

    @Test
    void mobileNewLoginDeletesAllDeviceRecords() {
        cleaner.onSessionsRevoked(new SessionsRevokedEvent(7L, "mobile", true, true));

        verify(devices).deleteAllByUser(7L);
    }

    @Test
    void revokeAllSessionsDeletesAllDeviceRecordsT008() {
        // logout-all, sifre degisimi/sifirlama, askiya alma: istemci null + yeni giris degil -> kilit ekraninda bildirim kalmasin
        cleaner.onSessionsRevoked(new SessionsRevokedEvent(7L));
        cleaner.onSessionsRevoked(new SessionsRevokedEvent(8L, null, false, true));

        verify(devices).deleteAllByUser(7L);
        verify(devices).deleteAllByUser(8L);
    }

    @Test
    void otherRevocationsKeepDevices() {
        // web yeni girisi ve mobil "kismi" iptal (yeni giris degil) cihaz kayitlarina dokunmaz
        cleaner.onSessionsRevoked(new SessionsRevokedEvent(7L, "web", true, true));
        cleaner.onSessionsRevoked(new SessionsRevokedEvent(7L, "mobile", false, true));
        cleaner.onSessionsRevoked(new SessionsRevokedEvent(7L, "web", false, true));

        verify(devices, never()).deleteAllByUser(anyLong());
    }

    @Test
    void logoutWithTokenDeletesOnlyThatUsersTokenRecord() {
        cleaner.onDeviceLoggedOut(new edu.bingol.backend.auth.token.DeviceLoggedOutEvent(7L, "tok-abc"));

        verify(devices).deleteByFcmTokenAndUserId("tok-abc", 7L);
        verify(devices, never()).deleteAllByUser(anyLong());
    }
}
