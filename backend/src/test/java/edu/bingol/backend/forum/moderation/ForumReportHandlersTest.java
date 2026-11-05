package edu.bingol.backend.forum.moderation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.MediaPreview;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportReason;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.moderation.dto.ModerationDtos.CreateReportRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * FORUM_TOPIC / FORUM_COMMENT rapor adaptorleri (SPI): gorunurluk, anonim icerigin raporlanabilmesi, tekrar/kendi
 * raporu, PERSONAL_INFO sebebi, hide/unhide (A/B durumuna yansima) ve islem kaydi. Otomatik gizleme esigi ve
 * {@code markHidden} (PostgreSQL ON CONFLICT) duman betigiyle dogrulanir; burada hide/unhide dogrudan cagrilir.
 */
@SpringBootTest
@Import(ForumReportHandlersTest.Cfg.class)
class ForumReportHandlersTest {

    @TestConfiguration
    static class Cfg {
        @Bean
        @Primary
        FakeForumState fakeForumState(JdbcTemplate jdbc) {
            return new FakeForumState(jdbc);
        }
    }

    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;
    @Autowired ReportService reports;
    @Autowired BlockService blocks;
    @Autowired List<ReportTargetHandler> handlers;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    ForumTestData data;
    long cat;

    @BeforeEach
    void setUp() {
        data = new ForumTestData(jdbc, users);
        data.ensureCommentTable();
        data.reset();
        cat = data.category("Gundem");
    }

    private ReportTargetHandler handler(ReportTargetType t) {
        return handlers.stream().filter(h -> h.type() == t).findFirst().orElseThrow();
    }

    private Report report(User by, ReportTargetType t, long id, ReportReason reason) {
        return reports.create(by.getId(), new CreateReportRequest(t, id, reason, null));
    }

    @Test
    void anonymousTopicCanBeReportedWithPersonalInfoReason() {
        User owner = data.user("anonimsahip");
        User reporter = data.user("raporlayan");
        long t = data.topic(owner.getId(), cat, "Anonim", "Telefon: 0555", true);

        Report r = report(reporter, ReportTargetType.FORUM_TOPIC, t, ReportReason.PERSONAL_INFO);

        assertThat(r.getReason()).isEqualTo(ReportReason.PERSONAL_INFO);
        assertThat(r.getTargetType()).isEqualTo(ReportTargetType.FORUM_TOPIC);
        // veritabanina enum adiyla yazilir (EnumType.STRING)
        assertThat(jdbc.queryForObject("SELECT reason FROM report WHERE id = ?", String.class, r.getId())).isEqualTo("PERSONAL_INFO");
    }

    @Test
    void duplicateAndSelfReportsAreRejected() {
        User owner = data.user("sahip");
        User reporter = data.user("rapor");
        long t = data.topic(owner.getId(), cat, "Konu", "x", true);
        long c = data.comment(t, owner.getId(), "yorum", true);

        report(reporter, ReportTargetType.FORUM_TOPIC, t, ReportReason.SPAM);
        assertThatThrownBy(() -> report(reporter, ReportTargetType.FORUM_TOPIC, t, ReportReason.SPAM))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("ALREADY_REPORTED"));
        // anonim da olsa kendi icerigini raporlayamaz
        assertThatThrownBy(() -> report(owner, ReportTargetType.FORUM_TOPIC, t, ReportReason.SPAM))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("CANNOT_REPORT_SELF"));
        assertThatThrownBy(() -> report(owner, ReportTargetType.FORUM_COMMENT, c, ReportReason.SPAM))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("CANNOT_REPORT_SELF"));
    }

    @Test
    void invisibleTargetsLookLikeMissingOnes() {
        User owner = data.user("sahip2");
        User reporter = data.user("rapor2");
        long removed = data.topic(owner.getId(), cat, "Kaldirilmis", "x", false);
        data.setTopicStatus(removed, "REMOVED");
        long deleted = data.topic(owner.getId(), cat, "Silinmis", "x", false);
        data.softDeleteTopic(deleted);
        long blockedByOwner = data.topic(owner.getId(), cat, "Engelli", "x", true);
        blocks.block(owner.getId(), reporter.getId());

        for (long id : List.of(removed, deleted, blockedByOwner, 987654L)) {
            assertThatThrownBy(() -> report(reporter, ReportTargetType.FORUM_TOPIC, id, ReportReason.SPAM))
                    .as("topic " + id)
                    .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("TARGET_NOT_FOUND"));
        }
        // yorum: konu kaldirilmissa yorum da gorunmez
        long t = data.topic(owner.getId(), cat, "Aktif", "x", false);
        long c = data.comment(t, owner.getId(), "yorum", false);
        User other = data.user("rapor3");
        report(other, ReportTargetType.FORUM_COMMENT, c, ReportReason.HARASSMENT);
        data.setTopicStatus(t, "REMOVED");
        User third = data.user("rapor4");
        assertThatThrownBy(() -> report(third, ReportTargetType.FORUM_COMMENT, c, ReportReason.HARASSMENT))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("TARGET_NOT_FOUND"));
    }

    @Test
    void viewerWhoBlockedTheAuthorMayStillReport() {
        User author = data.user("yazar");
        User viewer = data.user("bakan");
        long t = data.topic(author.getId(), cat, "Konu", "x", true);
        blocks.block(viewer.getId(), author.getId()); // engelle + raporla akisi
        assertThat(handler(ReportTargetType.FORUM_TOPIC).exists(viewer.getId(), t)).isTrue();
    }

    @Test
    void hideAndUnhideReflectOnTopicStateAndAreRecorded() {
        User owner = data.user("sahip5");
        long t = data.topic(owner.getId(), cat, "Konu", "Govde", true);
        ReportTargetHandler h = handler(ReportTargetType.FORUM_TOPIC);

        assertThat(h.reversible()).isTrue();
        assertThat(h.ownerId(t)).contains(owner.getId());
        h.hide(t);
        assertThat(jdbc.queryForObject("SELECT status FROM forum_topic WHERE id = ?", String.class, t)).isEqualTo("REMOVED");
        h.hide(t); // idempotent: ikinci kayit yok
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM forum_moderation_action WHERE target_id = ? AND action = 'REMOVE'",
                Long.class, t)).isEqualTo(1L);
        // kaldirilmis ama silinmemis: yonetici akisinda "var" sayilir (geri acilabilsin), raporlayana gorunmez
        assertThat(h.exists(t)).isTrue();
        assertThat(h.exists(data.user("x9").getId(), t)).isFalse();

        h.unhide(t);
        assertThat(jdbc.queryForObject("SELECT status FROM forum_topic WHERE id = ?", String.class, t)).isEqualTo("ACTIVE");
        h.unhide(t);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM forum_moderation_action WHERE target_id = ? AND action = 'RESTORE'",
                Long.class, t)).isEqualTo(1L);
        // otomatik/rapor kaynakli kayit: istek yok => REPORT_AUTO, aktor yok
        assertThat(jdbc.queryForObject("SELECT source FROM forum_moderation_action WHERE target_id = ? AND action = 'REMOVE'",
                String.class, t)).isEqualTo("REPORT_AUTO");
        assertThat(jdbc.queryForObject("SELECT actor_id FROM forum_moderation_action WHERE target_id = ? AND action = 'REMOVE'",
                Long.class, t)).isNull();

        // sahibi silerse artik yok
        data.softDeleteTopic(t);
        assertThat(h.exists(t)).isFalse();
        assertThat(h.preview(t)).isEmpty();
    }

    @Test
    void commentHideUnhideAndPreview() {
        User owner = data.user("sahip6");
        long t = data.topic(owner.getId(), cat, "Konu", "x", false);
        long c = data.comment(t, owner.getId(), "Uygunsuz yorum metni", true);
        ReportTargetHandler h = handler(ReportTargetType.FORUM_COMMENT);

        Optional<MediaPreview> p = h.preview(c);
        assertThat(p).isPresent();
        assertThat(p.get().kind()).isEqualTo("TEXT");
        assertThat(p.get().text()).isEqualTo("Uygunsuz yorum metni");
        h.hide(c);
        assertThat(jdbc.queryForObject("SELECT status FROM forum_comment WHERE id = ?", String.class, c)).isEqualTo("REMOVED");
        h.unhide(c);
        assertThat(jdbc.queryForObject("SELECT status FROM forum_comment WHERE id = ?", String.class, c)).isEqualTo("ACTIVE");
        assertThat(jdbc.queryForObject("SELECT topic_id FROM forum_moderation_action WHERE target_id = ? AND action = 'REMOVE' "
                + "AND target_type = 'FORUM_COMMENT'", Long.class, c)).isEqualTo(t);
    }

    @Test
    void topicPreviewHasTitleAndBodyButNoAuthor() {
        User owner = data.user("sahipadi");
        long t = data.topic(owner.getId(), cat, "Baslik burada", "Govde burada", true);
        MediaPreview p = handler(ReportTargetType.FORUM_TOPIC).preview(t).orElseThrow();
        assertThat(p.text()).contains("Baslik burada").contains("Govde burada").doesNotContain("sahipadi");
    }
}
