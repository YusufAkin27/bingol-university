package edu.bingol.backend.auth.session;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.accessban.DeviceNames;
import org.junit.jupiter.api.Test;

class DeviceNamesAndIpMaskTest {

    @Test
    void ipv4KeepsOnlyFirstTwoOctets() {
        assertEquals("203.0.*.*", IpMask.of("203.0.113.9"));
        assertEquals("10.1.*.*", IpMask.of(" 10.1.2.3 "));
    }

    @Test
    void ipv6KeepsOnlyFirstTwoGroupsAndGarbageIsNull() {
        assertEquals("2001:db8:*", IpMask.of("2001:db8:85a3::8a2e:370:7334"));
        assertEquals("fe80:0:*", IpMask.of("fe80:0:0:0:1:2:3:4%eth0"));
        assertNull(IpMask.of("::1"));
        assertNull(IpMask.of(null));
        assertNull(IpMask.of(""));
        assertNull(IpMask.of("not-an-ip"));
    }

    @Test
    void headerNameWinsAndIsSanitisedAndCapped() {
        assertEquals("Pixel 8", DeviceNames.resolve("  Pixel   8 ", "okhttp", "ANDROID"));
        assertEquals("script alert(1) /script", DeviceNames.sanitize("<script>alert(1)</script>"));
        assertEquals("a b", DeviceNames.sanitize("a\u0007b"));
        assertEquals(DeviceNames.MAX_LENGTH, DeviceNames.sanitize("x".repeat(500)).length());
        assertNull(DeviceNames.sanitize("   "));
        assertNull(DeviceNames.sanitize(null));
    }

    @Test
    void userAgentFallbackThenPlatformFallback() {
        assertEquals("Chrome / Windows", DeviceNames.resolve(null,
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
                "WEB"));
        assertEquals("Safari / iPhone", DeviceNames.resolve("", "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", null));
        assertEquals("Android", DeviceNames.resolve(null, "Dalvik/2.1.0 (Linux; U; Android 14; Pixel 8)", "ANDROID"));
        assertEquals("iPhone", DeviceNames.resolve(null, "Dart/3.4 (dart:io)", "IOS"));
        assertEquals("Web", DeviceNames.resolve(null, null, "web"));
        assertNull(DeviceNames.resolve(null, null, "UNKNOWN"));
        assertNull(DeviceNames.resolve(null, null, null));
        assertTrue(DeviceNames.resolve(null, "Dart/3.4", "ANDROID").length() > 0);
    }
}
