package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** QA-AUTH: yeni kullanicinin bildirim tercihi varsayilanlari (gunun menusu ACIK, sessiz saat KAPALI 22:00-07:00). */
class NotificationPrefDefaultsTest {

    @Test
    void newUserDefaults() {
        NotificationPref p = NotificationPref.defaults(1L);
        assertTrue(p.isMealMenu(), "gunun menusu varsayilan ACIK olmali");
        assertTrue(p.isNews());
        assertTrue(p.isMessages());
        assertTrue(p.isPolls());
        assertFalse(p.isQuietEnabled());
        assertEquals(1320, p.getQuietStart());
        assertEquals(420, p.getQuietEnd());
    }
}
