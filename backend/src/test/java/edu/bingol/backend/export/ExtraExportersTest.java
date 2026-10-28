package edu.bingol.backend.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.profile.AccountDataPurger;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import javax.sql.DataSource;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabase;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseBuilder;
import org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseType;

/** KVKK veri indirme: yeni bolumler yalniz istek sahibinin satirlarini doner; silinen tablolar bir bolume bagli. */
class ExtraExportersTest {

    private static EmbeddedDatabase db;
    private static JdbcTemplate jdbc;
    private final ExtraExporters exporters = new ExtraExporters();

    @BeforeAll
    static void setUp() {
        db = new EmbeddedDatabaseBuilder().setType(EmbeddedDatabaseType.H2).setName("extra_exporters").build();
        jdbc = new JdbcTemplate((DataSource) db);
        jdbc.execute("CREATE TABLE bookmark (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id BIGINT, target_type VARCHAR(16), target_id BIGINT, created_at TIMESTAMP WITH TIME ZONE DEFAULT now())");
        jdbc.execute("CREATE TABLE community (id BIGINT PRIMARY KEY, name VARCHAR(80))");
        jdbc.execute("CREATE TABLE community_member (id BIGINT AUTO_INCREMENT PRIMARY KEY, community_id BIGINT, user_id BIGINT, role VARCHAR(16), status VARCHAR(16), joined_at TIMESTAMP WITH TIME ZONE DEFAULT now())");
        jdbc.execute("CREATE TABLE community_post (id BIGINT AUTO_INCREMENT PRIMARY KEY, community_id BIGINT, author_id BIGINT, content VARCHAR(2000), image_url VARCHAR(300), announcement BOOLEAN DEFAULT FALSE, deleted BOOLEAN DEFAULT FALSE, created_at TIMESTAMP WITH TIME ZONE DEFAULT now())");
        jdbc.execute("CREATE TABLE user_event (id BIGINT PRIMARY KEY, title VARCHAR(150), description VARCHAR(2000), location VARCHAR(200), community_id BIGINT, created_by BIGINT, status VARCHAR(16), starts_at TIMESTAMP WITH TIME ZONE, ends_at TIMESTAMP WITH TIME ZONE, created_at TIMESTAMP WITH TIME ZONE DEFAULT now())");
        jdbc.execute("CREATE TABLE event_rsvp (id BIGINT AUTO_INCREMENT PRIMARY KEY, event_id BIGINT, user_id BIGINT, status VARCHAR(16), created_at TIMESTAMP WITH TIME ZONE DEFAULT now())");
        jdbc.execute("CREATE TABLE event_attendance (id BIGINT AUTO_INCREMENT PRIMARY KEY, event_id BIGINT, user_id BIGINT, present BOOLEAN, method VARCHAR(8), marked_by BIGINT, marked_at TIMESTAMP WITH TIME ZONE DEFAULT now())");
        jdbc.execute("CREATE TABLE mail_campaign (id BIGINT PRIMARY KEY, name VARCHAR(120))");
        jdbc.execute("CREATE TABLE mail_campaign_recipient (id BIGINT AUTO_INCREMENT PRIMARY KEY, campaign_id BIGINT, user_id BIGINT, status VARCHAR(12), skip_reason VARCHAR(24), lang VARCHAR(2), updated_at TIMESTAMP WITH TIME ZONE DEFAULT now())");
        jdbc.execute("CREATE TABLE feedback_vote (feedback_id BIGINT, user_id BIGINT, created_at TIMESTAMP WITH TIME ZONE DEFAULT now())");
        jdbc.execute("CREATE TABLE conversation_member (id BIGINT AUTO_INCREMENT PRIMARY KEY, conversation_id BIGINT, user_id BIGINT, role VARCHAR(10), joined_at TIMESTAMP WITH TIME ZONE DEFAULT now(), left_at TIMESTAMP WITH TIME ZONE, muted_until TIMESTAMP WITH TIME ZONE, archived_at TIMESTAMP WITH TIME ZONE)");

        jdbc.update("INSERT INTO bookmark (user_id, target_type, target_id) VALUES (1,'NEWS',10),(2,'NEWS',11)");
        jdbc.update("INSERT INTO community (id, name) VALUES (5,'Satranc')");
        jdbc.update("INSERT INTO community_member (community_id, user_id, role, status) VALUES (5,1,'MEMBER','ACTIVE'),(5,2,'OWNER','ACTIVE')");
        jdbc.update("INSERT INTO community_post (community_id, author_id, content, announcement, deleted) VALUES (5,1,'merhaba',FALSE,FALSE),(5,1,'duyuru',TRUE,FALSE),(5,1,'silinmis',FALSE,TRUE),(5,2,'baskasi',FALSE,FALSE)");
        jdbc.update("INSERT INTO user_event (id, title, created_by, status, starts_at, ends_at) VALUES (7,'Turnuva',1,'ACTIVE',now(),now()),(8,'Baska',2,'ACTIVE',now(),now())");
        jdbc.update("INSERT INTO event_rsvp (event_id, user_id, status) VALUES (7,1,'GOING'),(7,2,'GOING')");
        jdbc.update("INSERT INTO event_attendance (event_id, user_id, present, method, marked_by) VALUES (7,1,TRUE,'QR',1),(7,2,TRUE,'MANUAL',1)");
        jdbc.update("INSERT INTO mail_campaign (id, name) VALUES (3,'Duyuru')");
        jdbc.update("INSERT INTO mail_campaign_recipient (campaign_id, user_id, status) VALUES (3,1,'QUEUED'),(3,2,'SKIPPED')");
        jdbc.update("INSERT INTO feedback_vote (feedback_id, user_id) VALUES (9,1),(9,2)");
        jdbc.update("INSERT INTO conversation_member (conversation_id, user_id, role) VALUES (4,1,'MEMBER'),(4,2,'MEMBER')");
    }

    @AfterAll
    static void tearDown() {
        db.shutdown();
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> list(Object o) {
        return (List<Map<String, Object>>) o;
    }

    @Test
    void everySectionReturnsOnlyTheRequestersRows() {
        Map<String, DataExporter> all = Stream.of(
                        exporters.bookmarksExporter(jdbc), exporters.communityMembershipsExporter(jdbc),
                        exporters.communityPostsExporter(jdbc), exporters.eventRsvpsExporter(jdbc),
                        exporters.eventAttendanceExporter(jdbc), exporters.createdEventsExporter(jdbc),
                        exporters.mailCampaignsExporter(jdbc), exporters.feedbackVotesExporter(jdbc),
                        exporters.conversationMembershipsExporter(jdbc))
                .collect(Collectors.toMap(DataExporter::section, e -> e));
        assertEquals(9, all.size());
        for (DataExporter e : all.values()) {
            // kullanici 1 kendi tek satirini gorur; kullanici 99 hicbir sey gormez
            if (!e.section().equals("createdEvents")) {
                assertEquals(1, list(e.export(1L)).size(), e.section());
            }
            assertTrue(list(e.export(99L)).isEmpty(), e.section());
        }
        assertEquals(1, list(all.get("createdEvents").export(1L)).size());
    }

    @Test
    void communityPostsExcludeAnnouncementsDeletedAndOthers() {
        List<Map<String, Object>> rows = list(exporters.communityPostsExporter(jdbc).export(1L));
        assertEquals(1, rows.size());
        assertEquals("merhaba", rows.get(0).get("text"));
    }

    @Test
    void mailCampaignsShowOnlyOwnRecipientRow() {
        List<Map<String, Object>> rows = list(exporters.mailCampaignsExporter(jdbc).export(1L));
        assertEquals("QUEUED", rows.get(0).get("status"));
        assertEquals("Duyuru", rows.get(0).get("campaignName"));
        assertFalse(rows.get(0).containsKey("userId"));
    }

    @Test
    void attendanceDoesNotLeakWhoMarkedIt() {
        Map<String, Object> row = list(exporters.eventAttendanceExporter(jdbc).export(1L)).get(0);
        assertFalse(row.containsKey("markedBy"));
        assertEquals("QR", row.get("method"));
    }

    // ---- AccountDataPurger kapsami: silinen/temizlenen her tablo bir disa aktarim bolumune bagli ya da gerekceli muaf ----

    /** tablo -> disa aktarim bolumu (bolum adi kaynak kodda DataExporter.of("...") ile aranir). */
    private static final Map<String, String> TABLE_TO_SECTION = Map.ofEntries(
            Map.entry("device", "devices"),
            Map.entry("user_device_log", "accessHistory"),
            Map.entry("mail_campaign_recipient", "mailCampaigns"),
            Map.entry("notification", "notifications"),
            Map.entry("notification_pref", "notificationSettings"),
            Map.entry("notification_subtype_pref", "notificationSettings"),
            Map.entry("bookmark", "bookmarks"),
            Map.entry("feedback_vote", "feedbackVotes"),
            Map.entry("event_feedback", "eventExtras"),
            Map.entry("user_block", "blockedUserIds"),
            Map.entry("club_join_answer", "clubExtras"),
            Map.entry("community_member", "communityMemberships"),
            Map.entry("poll_vote", "polls"),
            Map.entry("poll", "polls"),
            Map.entry("feedback", "feedback"),
            Map.entry("support_ticket", "supportTickets"),
            Map.entry("support_message", "supportTickets"),
            Map.entry("moderation_appeal", "moderation"),
            Map.entry("report", "moderation"),
            Map.entry("event_application", "eventApplications"),
            Map.entry("event_certificate", "eventExtras"));

    /** Bilincli muaf: gecici push kuyrugu ve gizli oy secmen kaydi (kimlik-oy baglantisi tutulmaz, disari verilemez). */
    private static final Set<String> EXEMPT = Set.of("push_outbox", "poll_ballot");

    private static Set<String> purgedTables() {
        Pattern p = Pattern.compile("(?:DELETE FROM|UPDATE)\\s+([a-z_]+)");
        return Stream.concat(AccountDataPurger.DELETES.stream(), AccountDataPurger.SCRUBS.stream())
                .map(sql -> {
                    Matcher m = p.matcher(sql);
                    assertTrue(m.find(), sql);
                    return m.group(1);
                }).collect(Collectors.toSet());
    }

    @Test
    void everyPurgedTableMapsToAnExportSectionOrExemption() throws IOException {
        Path src = Paths.get("src", "main", "java");
        StringBuilder all = new StringBuilder();
        try (Stream<Path> files = Files.walk(src)) {
            for (Path f : files.filter(x -> x.toString().endsWith(".java")).toList()) {
                all.append(Files.readString(f));
            }
        }
        for (String table : purgedTables()) {
            if (EXEMPT.contains(table)) {
                continue;
            }
            String section = TABLE_TO_SECTION.get(table);
            assertTrue(section != null, "AccountDataPurger tablosu icin disa aktarim bolumu/muafiyet yok: " + table);
            assertTrue(all.indexOf("DataExporter.of(\"" + section + "\"") >= 0, "bolum kayitli degil: " + section);
        }
    }
}
