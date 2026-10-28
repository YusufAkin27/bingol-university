package edu.bingol.backend.export;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * KVKK m.11 "verilerimi indir": kullanicinin kendi kayitlarini tutan, onceki modullerde disa aktarimi eksik kalan
 * tablolar (denetim 2026-10-28 M10). Her bolum yalniz istek sahibinin satirlarini doner; baskalarinin kisisel verisi
 * (diger uyeler, katilimcilar, kampanyanin diger alicilari) yer almaz. Anket oylari {@code PollExporters}'ta; gizli
 * ankette kimlik baglantisi zaten tutulmadigi icin burada tekrar edilmez.
 */
@Configuration
public class ExtraExporters {

    /** Bolum basina en cok satir (cok buyuk hesaplarda cevabi sinirlar). */
    static final int MAX_ROWS = 5000;

    @Bean
    DataExporter bookmarksExporter(JdbcTemplate jdbc) {
        return DataExporter.of("bookmarks", uid -> rows(jdbc,
                "SELECT target_type AS \"targetType\", target_id AS \"targetId\", CAST(created_at AS varchar(40)) AS \"savedAt\" "
                        + "FROM bookmark WHERE user_id = ? ORDER BY id DESC LIMIT " + MAX_ROWS, uid));
    }

    @Bean
    DataExporter communityMembershipsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("communityMemberships", uid -> rows(jdbc,
                "SELECT m.community_id AS \"communityId\", c.name AS \"communityName\", m.role AS \"role\", m.status AS \"status\", "
                        + "CAST(m.joined_at AS varchar(40)) AS \"joinedAt\" FROM community_member m "
                        + "JOIN community c ON c.id = m.community_id WHERE m.user_id = ? ORDER BY m.id DESC LIMIT " + MAX_ROWS, uid));
    }

    /** Kullanicinin (duyuru olmayan) kulup gonderileri; duyurular {@code clubExtras} bolumundedir. */
    @Bean
    DataExporter communityPostsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("communityPosts", uid -> rows(jdbc,
                "SELECT id AS \"id\", community_id AS \"communityId\", content AS \"text\", image_url AS \"imageUrl\", "
                        + "CAST(created_at AS varchar(40)) AS \"createdAt\" FROM community_post "
                        + "WHERE author_id = ? AND deleted = FALSE AND announcement = FALSE ORDER BY id DESC LIMIT " + MAX_ROWS, uid));
    }

    @Bean
    DataExporter eventRsvpsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("eventRsvps", uid -> rows(jdbc,
                "SELECT r.event_id AS \"eventId\", e.title AS \"eventTitle\", r.status AS \"status\", "
                        + "CAST(r.created_at AS varchar(40)) AS \"createdAt\" FROM event_rsvp r "
                        + "JOIN user_event e ON e.id = r.event_id WHERE r.user_id = ? ORDER BY r.id DESC LIMIT " + MAX_ROWS, uid));
    }

    /** Yoklama kayitlari (QR/elle, isaretlenme ani); isaretleyen kisinin kimligi verilmez. */
    @Bean
    DataExporter eventAttendanceExporter(JdbcTemplate jdbc) {
        return DataExporter.of("eventAttendance", uid -> rows(jdbc,
                "SELECT a.event_id AS \"eventId\", e.title AS \"eventTitle\", a.present AS \"present\", a.method AS \"method\", "
                        + "CAST(a.marked_at AS varchar(40)) AS \"markedAt\" FROM event_attendance a "
                        + "JOIN user_event e ON e.id = a.event_id WHERE a.user_id = ? ORDER BY a.id DESC LIMIT " + MAX_ROWS, uid));
    }

    @Bean
    DataExporter createdEventsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("createdEvents", uid -> rows(jdbc,
                "SELECT id AS \"id\", title AS \"title\", description AS \"description\", location AS \"location\", community_id AS \"communityId\", status AS \"status\", "
                        + "CAST(starts_at AS varchar(40)) AS \"startsAt\", CAST(ends_at AS varchar(40)) AS \"endsAt\", "
                        + "CAST(created_at AS varchar(40)) AS \"createdAt\" FROM user_event "
                        + "WHERE created_by = ? ORDER BY id DESC LIMIT " + MAX_ROWS, uid));
    }

    /** Hangi yonetici e-posta kampanyalarinin alici listesinde oldugu (kampanya adi/durumu; diger alicilar yok). */
    @Bean
    DataExporter mailCampaignsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("mailCampaigns", uid -> rows(jdbc,
                "SELECT r.campaign_id AS \"campaignId\", c.name AS \"campaignName\", r.status AS \"status\", "
                        + "r.skip_reason AS \"skipReason\", r.lang AS \"lang\", CAST(r.updated_at AS varchar(40)) AS \"updatedAt\" "
                        + "FROM mail_campaign_recipient r JOIN mail_campaign c ON c.id = r.campaign_id "
                        + "WHERE r.user_id = ? ORDER BY r.id DESC LIMIT " + MAX_ROWS, uid));
    }

    @Bean
    DataExporter feedbackVotesExporter(JdbcTemplate jdbc) {
        return DataExporter.of("feedbackVotes", uid -> rows(jdbc,
                "SELECT feedback_id AS \"feedbackId\", CAST(created_at AS varchar(40)) AS \"votedAt\" "
                        + "FROM feedback_vote WHERE user_id = ? ORDER BY created_at DESC LIMIT " + MAX_ROWS, uid));
    }

    /** Sohbet uyelikleri: rol, katilma/ayrilma, sessize alma ve arsiv durumu (mesaj icerigi {@code sentMessages}'tadir). */
    @Bean
    DataExporter conversationMembershipsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("conversationMemberships", uid -> rows(jdbc,
                "SELECT conversation_id AS \"conversationId\", role AS \"role\", CAST(joined_at AS varchar(40)) AS \"joinedAt\", "
                        + "CAST(left_at AS varchar(40)) AS \"leftAt\", CAST(muted_until AS varchar(40)) AS \"mutedUntil\", "
                        + "CAST(archived_at AS varchar(40)) AS \"archivedAt\" FROM conversation_member "
                        + "WHERE user_id = ? ORDER BY id DESC LIMIT " + MAX_ROWS, uid));
    }

    private static List<Map<String, Object>> rows(JdbcTemplate jdbc, String sql, Long uid) {
        // Sutun adlari kucuk harfe duserse (H2) anahtarlar tutarsiz olmasin: LinkedHashMap ile sirayi koru
        return jdbc.queryForList(sql, uid).stream().map(m -> (Map<String, Object>) new LinkedHashMap<>(m)).toList();
    }
}
