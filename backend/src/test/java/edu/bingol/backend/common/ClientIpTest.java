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

    @Test
    void limitKeyCollapsesIpv6To64AndKeepsIpv4() {
        // ayni /64 icindeki iki adres ayni anahtar (adres dondurerek limit atlatilamaz)
        assertEquals(ClientIp.limitKey("2001:db8:1:2:aaaa:bbbb:cccc:dddd"),
                ClientIp.limitKey("2001:db8:1:2:1111:2222:3333:4444"));
        assertEquals("v6:2001:0db8:0001:0002::/64", ClientIp.limitKey("2001:db8:1:2::9"));
        // baska /64 baska anahtar
        org.junit.jupiter.api.Assertions.assertNotEquals(ClientIp.limitKey("2001:db8:1:2::1"),
                ClientIp.limitKey("2001:db8:1:3::1"));
        // IPv4 oldugu gibi, IPv4-eslenik IPv6 IPv4'e donusur
        assertEquals("203.0.113.9", ClientIp.limitKey("203.0.113.9"));
        assertEquals("203.0.113.9", ClientIp.limitKey("::ffff:203.0.113.9"));
        assertEquals("unknown", ClientIp.limitKey((String) null));
        assertEquals("not-an-ip:", ClientIp.limitKey("not-an-ip:"));
    }
}
