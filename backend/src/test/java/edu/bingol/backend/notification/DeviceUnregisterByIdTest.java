package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** P04 (A04#19): cihaz kaydi FCM token'i URL'ye koymadan kimlikle silinebilir; baskasinin cihazi silinmez. */
@SpringBootTest
class DeviceUnregisterByIdTest {

    @Autowired DeviceService service;
    @Autowired DeviceRepository devices;
    @Autowired UserRepository users;

    private User user() {
        User u = new User();
        u.setEmail("d" + UUID.randomUUID().toString().substring(0, 10) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Cihaz");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    @Test
    void idLooksLikeDigitsAndTokenDoesNot() {
        assertTrue(DeviceService.isDeviceId("42"));
        assertFalse(DeviceService.isDeviceId("fAk3-token_abc:APA91bH"));
        assertFalse(DeviceService.isDeviceId("1234567890123456789")); // 19 hane: kimlik degil
        assertFalse(DeviceService.isDeviceId(null));
    }

    @Test
    void unregisterByIdDeletesOnlyOwnDevice() {
        User me = user();
        User other = user();
        service.register(me.getId(), "tok-" + UUID.randomUUID(), "android");
        service.register(other.getId(), "tok-" + UUID.randomUUID(), "android");
        Long mine = devices.findByUserId(me.getId()).get(0).getId();
        Long theirs = devices.findByUserId(other.getId()).get(0).getId();

        service.unregisterById(me.getId(), theirs); // baskasinin kimligi: sessizce etkisiz
        assertEquals(1, devices.findByUserId(other.getId()).size());

        service.unregisterById(me.getId(), mine);
        assertTrue(devices.findByUserId(me.getId()).isEmpty());
    }
}
