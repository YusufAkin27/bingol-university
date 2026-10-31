package edu.bingol.backend.notification;

import java.sql.Array;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.Instant;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import javax.sql.DataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Cok alicili sohbet bildirimi icin TEK ifadelik yaz-ya-da-guncelle (PostgreSQL). Kismi benzersiz indeks
 * `fan9_notification_unread_collapse (user_id, collapse_key) WHERE read_at IS NULL` (V940) uzerinden
 * `INSERT .. ON CONFLICT .. DO UPDATE`: okunmamis satir yoksa acilir, varsa sayaci artar ve metni yenilenir.
 * Eski "bul sonra yaz" davranisinin birebir karsiligidir ama alici basina 2 gidis-donus yerine parca basina 1'dir
 * ve eszamanli iki mesajda yinelenen satir uretmez.
 * <p>
 * PostgreSQL'e ozel SQL'dir; baska veritabaninda (testlerde H2) {@link #supported()} false doner ve cagiran
 * alici basina eski yola duser.
 */
@Component
public class NotificationBatchWriter {

    /** Yazilan/guncellenen satir: kimlik ve guncel birlesme sayaci. */
    public record Row(long id, int groupCount) {}

    private static final Logger log = LoggerFactory.getLogger(NotificationBatchWriter.class);

    private static final String UPSERT = """
            INSERT INTO notification (user_id, type, title, body, data, subtype, collapse_key, group_count, created_at)
            SELECT t.uid, CAST(? AS varchar), CAST(? AS varchar), CAST(? AS varchar), CAST(? AS varchar),
                   CAST(? AS varchar), CAST(? AS varchar), CAST(? AS integer), CAST(? AS timestamptz)
            FROM unnest(CAST(? AS bigint[])) AS t(uid)
            ON CONFLICT (user_id, collapse_key) WHERE read_at IS NULL
            DO UPDATE SET group_count = notification.group_count + EXCLUDED.group_count,
                          created_at = EXCLUDED.created_at, subtype = EXCLUDED.subtype, title = EXCLUDED.title,
                          body = EXCLUDED.body, data = EXCLUDED.data
            RETURNING user_id, id, group_count
            """;

    private final JdbcTemplate jdbc;
    private final DataSource dataSource;
    /** null: henuz bakilmadi. */
    private final AtomicReference<Boolean> postgres = new AtomicReference<>();

    @Autowired
    public NotificationBatchWriter(JdbcTemplate jdbc, DataSource dataSource) {
        this.jdbc = jdbc;
        this.dataSource = dataSource;
    }

    /** Veritabani PostgreSQL mi (ON CONFLICT .. WHERE kismi indeks cikarimi yalniz orada var). */
    public boolean supported() {
        Boolean known = postgres.get();
        if (known != null) {
            return known;
        }
        boolean pg;
        try (Connection c = dataSource.getConnection()) {
            pg = "PostgreSQL".equalsIgnoreCase(c.getMetaData().getDatabaseProductName());
        } catch (Exception e) {
            log.warn("Veritabani turu okunamadi, toplu bildirim yazimi kapali: {}", e.toString());
            return false; // gecici hata: sonuc onbelleklenmez
        }
        postgres.set(pg);
        return pg;
    }

    /**
     * Verilen kullanicilar icin ayni anahtarli okunmamis bildirimi acar ya da gunceller.
     * `userIds` tekrarsiz olmalidir (ayni ifadede ayni satir iki kez etkilenemez).
     * @param increment yeni satirin ilk sayaci ve var olanin artisi (birlestirilmis gorevlerde 1'den buyuk olabilir)
     * @return kullanici kimligi -> yazilan satir
     */
    public Map<Long, Row> upsertUnread(Collection<Long> userIds, NotificationType type, String subtype,
                                       String collapseKey, String title, String body, String data, int increment,
                                       Instant now) {
        if (userIds.isEmpty()) {
            return Map.of();
        }
        Long[] ids = userIds.toArray(Long[]::new);
        Map<Long, Row> out = new HashMap<>(ids.length * 2);
        jdbc.query(con -> {
            PreparedStatement ps = con.prepareStatement(UPSERT);
            ps.setString(1, type.name());
            ps.setString(2, title);
            setNullable(ps, 3, body);
            setNullable(ps, 4, data);
            setNullable(ps, 5, subtype);
            ps.setString(6, collapseKey);
            ps.setInt(7, Math.max(1, increment));
            ps.setTimestamp(8, Timestamp.from(now));
            Array arr = con.createArrayOf("bigint", ids);
            ps.setArray(9, arr);
            return ps;
        }, rs -> {
            out.put(rs.getLong(1), new Row(rs.getLong(2), rs.getInt(3)));
        });
        return out;
    }

    private static void setNullable(PreparedStatement ps, int idx, String v) throws java.sql.SQLException {
        if (v == null) {
            ps.setNull(idx, Types.VARCHAR);
        } else {
            ps.setString(idx, v);
        }
    }
}
