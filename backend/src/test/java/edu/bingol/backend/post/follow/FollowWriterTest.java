package edu.bingol.backend.post.follow;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * A06#4: (a) ensureStats PostgreSQL'de benzersizlik ihlalini yutamaz (islem "aborted" olur) -> ON CONFLICT DO NOTHING;
 * (b) karsilikli takipte kilit sirasi: sayac satirlari her zaman kucuk kimlikten buyuge dogru guncellenir.
 */
class FollowWriterTest {

    record Call(String sql, Object[] args) {
    }

    private final List<Call> calls = new ArrayList<>();
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final FollowWriter writer = new FollowWriter(jdbc);

    private void record(boolean followRowInserted) {
        when(jdbc.update(anyString(), any(Object[].class))).thenAnswer(inv -> {
            String sql = inv.getArgument(0);
            Object[] args = new Object[inv.getArguments().length - 1];
            for (int i = 1; i < inv.getArguments().length; i++) {
                args[i - 1] = inv.getArguments()[i];
            }
            // varargs tek dizi olarak gelir
            if (args.length == 1 && args[0] instanceof Object[] arr) {
                args = arr;
            }
            calls.add(new Call(sql, args));
            return sql.startsWith("INSERT INTO user_follow (") || sql.startsWith("DELETE FROM user_follow")
                    ? (followRowInserted ? 1 : 0) : 1;
        });
    }

    private List<Long> statsRowOrder() {
        List<Long> order = new ArrayList<>();
        for (Call c : calls) {
            if (c.sql().startsWith("UPDATE user_follow_stats")) {
                order.add((Long) c.args()[c.args().length - 1]);
            }
        }
        return order;
    }

    @Test
    void ensureStatsUsesOnConflictInsteadOfSwallowingDuplicateKey() {
        record(true);
        writer.create(7L, 3L);
        List<Call> inserts = calls.stream().filter(c -> c.sql().startsWith("INSERT INTO user_follow_stats")).toList();
        assertEquals(2, inserts.size());
        assertTrue(inserts.stream().allMatch(c -> c.sql().contains("ON CONFLICT (user_id) DO NOTHING")),
                inserts.get(0).sql());
    }

    @Test
    void duplicateKeyFromStatsInsertIsNotSilentlySwallowed() {
        // PostgreSQL'de yutulan ihlal islemi bozar; artik hic ihlal beklenmez, ihlal gelirse yayilmali
        when(jdbc.update(anyString(), any(Object[].class))).thenAnswer(inv -> {
            String sql = inv.getArgument(0);
            if (sql.startsWith("INSERT INTO user_follow_stats")) {
                throw new DuplicateKeyException("dup");
            }
            return 1;
        });
        assertThrows(DuplicateKeyException.class, () -> writer.create(7L, 3L));
    }

    @Test
    void statsRowsAreLockedInAscendingUserIdOrderOnCreate() {
        record(true);
        writer.create(7L, 3L); // follower > followee
        assertEquals(List.of(3L, 7L), statsRowOrder());
        calls.clear();
        writer.create(3L, 7L); // follower < followee
        assertEquals(List.of(3L, 7L), statsRowOrder());
    }

    @Test
    void statsRowsAreLockedInAscendingUserIdOrderOnRemove() {
        record(true);
        writer.remove(7L, 3L);
        assertEquals(List.of(3L, 7L), statsRowOrder());
        calls.clear();
        writer.remove(3L, 7L);
        assertEquals(List.of(3L, 7L), statsRowOrder());
    }

    @Test
    void countersUntouchedWhenNothingChanged() {
        record(false);
        assertFalse(writer.create(7L, 3L));
        assertFalse(writer.remove(7L, 3L));
        assertTrue(statsRowOrder().isEmpty());
    }
}
