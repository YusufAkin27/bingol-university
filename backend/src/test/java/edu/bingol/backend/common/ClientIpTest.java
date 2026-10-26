package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class ClientIpTest {

    private final ClientIp ip = new ClientIp("10.0.0.0/8,172.16.0.0/12,127.0.0.0/8");

    @Test
    void untrustedPeerCannotSpoofXff() {
        assertEquals("203.0.113.9", ip.resolve("203.0.113.9", "1.2.3.4"));
    }

    @Test
    void trustedProxyUsesRightmostUntrusted() {
        assertEquals("198.51.100.7", ip.resolve("172.18.0.5", "198.51.100.7"));
        // istemcinin ekledigi sahte deger solda kalir, proxy'nin ekledigi sagdaki alinir
        assertEquals("198.51.100.7", ip.resolve("172.18.0.5", "9.9.9.9, 198.51.100.7"));
        assertEquals("198.51.100.7", ip.resolve("172.18.0.5", "9.9.9.9, 198.51.100.7, 10.1.1.1"));
    }

    @Test
    void garbageOrMissingHeaderFallsBack() {
        assertEquals("172.18.0.5", ip.resolve("172.18.0.5", "evil.example.com"));
        assertEquals("172.18.0.5", ip.resolve("172.18.0.5", null));
        assertEquals("172.18.0.5", ip.resolve("172.18.0.5", "10.2.2.2"));
    }
}
