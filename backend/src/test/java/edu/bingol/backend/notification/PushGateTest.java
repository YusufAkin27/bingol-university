package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Duration;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class PushGateTest {

    /** Bellek deposu; expireAll() "pencere/TTL doldu" demektir. */
    static class MemStore implements PushGate.Store {
        final Set<String> keys = new HashSet<>();
        final Map<String, Long> counters = new HashMap<>();

        @Override
        public boolean setIfAbsent(String key, Duration ttl) {
            return keys.add(key);
        }

        @Override
        public long incr(String key, Duration ttl) {
            return counters.merge(key, 1L, Long::sum);
        }

        void expireAll() {
            keys.clear();
            counters.clear();
        }
    }

    @Test
    void secondPushForSameConversationInsideWindowIsSuppressed() {
        MemStore store = new MemStore();
        PushGate gate = new PushGate(store, 20, 100);

        assertTrue(gate.allowMessagePush(1L, "conv:5"));
        assertFalse(gate.allowMessagePush(1L, "conv:5"));
        assertTrue(gate.allowMessagePush(1L, "conv:6")); // baska sohbet etkilenmez
        assertTrue(gate.allowMessagePush(2L, "conv:5")); // baska kullanici etkilenmez
        store.expireAll();
        assertTrue(gate.allowMessagePush(1L, "conv:5")); // pencere doldu
    }

    @Test
    void perUserPerMinuteCapAppliesToMessagesAndOtherTypes() {
        PushGate gate = new PushGate(new MemStore(), 0, 3);

        assertTrue(gate.allowMessagePush(1L, "conv:1"));
        assertTrue(gate.allowMessagePush(1L, "conv:2"));
        assertTrue(gate.allowGeneralPush(1L));
        assertFalse(gate.allowGeneralPush(1L));
        assertFalse(gate.allowMessagePush(1L, "conv:3"));
        assertTrue(gate.allowGeneralPush(2L));
    }

    @Test
    void storeFailureFailsOpen() {
        PushGate gate = new PushGate(new PushGate.Store() {
            @Override
            public boolean setIfAbsent(String key, Duration ttl) {
                throw new IllegalStateException("redis down");
            }

            @Override
            public long incr(String key, Duration ttl) {
                throw new IllegalStateException("redis down");
            }
        }, 20, 5);

        assertTrue(gate.allowMessagePush(1L, "conv:1"));
        assertTrue(gate.allowGeneralPush(1L));
    }

    @Test
    void openGateAllowsEverything() {
        assertTrue(PushGate.OPEN.allowMessagePush(1L, "x"));
        assertTrue(PushGate.OPEN.allowMessagePush(1L, "x"));
    }
}
