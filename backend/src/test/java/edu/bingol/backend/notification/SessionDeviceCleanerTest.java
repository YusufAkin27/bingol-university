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
    void otherRevocationsKeepDevices() {
        cleaner.onSessionsRevoked(new SessionsRevokedEvent(7L));
        cleaner.onSessionsRevoked(new SessionsRevokedEvent(7L, "web", true, true));
        cleaner.onSessionsRevoked(new SessionsRevokedEvent(7L, "mobile", false, true));

        verify(devices, never()).deleteAllByUser(anyLong());
    }

    @Test
    void logoutWithTokenDeletesOnlyThatUsersTokenRecord() {
        cleaner.onDeviceLoggedOut(new edu.bingol.backend.auth.token.DeviceLoggedOutEvent(7L, "tok-abc"));

        verify(devices).deleteByFcmTokenAndUserId("tok-abc", 7L);
        verify(devices, never()).deleteAllByUser(anyLong());
    }
}
