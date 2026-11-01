package edu.bingol.backend.notification;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Genel yayin (haber/duyuru/anket) icin ANAHTAR-KUMELI parcali yazim (PostgreSQL). Tum kullanici/cihaz listesini
 * bellege almak ve tek islemde satir satir INSERT yapmak yerine kullanici kimligi araliklari ({@code id > after AND
 * id <= hi}, ~1000 kullanici) uzerinden her aralik KENDI kisa ifadesinde `INSERT .. SELECT` ile hem `notification`
 * hem `push_outbox` satirlarini yazar. Push satirinda token tutulmaz (cihaz kimligi + ozet; gonderimde cozulur).
 * <p>
 * Filtreler eski {@code insertForAll/insertForLang} + {@code tokensForBroadcast*} sorgulariyla AYNIDIR (aktif hesap,
 * tur tercihi, dil, sessiz saat: sessiz saatteki kullanicinin yalniz uygulama ici kaydi dusulur, push atlanir).
 * PostgreSQL'e ozeldir ({@code sha256()}); baska veritabaninda {@link #supported()} false doner, cagiran eski yola duser.
 */
@Component
public class BroadcastWriter {

    /** Aralik basina kullanici sayisi. */
    public static final int RANGE = 1000;

    /** Tercih sutunu secimi (NotificationRepository.insertForAll ile ayni). */
    private static final String PREF_OK = """
            COALESCE(CASE :col WHEN 'news' THEN p.news WHEN 'announcements' THEN p.announcements
                           WHEN 'events' THEN p.events WHEN 'messages' THEN p.messages
                           WHEN 'communities' THEN p.communities
                           WHEN 'polls' THEN (p.polls AND p.announcements)
                           WHEN 'academic_announcements' THEN (p.academic_announcements AND p.announcements) ELSE TRUE END, TRUE)
            """;

    private static final String INSERT_NOTIFICATIONS = """
            INSERT INTO notification (user_id, type, title, body, data, created_at)
            SELECT u.id, :type, :title, :body, :data, now() FROM app_user u
            LEFT JOIN notification_pref p ON p.user_id = u.id
            WHERE u.id > :after AND u.id <= :hi
              AND u.status = 'ACTIVE' AND u.email_verified = TRUE
              AND (CAST(:lang AS varchar) IS NULL OR u.language = :lang)
              AND\s""" + PREF_OK;

    private static final String INSERT_PUSH = """
            INSERT INTO push_outbox (user_id, device_id, fcm_token_hash, payload_json, priority, status, attempts,
                                     next_attempt_at, created_at, msg_type)
            SELECT d.user_id, d.id, encode(sha256(convert_to(d.fcm_token, 'UTF8')), 'hex'), :payload, :prio,
                   'PENDING', 0, now(), now(), :msgType
            FROM device d
            JOIN app_user u ON u.id = d.user_id AND u.status = 'ACTIVE'
            LEFT JOIN notification_pref p ON p.user_id = u.id
            WHERE u.id > :after AND u.id <= :hi
              AND (CAST(:lang AS varchar) IS NULL OR u.language = :lang)
              AND\s""" + PREF_OK + "  AND " + QuietSql.NOT_QUIET;

    private final NamedParameterJdbcTemplate jdbc;
    private final NotificationBatchWriter dialect;

    @Autowired
    public BroadcastWriter(NamedParameterJdbcTemplate jdbc, NotificationBatchWriter dialect) {
        this.jdbc = jdbc;
        this.dialect = dialect;
    }

    /** Veritabani PostgreSQL mi (sha256()/ON CONFLICT yalniz orada). */
    public boolean supported() {
        return dialect.supported();
    }

    /**
     * {@code after}'tan buyuk ilk {@code n} kullanicinin en buyuk kimligi (aralik ust siniri); kalmadiysa null.
     * Birincil anahtar taramasidir (sabit maliyet).
     */
    public Long upperBound(long after, int n) {
        return jdbc.queryForObject("SELECT max(id) FROM (SELECT id FROM app_user WHERE id > :after ORDER BY id LIMIT :n) t",
                new MapSqlParameterSource("after", after).addValue("n", n), Long.class);
    }

    /** Aralikta tercihe uyan aktif kullanicilara uygulama ici bildirim satiri yazar; lang null ise tum diller. */
    public int insertNotifications(NotificationType type, String title, String body, String dataJson, String prefColumn,
                                   String lang, long after, long hi) {
        return jdbc.update(INSERT_NOTIFICATIONS, new MapSqlParameterSource("type", type.name()).addValue("title", title)
                .addValue("body", body).addValue("data", dataJson).addValue("col", prefColumn).addValue("lang", lang)
                .addValue("after", after).addValue("hi", hi));
    }

    /**
     * Aralikta tercihe uyan, sessiz saatte olmayan kullanicilarin HER cihazi icin `push_outbox` satiri yazar.
     * @return yazilan satir sayisi
     */
    public int enqueuePush(String payloadJson, short priority, String msgType, String prefColumn, String lang,
                           long after, long hi) {
        return jdbc.update(INSERT_PUSH, new MapSqlParameterSource("payload", payloadJson).addValue("prio", priority)
                .addValue("msgType", msgType).addValue("col", prefColumn).addValue("lang", lang)
                .addValue("after", after).addValue("hi", hi));
    }
}
