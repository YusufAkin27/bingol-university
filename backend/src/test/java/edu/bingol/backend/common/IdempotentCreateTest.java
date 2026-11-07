package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.concurrent.atomic.AtomicInteger;
import javax.sql.DataSource;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabase;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseBuilder;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseType;

/** B4: ayni Idempotency-Key ayni kaydi doner, ikinci kayit olusmaz; baslik yoksa eski davranis; kapsamlar ayridir. */
class IdempotentCreateTest {

    private static EmbeddedDatabase db;
    private static JdbcTemplate jdbc;
    private static IdempotentCreate idem;

    @BeforeAll
    static void setUp() {
        db = new EmbeddedDatabaseBuilder().setType(EmbeddedDatabaseType.H2).setName("idem_create").build();
        jdbc = new JdbcTemplate((DataSource) db);
        jdbc.execute("CREATE TABLE idempotency_record (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT NOT NULL, "
                + "scope VARCHAR(40) NOT NULL, idem_key VARCHAR(64) NOT NULL, resource_id BIGINT NOT NULL, "
                + "created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), CONSTRAINT uq UNIQUE (user_id, scope, idem_key))");
        jdbc.execute("CREATE TABLE thing (id BIGINT AUTO_INCREMENT PRIMARY KEY, v VARCHAR(10))");
        idem = new IdempotentCreate(jdbc, new DataSourceTransactionManager((DataSource) db));
    }

    @AfterAll
    static void tearDown() {
        db.shutdown();
    }

    @BeforeEach
    void clean() {
        jdbc.update("DELETE FROM idempotency_record");
        jdbc.update("DELETE FROM thing");
    }

    private long create() {
        jdbc.update("INSERT INTO thing (v) VALUES ('x')");
        return jdbc.queryForObject("SELECT MAX(id) FROM thing", Long.class);
    }

    private long run(Long uid, String scope, String key, AtomicInteger limiter) {
        return idem.run(uid, scope, key, limiter::incrementAndGet, this::create, id -> id, id -> id);
    }

    private int things() {
        return jdbc.queryForObject("SELECT COUNT(*) FROM thing", Integer.class);
    }

    @Test
    void sameKeyReturnsSameRecordAndDoesNotCreateTwice() {
        AtomicInteger limit = new AtomicInteger();
        long first = run(1L, "event", "key-abcdefgh", limit);
        long second = run(1L, "event", "key-abcdefgh", limit);
        assertEquals(first, second);
        assertEquals(1, things());
        assertEquals(1, limit.get(), "tekrar hiz sinirina sayilmaz");
    }

    @Test
    void noKeyKeepsLegacyBehaviour() {
        AtomicInteger limit = new AtomicInteger();
        long a = run(1L, "event", null, limit);
        long b = run(1L, "event", "  ", limit);
        assertEquals(2, things());
        assertEquals(2, limit.get());
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM idempotency_record", Integer.class));
        assertEquals(a + 1, b);
    }

    @Test
    void keysAreScopedPerUserAndScope() {
        AtomicInteger limit = new AtomicInteger();
        long a = run(1L, "event", "key-abcdefgh", limit);
        long b = run(2L, "event", "key-abcdefgh", limit);
        long c = run(1L, "poll", "key-abcdefgh", limit);
        assertEquals(3, things());
        assertEquals(3, java.util.Set.of(a, b, c).size());
    }

    @Test
    void failedCreateLeavesNoRecordSoRetryWorks() {
        assertThrows(IllegalStateException.class, () -> idem.run(1L, "event", "key-abcdefgh", () -> { },
                () -> {
                    create();
                    throw new IllegalStateException("boom");
                }, (Long id) -> id, id -> id));
        assertEquals(0, things(), "islem geri alinir");
        long ok = run(1L, "event", "key-abcdefgh", new AtomicInteger());
        assertEquals(1, things());
        assertEquals(ok, run(1L, "event", "key-abcdefgh", new AtomicInteger()));
    }

    @Test
    void invalidKeyIs400() {
        ApiException e = assertThrows(ApiException.class, () -> run(1L, "event", "kisa", new AtomicInteger()));
        assertEquals("IDEMPOTENCY_KEY_INVALID", e.code());
        assertNull(IdempotentCreate.exec(null, 1L, "s", null, () -> { }, () -> null, x -> 1L, x -> null));
    }
}
