package edu.bingol.backend.accessban;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.accessban.IpRanges.Range;
import edu.bingol.backend.accessban.IpRanges.RangeSet;
import java.util.List;
import org.junit.jupiter.api.Test;

class IpRangesTest {

    private static boolean in(String cidr, String ip) {
        Range r = IpRanges.parse(cidr);
        long[] k = IpRanges.keyOf(ip);
        return r.contains(k[0], k[1]);
    }

    @Test
    void ipv4CidrBoundaries() {
        assertTrue(in("203.0.113.0/24", "203.0.113.0"));
        assertTrue(in("203.0.113.0/24", "203.0.113.255"));
        assertFalse(in("203.0.113.0/24", "203.0.114.0"));
        assertFalse(in("203.0.113.0/24", "203.0.112.255"));
        assertTrue(in("203.0.113.7", "203.0.113.7"));
        assertFalse(in("203.0.113.7", "203.0.113.8"));
        assertTrue(in("0.0.0.0/0", "198.51.100.9"));
        assertTrue(in("198.51.100.9/32", "198.51.100.9"));
    }

    @Test
    void cidrIsNormalizedToNetworkAddress() {
        assertEquals("10.0.0.0/8", IpRanges.parse("10.1.2.3/8").canonical());
        assertEquals("203.0.113.9", IpRanges.parse("203.0.113.9").canonical());
        assertTrue(IpRanges.parse("203.0.113.9").single());
        assertFalse(IpRanges.parse("203.0.113.0/24").single());
    }

    @Test
    void ipv6Cidr() {
        assertTrue(in("2001:db8::/32", "2001:db8:ffff::1"));
        assertFalse(in("2001:db8::/32", "2001:db9::1"));
        assertTrue(in("2001:db8::1/128", "2001:db8::1"));
        assertFalse(in("2001:db8::1/128", "2001:db8::2"));
        assertTrue(in("2001:db8:0:1::/64", "2001:db8:0:1:ffff:ffff:ffff:ffff"));
        assertFalse(in("2001:db8:0:1::/64", "2001:db8:0:2::"));
        assertTrue(in("2001:db8::/65", "2001:db8::7fff:ffff:ffff:ffff"));
        assertFalse(in("2001:db8::/65", "2001:db8:0:0:8000::"));
        assertTrue(in("::/0", "2606:4700::1111"));
    }

    @Test
    void ipv4AndIpv6SpacesDoNotMix() {
        assertFalse(in("0.0.0.0/0", "2001:db8::1"));
        // IPv4-eslenik IPv6 adres IPv4 gibi davranir
        assertTrue(in("203.0.113.0/24", "::ffff:203.0.113.5"));
    }

    @Test
    void invalidInputIsRejected() {
        for (String bad : new String[] {"", "abc", "1.2.3", "1.2.3.4/33", "1.2.3.4/", "1.2.3.4/x", "::1/129",
                "300.1.1.1", "example.com", "1.2.3.4/-1", "1.2.3.4 /8"}) {
            assertThrows(IllegalArgumentException.class, () -> IpRanges.parse(bad), bad);
        }
        assertNull(IpRanges.keyOf("not-an-ip"));
        assertNull(IpRanges.keyOf(null));
    }

    @Test
    void textRoundTripAndFamily() {
        long[] k = IpRanges.keyOf("198.51.100.9");
        assertEquals("198.51.100.9", IpRanges.text(k[0], k[1]));
        assertEquals(4, IpRanges.family(k[0], k[1]));
        long[] k6 = IpRanges.keyOf("2001:db8::1");
        assertEquals("2001:db8:0:0:0:0:0:1", IpRanges.text(k6[0], k6[1]));
        assertEquals(6, IpRanges.family(k6[0], k6[1]));
    }

    @Test
    void rangeSetFindsNestedAndOverlappingRanges() {
        RangeSet set = RangeSet.of(List.of(
                new RangeSet.Entry(IpRanges.parse("10.0.0.0/8"), 1),
                new RangeSet.Entry(IpRanges.parse("10.1.0.0/16"), 2),
                new RangeSet.Entry(IpRanges.parse("192.0.2.5"), 3),
                new RangeSet.Entry(IpRanges.parse("2001:db8::/32"), 4)));
        assertTrue(set.contains("10.200.1.1"));
        assertTrue(set.contains("10.1.5.5"));
        assertTrue(set.contains("192.0.2.5"));
        assertFalse(set.contains("192.0.2.6"));
        assertTrue(set.contains("2001:db8::9"));
        assertFalse(set.contains("11.0.0.1"));
        assertFalse(set.contains("9.255.255.255"));
        assertEquals(4, set.size());
        assertEquals(RangeSet.EMPTY.size(), 0);
        assertFalse(RangeSet.EMPTY.contains("1.1.1.1"));
    }

    @Test
    void rangeSetHandlesLargeCoveringRangeBeforeNarrowOnes() {
        // Genis aralik, sonraki dar araliklarin onunde: onek-maksimum yapisi yine bulmali
        RangeSet set = RangeSet.of(List.of(
                new RangeSet.Entry(IpRanges.parse("198.0.0.0/8"), 1),
                new RangeSet.Entry(IpRanges.parse("198.1.0.1"), 2),
                new RangeSet.Entry(IpRanges.parse("198.2.0.1"), 3)));
        assertTrue(set.contains("198.250.0.1")); // yalniz genis aralik kapsar
        assertEquals(1, set.find(IpRanges.keyOf("198.250.0.1")[0], IpRanges.keyOf("198.250.0.1")[1]));
    }

    @Test
    void privateNetworksAreRecognized() {
        RangeSet priv = IpRanges.setOf(IpRanges.PRIVATE);
        for (String ip : new String[] {"127.0.0.1", "10.4.5.6", "172.16.0.1", "172.31.255.255", "192.168.1.1", "::1",
                "fd00::1", "fe80::1", "169.254.1.1"}) {
            assertTrue(priv.contains(ip), ip);
        }
        for (String ip : new String[] {"172.32.0.1", "8.8.8.8", "100.64.0.1", "2001:db8::1", "192.169.0.1"}) {
            assertFalse(priv.contains(ip), ip);
        }
    }

    @Test
    void overlapAndWithin() {
        Range a = IpRanges.parse("10.0.0.0/8");
        Range b = IpRanges.parse("10.1.0.0/16");
        Range c = IpRanges.parse("11.0.0.0/8");
        assertTrue(a.overlaps(b));
        assertTrue(b.within(a));
        assertFalse(a.within(b));
        assertFalse(a.overlaps(c));
    }
}
