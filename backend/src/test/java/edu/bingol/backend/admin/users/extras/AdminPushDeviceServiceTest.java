package edu.bingol.backend.admin.users.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.users.extras.UserExtrasDtos.PushDeviceInfo;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class AdminPushDeviceServiceTest {

    private static final String TOKEN = "dGhpcy1pcy1hLXZlcnktbG9uZy1mY20tdG9rZW4tU0VDUkVULVRBSUw6QVBBOTFiRw";

    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final AdminPushDeviceService service = new AdminPushDeviceService(devices, users);

    private Device device(long id, long userId, String token) {
        Device d = new Device();
        d.setId(id);
        d.setUserId(userId);
        d.setFcmToken(token);
        d.setPlatform("ANDROID");
        d.setAppVersion("1.4.0");
        d.setLocale("tr");
        return d;
    }

    @Test
    void tokenIsNeverReturnedInFull() {
        when(users.findById(5L)).thenReturn(Optional.of(new User()));
        when(devices.findByUserIdOrderByUpdatedAtDesc(5L)).thenReturn(List.of(device(1, 5, TOKEN)));

        List<PushDeviceInfo> out = service.list(5L);

        assertEquals(1, out.size());
        assertEquals(TOKEN.substring(TOKEN.length() - 6), out.get(0).tokenTail());
        assertEquals(6, out.get(0).tokenTail().length());
        assertFalse(out.toString().contains(TOKEN.substring(0, 20)));
        assertEquals("ANDROID", out.get(0).platform());
        assertEquals("1.4.0", out.get(0).appVersion());
    }

    @Test
    void shortTokensRevealAtMostAQuarter() {
        assertEquals("", AdminPushDeviceService.tail(null));
        assertEquals("", AdminPushDeviceService.tail(""));
        assertEquals("d", AdminPushDeviceService.tail("abcd"));
        assertTrue(AdminPushDeviceService.tail("0123456789ab").length() <= 3);
    }

    @Test
    void deleteRemovesOnlyTheUsersOwnDevice() {
        when(users.findById(5L)).thenReturn(Optional.of(new User()));
        Device mine = device(1, 5, TOKEN);
        Device other = device(2, 6, TOKEN + "x");
        when(devices.findById(1L)).thenReturn(Optional.of(mine));
        when(devices.findById(2L)).thenReturn(Optional.of(other));

        service.delete(5L, 1L);
        verify(devices).delete(mine);

        ApiException e = assertThrows(ApiException.class, () -> service.delete(5L, 2L));
        assertEquals("PUSH_DEVICE_NOT_FOUND", e.code());
        verify(devices, never()).delete(other);

        assertEquals("PUSH_DEVICE_NOT_FOUND", assertThrows(ApiException.class, () -> service.delete(5L, 3L)).code());
    }
}
